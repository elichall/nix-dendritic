# 2FA for Select Hosts — Research & Implementation

Follow-up to `security-hardening.md` item 8, raised to top priority after the
verified t480 ↔ work-desktop SSH key test showed key-only access with no
independent second factor on the work desktop.

**Status: implemented and verified on the work desktop.** Option C (Google
Authenticator TOTP, §4) is live: SSH into the work desktop now requires the
t480's key *and* a TOTP code, no Unix account password involved. This is now
the **preferred pathway** for this fleet going forward — see §9. The rest of
this doc's research (Duo personal/institutional, privacyIDEA, Tailscale check
mode) is kept as documented alternatives, not pursued further for now.

---

## 0. Read this first: compliance, not just engineering

The work desktop is a Baylor University lab machine, and the lab contracts
on **ITAR and DoD work** — that's the actual reason the security bar is
higher here, not incidental context, and it changes what "implement 2FA"
means on this specific host versus a purely personal machine.

Before implementing *anything* below on the work desktop — including the
personal-Duo-account path, which avoids touching Baylor's own systems but
still changes an authentication control on a covered machine — worth
verifying with your PI and/or Baylor's Research Compliance / IT Security
office:

- **ITAR technical data carries data-residency/access restrictions**
  (generally: not accessible to non-US-persons, not transiting outside the
  US without authorization). Tailscale is a third-party SaaS coordination
  service whose DERP relay selection isn't controlled by this repo — this
  applies to the *already-deployed* Tailscale+SSH-key setup on this machine,
  not just a prospective Tailscale-SSH-based 2FA option.
- **DoD contracts commonly carry NIST SP 800-171 / DFARS 252.204-7012
  obligations**, typically with a documented System Security Plan (SSP).
  Authentication control changes on a covered system are often exactly the
  category of change that needs to go through an institution's formal IT
  security process, even when the change is a genuine improvement and even
  when it uses an account you personally own rather than Baylor's.

This isn't boilerplate caution — ITAR carries real legal exposure, and the
right call here is verification, not assumption in either direction. This
doc still covers the technical options in full so you have them ready once
that's settled.

---

## 1. The authority split that shapes every option below

The t480 is NixOS — full Nix authority over PAM and `sshd`. The work desktop
is standalone Home Manager on a foreign Ubuntu install — the same limitation
already hit for `authorized_keys`/`sshd_config` earlier: Home Manager has no
access to system-level PAM config there at all. Anything requiring
`/etc/pam.d/sshd` or `sshd_config` edits is:
- **Declarative on the t480** via `modules/system/security.nix`.
- **A manual, out-of-band runbook on the work desktop** — installed and
  configured directly on that machine, outside this repo's Nix management,
  the same category of limitation as the SSH key wiring there.

---

## 2. Option A — Personal Duo account + `pam_duo` (considered, not chosen)

Avoids the Baylor-IT-authorization question entirely by never touching the
institutional Duo instance — a separate account you own, used only for this
purpose.

**Correcting the free-tier assumption, since this is worth getting right
before signing up:** Duo Free is genuinely **free forever for up to 10
users** — it's not a time-limited trial. What you likely ran into is
separate: Duo also runs **30-day trials of the paid Advantage/Premier
tiers** (two per year, auto-downgrading to Free when they expire), and
that's probably where the "$3/mo" impression came from, not the Free plan
itself expiring. Signup: [duo.com/editions-and-pricing/duo-free](https://duo.com/editions-and-pricing/duo-free).

**One real ambiguity my sources didn't resolve, worth checking at signup
rather than assuming:** whether **Duo Push** (the tap-to-approve mobile
notification — the actually convenient part of Duo's UX) is included in the
Free tier or gated behind the $3/mo Essentials tier. Sources conflicted —
some describe Push as available broadly, others specifically tie it to
Essentials. If Free only gives you SMS/passcode/hardware-token methods (no
Push), the day-to-day experience is closer to typing a TOTP code anyway —
at which point Option C below (Google Authenticator TOTP) delivers the same
practical UX for zero cost and zero account, and Duo's advantage narrows to
"nicer mobile app + centralized enrollment," not "push notifications you
can't get elsewhere." Worth confirming directly during Duo Free signup
before treating Push as guaranteed.

**Creating the application** (in the Duo Admin Panel, after signup):
Applications → Application Catalog → find **"UNIX Application"** (labeled
2FA) → Add. This generates the three values `pam_duo` needs: an
**integration key**, a **secret key**, and an **API hostname**
(`api-XXXXXXXX.duosecurity.com`).

**NixOS side (t480) — confirmed from the actual pinned nixpkgs source**
(`nixos/modules/security/duosec.nix`, release-26.05 branch, matching this
repo's pin):

```nix
security.duosec = {
  ssh.enable = true;        # wires pam_duo into sshd's PAM stack directly
  pam.enable = true;        # protect other PAM-gated logins too, if wanted
  integrationKey = "...";   # from the UNIX Application in Duo's admin panel
  secretKeyFile = "/run/keys/duo-skey";  # NOT a literal string — see below
  host = "api-XXXXXXXX.duosecurity.com";
  failmode = "safe";        # "safe" = fail open if Duo's API is unreachable;
                             # "secure" = fail closed. Worth a deliberate
                             # choice, not the default, given ITAR context —
                             # "secure" is the more defensible posture for a
                             # covered machine, at the cost of lockout risk
                             # if Duo's service is down.
  prompts = 3;               # max retries
};
```

Other available knobs (all confirmed present, defaults shown): `groups`
(space-separated patterns limiting *which* users get prompted — irrelevant
here with a single-user host but worth knowing), `pushinfo`, `autopush`,
`acceptEnvFactor`, `fallbackLocalIP`, `motd`, `allowTcpForwarding`.

**The secret-handling catch — this reopens the exact concern from
`security-hardening.md` item 1:** `secretKeyFile` takes a *path*, not a
literal string, specifically because the Duo secret key is a real credential
that must never be committed — unlike the SSH public keys wired up earlier,
this is genuinely sensitive. Two ways to handle it, matching the same
decision item 1 already deferred:
- **Simplest, no new tooling:** create the key file manually, once, directly
  on each host (`/run/keys/duo-skey` or similar, root-only permissions,
  outside git entirely) — same pattern as any secret that predates a
  secrets-management decision. `secretKeyFile`'s *path* is safe to commit;
  its *contents* are placed out-of-band per host.
- **Longer-term, if you circle back to sops-nix/agenix:** encrypt the key
  in-repo and decrypt it to that same path at activation.

**Work desktop (standalone HM) — manual runbook, not a Nix module:**
`security.duosec` doesn't exist outside NixOS. The equivalent there:
1. Build `duo_unix` from source ([github.com/duosecurity/duo_unix](https://github.com/duosecurity/duo_unix)) or
   check for a Duo-provided `.deb` — Ubuntu doesn't carry it in its default
   repos.
2. Populate `/etc/duo/pam_duo.conf` with the integration key/secret
   key/API hostname from the same UNIX Application (a second Duo
   application, or the same one reused — reusing is simpler and fine for a
   personal 2-host setup).
3. Manually add the `pam_duo.so` line to `/etc/pam.d/sshd` and set
   `ChallengeResponseAuthentication yes` / `KbdInteractiveAuthentication
   yes` in `sshd_config`.

This is real manual work, but one-time, and — notably — it's the same
"outside Nix's authority on this specific machine" situation the SSH key
trust work already established, not a new category of problem.

---

## 3. Option B — Baylor's institutional Duo instance (kept as an alternative)

Same NixOS mechanism as Option A, pointed at Baylor's integration
key/secret/host instead of a personal application. No longer the default
recommendation given the IT-authorization uncertainty flagged in §0 — kept
here because it may still be preferable *if* IT clears self-service
configuration against the institutional instance (e.g., if Baylor's Duo
admin panel allows self-enrolled "Unix Application" instances for
individual researchers, which varies by institution and isn't something to
assume).

---

## 4. Option C — Google Authenticator TOTP — CHOSEN, IMPLEMENTED, PREFERRED

Went with this over Option A (Duo) precisely because it had the least
friction of everything researched: no signup, no account of any kind
(personal or institutional), no ambiguity about what's included in a free
tier — just a package install and a PAM stack edit. `security.pam.services.<name>.googleAuthenticator.enable
= true;` is the fully native NixOS option (same file family as the faillock
work already applied), backed by `pkgs.google-authenticator-libpam`
(confirmed exact package name), for whenever the t480 or a future NixOS host
needs this declaratively (see §9). No third-party service is in the
authentication path at all, which also sidesteps the §0 data-residency
question entirely — a genuine bonus, not just a cost-driven choice.

### What's actually live on the work desktop (standalone-HM, manual — no Nix involvement, matches the split described in §1)

1. `sudo apt install libpam-google-authenticator`
2. `google-authenticator` run as `elichall`, from an already-authenticated
   session — generated `~/.google_authenticator`, QR scanned into an
   authenticator app, scratch codes saved separately.
3. `/etc/pam.d/sshd` — added **one line only**, right above `@include
   common-auth`:
   ```
   auth required pam_google_authenticator.so nullok
   ```
   The `@include common-auth` line itself was **commented out** — see the
   "double-auth" gotcha below for why.
4. `/etc/ssh/sshd_config` (not `/etc/ssh/ssh_config` — see gotcha below) —
   ```
   KbdInteractiveAuthentication yes
   AuthenticationMethods publickey,keyboard-interactive
   ```
5. `sudo tailscale set --ssh=false` — see the Tailscale-SSH gotcha below;
   without this, none of the above ever gets exercised at all.

**End state, verified:** SSH into the work desktop now requires the t480's
private key (unlocked locally via its own passphrase, never transmitted)
*and* a TOTP code — no Unix account password anywhere in the flow.

### Gotchas hit during rollout — worth keeping for the next host

- **Tailscale SSH silently supersedes the real `sshd` for anything arriving
  over the tailnet.** This was already flagged as a risk in §7's research,
  but it wasn't a theoretical concern — it's what actually happened first:
  every `sshd_config`/PAM edit was completely inert until `tailscale set
  --ssh=false` was run, because `tailscaled` itself was answering port 22
  over `tailscale0` (visible as `remote software version Tailscale` in `ssh
  -v` output, `Authenticated ... using "none"`) before the real `sshd` ever
  saw the connection. **Check this first on any future host**: `ssh -v
  <host> true 2>&1 | grep "remote software version"` — `OpenSSH_...` means
  you're reaching the real daemon, `Tailscale` means you're not.
- **Client config vs. server config mixup:** `KbdInteractiveAuthentication`/
  `AuthenticationMethods` were briefly added to `/etc/ssh/ssh_config` (the
  *client* config — governs this machine's own outbound connections) instead
  of `/etc/ssh/sshd_config` (the *server* config — governs incoming
  connections). One-letter filename difference, easy to mix up, silently
  inert in the wrong file rather than erroring.
- **"Double factor" overcorrection:** stacking `auth required
  pam_google_authenticator.so` *above* `@include common-auth` without
  removing the latter meant PAM required **both** the TOTP code **and** the
  Unix account password — three factors total (key + password + TOTP)
  instead of the intended two. Fix was commenting out `@include common-auth`
  in `/etc/pam.d/sshd`, leaving only the TOTP requirement in the auth phase
  (account/session phases from other `@include` lines were left untouched).
- **Same-filename key confusion across hosts:** both the t480 and the work
  desktop have their own, separate `~/.ssh/id_ed25519` — running
  `ssh-keygen -p`/`-y` while inside an active `ssh dakota` session edits/
  verifies the *work desktop's* key, not the t480's, even though the command
  looks identical either way. Confirmed via file `mtime` — a real
  `ssh-keygen -p` always rewrites the file, so an unchanged `mtime` is proof
  positive the wrong host's terminal was used. Worth checking `stat -c '%y'
  ~/.ssh/id_ed25519` immediately after any future passphrase change, on any
  host, as a matter of habit.

---

## 5. Option E — privacyIDEA (self-hosted, fully open-source, newly researched)

Raised by your "there are free alternatives out there" prompt. privacyIDEA
is an open-source MFA platform (TOTP/HOTP, and its own push-token type via
the free "privacyIDEA Authenticator" app) with an official PAM module
(`privacyidea-pam`, on GitHub) that authenticates against a privacyIDEA
server you run yourself.

**Why this is worth a real look given §0 specifically:** unlike Duo or
Tailscale, a self-hosted privacyIDEA instance running on hardware you
control (e.g., on the t480 itself) means **no third-party SaaS is in the
authentication path at all** — no data-residency question to even ask,
which may be the most straightforwardly defensible answer for the
ITAR/DoD-adjacent concern in §0, at the cost of you now running and
maintaining a small auth server.

**Real trade-off, not a free lunch:** confirmed there is **no existing
NixOS module** for privacyIDEA itself (`services.privacyidea` doesn't exist
in nixpkgs) — it's a Flask/Python application needing its own service,
database, and admin setup, which you'd either package yourself as a NixOS
module or run more informally (e.g., in a container via the sandboxing
plumbing already in `sandbox.nix`). The PAM side (`privacyidea-pam`) would
still need manual building/wiring similar to `pam_duo`, on both the t480 and
the work desktop.

**Where this sits relative to the other options:** meaningfully more
infrastructure than Duo (SaaS, zero servers to run) or TOTP
(`pam_google_authenticator`, zero servers, zero third parties, but also zero
setup beyond a NixOS option flip) — privacyIDEA is the "I want push-like UX
*and* zero third-party dependency *and* I'm willing to run a server for it"
option. Given the work desktop specifically is the host under scrutiny, and
TOTP already gets you "zero third-party dependency" without standing up any
infrastructure at all, privacyIDEA is worth keeping in mind mainly if you
outgrow TOTP's UX later, not as a first move.

---

## 7. Option D — Tailscale SSH + ACL check mode

`tailscale up --ssh` runs Tailscale's own SSH server, intercepting
connections arriving over the `tailscale0` interface; a tailnet ACL
`"action": "check"` policy can force periodic re-authentication through
Tailscale's own web-based check before a session is allowed. This is the one
mechanism that works identically regardless of host OS/management model —
enforced by `tailscaled` itself, above the OS SSH stack, so it doesn't hit
the NixOS-vs-standalone-HM split at all.

**The `sshd`-interaction question is now resolved** (confirmed against
Tailscale's own docs): Tailscale claims port 22 **only for traffic arriving
over the Tailscale interface itself** — same port number, different listener
depending on where the connection originates. Regular `sshd` keeps handling
everything else untouched (LAN, non-tailnet sources). The important
consequence: this isn't an *additive* layer on top of the
`host.trustedSshKeys` work just verified — for any connection arriving over
Tailscale (which, practically, is 100% of how you actually reach these
hosts), Tailscale SSH would **supersede** OpenSSH's `authorized_keys`
entirely, with authorization then governed by Tailscale ACLs instead. Worth
being clear-eyed that adopting this is a bigger architectural swap than
"bolt on 2FA" — it would mean the key-trust mechanism just built and verified
this session stops being the thing that actually gates access over Tailscale.

**Still carries the same §0 data-residency question** as the existing
Tailscale+SSH-key setup — not a compliance-neutral alternative to Duo/TOTP,
since it's the same third-party SaaS either way.

---

## 8. Outcome

**Option C (Google Authenticator TOTP) was chosen and implemented** on the
work desktop — see §4 for the runbook and the gotchas actually hit during
rollout. It's now this fleet's **preferred pathway** for 2FA on select hosts:
zero cost, zero account/signup with any provider, zero third-party service
in the auth path (sidesteps the §0 data-residency question entirely rather
than just being cheaper), and a native one-line NixOS option
(`security.pam.services.<name>.googleAuthenticator.enable`) for whenever a
NixOS host needs the same thing declaratively (§9).

Other options researched here are kept as documented alternatives, not
pursued further unless TOTP's UX genuinely stops being enough:
- **Option A/B (Duo, personal or Baylor)** — still viable if push-to-approve
  UX is ever wanted badly enough to accept a third-party SaaS in the loop;
  Duo Free's Push-tier inclusion (§2) would need confirming at signup.
- **Option E (privacyIDEA)** — the answer if compliance ever rules out any
  third-party SaaS *and* TOTP's code-typing UX isn't sufficient; accept the
  cost of running your own auth server only if both conditions apply.
- **Option D (Tailscale check mode)** — kept for awareness, not adopted: it
  would supersede `host.trustedSshKeys` for all Tailscale-sourced
  connections rather than layering on top (§7), a bigger swap than
  warranted here.

**§0's compliance flag stands independent of which option was picked** — the
TOTP choice happens to be the most defensible pick precisely because it
introduces zero third-party service, but that doesn't substitute for
actually having the conversation with your PI / Baylor's compliance process
about the existing Tailscale usage and this authentication change.

---

## 9. Future work: the NixOS server host will need this declaratively

You expect the future server host (the t480, once repurposed after the
Framework 13 Pro takes over as the daily machine) to likely need the same
2FA treatment. Unlike the work desktop, **that host will be NixOS** — full
Nix authority, no manual runbook required. When that host exists, the
equivalent of everything done manually in §4 becomes a `security.nix`
addition:

```nix
security.pam.services.sshd.googleAuthenticator.enable = true;
# allowNullOTP = true;  # first-rollout safety net, matching the manual
                          # runbook's `nullok` — flip off once verified
```

plus the same `AuthenticationMethods = "publickey,keyboard-interactive";`
addition to `network.nix`'s `services.openssh.settings`, and — learned the
hard way this session — **checking whether Tailscale SSH is active on that
host first** (`ssh -v <host> true 2>&1 | grep "remote software version"`)
before assuming any PAM/sshd change will actually take effect.

One difference from the manual work: NixOS's PAM module doesn't have the
`@include common-auth` double-auth footgun hit on the work desktop — the
`rules.auth` stack (same experimental API touched for `faillock` in
`security-hardening.md` item 4) is composed declaratively per-rule, so
`googleAuthenticator.enable = true` alone shouldn't also require the account
password unless something else in this repo adds that. Worth verifying
directly rather than assuming, when the time comes.

Not implemented now — no server host exists yet. Revisit this section when
it does.

## Verification

Live-verified on the work desktop (§4): SSH requires the t480's key + TOTP
code, confirmed end to end. Future NixOS-host implementation (§9) would
follow the same per-host pattern already established for
`host.trustedSshKeys`: declarative where the host is NixOS, a
documented manual runbook where it isn't (work desktop).
