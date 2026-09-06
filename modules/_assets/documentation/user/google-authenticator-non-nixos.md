# Adding Google Authenticator (TOTP) SSH 2FA — Non-NixOS Hosts

How to add key + TOTP two-factor SSH login on a **standalone Home Manager**
host (foreign distro — Ubuntu, Debian, etc.), the same setup verified
working on the work desktop. This is a manual runbook, not a Nix module —
standalone HM has no authority over system PAM/`sshd` (same limitation
already true for `authorized_keys`/`sshd_config` generally; see
`AGENTS.md`/`security-hardening.md` for why). If the target host is
**NixOS**, don't use this doc — see
`modules/_assets/plans/2fa-select-hosts-research.md` §9 for the declarative
equivalent instead.

Companion reading: `modules/_assets/plans/2fa-select-hosts-research.md` (why
TOTP was chosen over Duo/privacyIDEA/Tailscale check mode) and
`modules/_assets/plans/security-hardening.md` item 8 (the decision record).

---

## 0. Before you start

- You need an existing **key-based** SSH session into the target host
  already working (`host.trustedSshKeys` already trusts the connecting
  device). This runbook adds TOTP *on top of* key auth — it assumes key
  auth already works, it does not set that up.
- **Check whether Tailscale SSH is intercepting the connection first** —
  this silently defeats every step below with zero error message:
  ```bash
  ssh -v <host> true 2>&1 | grep "remote software version"
  ```
  - `OpenSSH_...` → good, the real `sshd` is answering, continue.
  - `Tailscale` → `tailscaled` is intercepting port 22 over the tailnet
    interface and none of this runbook's changes will ever be exercised.
    Fix first: `sudo tailscale set --ssh=false` on the target host, then
    re-run the check above.
- **Do not close your working session at any point below** until a *fresh*
  session confirms the new flow works. Every step here can lock you out if
  done wrong — the existing session is your rollback path.

---

## 1. Install the PAM module

```bash
sudo apt update && sudo apt install libpam-google-authenticator
```

(Debian/Ubuntu package name. Other distros: check for `google-authenticator`
or `pam-google-authenticator` in their package manager.)

---

## 2. Generate your TOTP secret

Run as the target user, from the **already-authenticated** session:

```bash
google-authenticator
```

- `y` to time-based tokens.
- Scan the printed QR code with your authenticator app **immediately**.
- Save the printed emergency scratch codes somewhere safe (password
  manager) — these are your fallback if you lose the device.
- `y` to the remaining prompts (update `~/.google_authenticator`, disallow
  code reuse, default time-skew window, rate-limiting).

This creates `~/.google_authenticator` (mode `600`, owned by that user).

---

## 3. Wire it into sshd's PAM stack

Edit `/etc/pam.d/sshd`. Add **one line**, above the `@include common-auth`
line:

```
auth required pam_google_authenticator.so nullok
```

Then **comment out** `@include common-auth` itself:

```
# @include common-auth
```

**Why comment it out, not just add the new line:** `@include common-auth`
pulls in `pam_unix.so` (the Unix account password check). Leaving it in
means PAM's `auth` phase requires the TOTP code *and* the account password
— three factors total (key + password + TOTP) instead of the intended two
(key + TOTP). This was hit and fixed live during the original rollout; don't
repeat it. Leave every *other* `@include` line in the file untouched
(`common-account`, `common-session`, etc.) — only the password-auth
inclusion goes.

---

## 4. Require both factors at the SSH level

Edit `/etc/ssh/sshd_config` — **not** `/etc/ssh/ssh_config` (no "d"; that's
the *client* config and silently does nothing here, another mistake hit
live during rollout). Set/add:

```
KbdInteractiveAuthentication yes
AuthenticationMethods publickey,keyboard-interactive
```

If `KbdInteractiveAuthentication` isn't recognized by the installed OpenSSH
version, use the older name instead: `ChallengeResponseAuthentication yes`.

---

## 5. Restart and verify

```bash
sudo sshd -t                 # validate syntax before restarting
sudo systemctl restart ssh   # Ubuntu's unit is usually `ssh`, not `sshd`
```

**Keeping your original session open**, open a brand-new terminal/connection
and test. Expect, in order: your key's local passphrase prompt (client-side,
unrelated to any of this), then a TOTP code prompt. No account password
should appear. Confirm this actually succeeds before touching anything else.

---

## 6. Lock it in

Once step 5 is confirmed working from a fresh session, remove the safety net:

1. Edit `/etc/pam.d/sshd`, remove `nullok` from the line added in step 3.
2. `sudo sshd -t && sudo systemctl restart ssh`.
3. Reconfirm once more from another fresh session.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| No TOTP prompt at all, straight to a shell | Tailscale SSH intercepting the connection (see §0) | `sudo tailscale set --ssh=false` on the target host |
| No TOTP prompt, `AuthenticationMethods`/`KbdInteractiveAuthentication` edits seem to do nothing | Edited `/etc/ssh/ssh_config` instead of `/etc/ssh/sshd_config` | Move the two directives to `sshd_config`, remove them from `ssh_config` |
| Prompted for key passphrase, TOTP, **and** account password (three factors) | `@include common-auth` still active alongside `pam_google_authenticator.so` | Comment out `@include common-auth` in `/etc/pam.d/sshd` |
| Old key passphrase still works after changing it; new one doesn't | Passphrase was changed on the *wrong host's* `~/.ssh/id_ed25519` (easy to do if the command was run while inside an SSH session to the other machine) | Confirm which host's terminal you're in; check `stat -c '%y' ~/.ssh/id_ed25519` — a real `ssh-keygen -p` always updates the modify time, so an unchanged timestamp proves the wrong file was touched |
| Want to sanity-check which passphrase actually unlocks a key file, without networking/agents in the way | — | `ssh-keygen -yf ~/.ssh/id_ed25519` — succeeds only with the current correct passphrase, isolated from SSH/agent behavior entirely |

---

## Cheat sheet

```bash
# Confirm which sshd is actually answering (Tailscale SSH check)
ssh -v <host> true 2>&1 | grep "remote software version"

# Disable Tailscale's own SSH server if it's intercepting
sudo tailscale set --ssh=false

# Install + enroll
sudo apt install libpam-google-authenticator
google-authenticator

# Edit these two files only
/etc/pam.d/sshd        # add pam_google_authenticator.so line, comment @include common-auth
/etc/ssh/sshd_config   # KbdInteractiveAuthentication yes; AuthenticationMethods publickey,keyboard-interactive

# Validate + apply
sudo sshd -t && sudo systemctl restart ssh

# Verify a key file's passphrase in isolation (no agent, no network)
ssh-keygen -yf ~/.ssh/id_ed25519
```
