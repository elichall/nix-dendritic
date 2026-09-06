# Security Hardening Plan — `modules/system/`

Source: audit of `modules/system/{network,security,sandbox,hardware}.nix` against
the multihost Tailscale-SSH workflow (workstation + laptop, both NixOS). Items
are ordered by priority, each carrying the follow-up questions/comments raised
when this was reviewed.

---

## 1. SSH: stop relying on password auth — declarative keys now DONE, disabling password auth still deferred

**Original finding:** `network.nix` sets `PasswordAuthentication = true` with no
declarative `authorizedKeys` anywhere in the repo, so the whole remote-login
story over Tailscale rested on an account password that isn't managed by Nix at
all.

**Update — the "no keys / no secrets management" blocker is resolved.** You
already have separate SSH keypairs for the t480, the work Ubuntu desktop, and
the WSL work Windows laptop, each already registered as separate GitHub
identities — meaning these are already-public keys, safe to commit as-is, no
sops-nix/agenix needed for this. **Applied:** a new `host.trustedSshKeys`
option (`modules/options/hostOpt.nix`, both scopes) consumed by
`users.users.${config.host.identity.username}.openssh.authorizedKeys.keys` in
`network.nix` (NixOS hosts) and by a new `flake.modules.homeManager.network`
export (standalone-HM hosts, e.g. `work.nix`, which have no `services.openssh`
of their own to declare keys on).

**Coexistence with app-managed keys (e.g. Claude Code's own SSH access):** on
NixOS, declared keys land in `/etc/ssh/authorized_keys.d/<user>`, a separate
file from `~/.ssh/authorized_keys` — `sshd`'s `AuthorizedKeysFile` checks
both, so anything else appending directly into `~/.ssh/authorized_keys` keeps
working untouched. Standalone HM (`work.nix`) has no such split available
(would require editing the foreign distro's system `sshd_config`, outside
standalone-HM's scope) — so `homeManager.network` uses an idempotent
append-if-missing `home.activation` script rather than `home.file` full
ownership, specifically so it never clobbers keys something else wrote to
that same file. Trade-off: Nix can't prune a key it once added if later
removed from `host.trustedSshKeys` — acceptable for a file other things
legitimately share.

The t480 (`workstation.nix`/`laptop.nix`) now trusts the work desktop's key; `work.nix`
now trusts the t480's key. WSL work laptop and Framework 13 aren't real host
files yet — extending is a one-line append per host once they exist.

**`PasswordAuthentication` stays `true` for now, deliberately** — key-based
login is being added as an *additional* trusted path, not a replacement, until
the 2FA idea below covers the "login from an untrusted/non-key-holding device"
case. Flipping `PasswordAuthentication = false` is still a real follow-up once
key-based login is verified working end to end (see item 8, new).

The original caveat about *not* committing keys before understanding secrets
management still stands as general guidance for anything that must stay
confidential (private keys, API tokens, a Tailscale auth key for unattended
`tailscale up`) — just not applicable to the public keys already wired up
here.

If encrypting secrets ever becomes relevant (private keys, API tokens, an
unattended Tailscale auth key), the two mainstream options are **sops-nix**
(encrypts a file with `age`/GPG, decrypted at activation into
`/run/secrets/*`, best multi-host story) or **agenix** (same idea, `age`-only,
simpler to read end to end). Neither is needed for what's wired up now.

**Remaining open sub-item:** flip `PasswordAuthentication = false;` and
`KbdInteractiveAuthentication = false;` in `network.nix` once key-based login
is verified working end to end from both directions (t480 ↔ work desktop) —
tracked as item 8 below, gated on the 2FA design so untrusted devices aren't
locked out entirely.

---

## 2. Hostname: promote to a `host.hostName` option — DONE

**Finding:** `network.nix:7` hardcoded `networking.hostName = "t480-nixos";`
inside `nixos.network`, which is pulled in by `nixos.base`, which **both**
`workstation.nix` and `laptop.nix` import.

**Turned out not to be the bug it looked like:** `workstation` and `laptop`
are currently two different NixOS configurations *for the same physical t480*
— one experimental custom display setup, one stable Noctalia-managed setup —
not two different machines. Identical `hostName` across them is correct
today. The option still earned its keep, though: the plan going forward is
Framework 13 Pro becomes the new daily machine and the t480 gets repurposed
as a server host, at which point the two configs *will* need to diverge on
identity, and having `host.hostName` as an explicit per-host-file setting
(rather than buried in a shared `nixos.base` import) is what makes that a
one-line change instead of an untangling job.

**Applied:**
- `modules/options/hostOpt.nix` — added `host.hostName` (nixos scope only, no
  home-manager consumer) with no default, so an unset value is a hard eval
  error rather than a silent inherit.
- `modules/system/network.nix` — `networking.hostName = config.host.hostName;`
- `modules/hosts/laptop.nix` and `modules/hosts/workstation.nix` — both set
  `host.hostName = "t480-nixos";` explicitly (same machine, kept in sync
  on purpose; revisit when the Framework 13 / server split happens).

Why the option still matters even though today's values match: once the
Framework 13 / server split happens, identical hostnames across distinct
physical devices on the same Tailscale tailnet would make it easy to `ssh`
into the wrong machine, collide `known_hosts` entries, and misidentify a node
in the Tailscale admin console/ACL policy — all keyed by hostname. The option
being an explicit per-host-file value now means that failure mode is avoided
by construction later, not something to remember to fix when the hardware
changes.

---

## 3. `nix.settings.trusted-users` — verified, no action

Checked: not set, so it defaults to root-only trust on the Nix daemon. That's
the safe default and nothing here widens it. No change needed, noting it so
the audit trail is complete.

---

## 4. Defense-in-depth: PAM lockout on repeated auth failures — DONE

You confirmed you like defense-in-depth and are fine with a lockout threshold
of **5** failed attempts.

**What actually got applied ended up simpler than the first draft below
(kept for context on the reasoning) — no hardcoded module path at all.**
Reading nixpkgs' `nixos/modules/security/pam.nix` directly: `pam_faillock.so`
is already a named, built-in rule (`rules.auth.faillock`) whose `modulePath`
nixpkgs derives itself from `config.security.pam.package` the moment
`security.pam.services.<name>.logFailures = true;` is set. So the real
answer to "avoid hardcoding module pathing" was: don't set `modulePath` at
all, just flip `logFailures` and override `rules.auth.faillock.settings`
(which nixpkgs auto-formats into PAM `module-arguments`):

```nix
security.pam.services = {
  login = {
    logFailures = true;
    rules.auth.faillock.settings = { deny = 5; unlock_time = 900; };
  };
  sudo = {
    logFailures = true;
    rules.auth.faillock.settings = { deny = 5; unlock_time = 900; };
  };
  sshd = {
    logFailures = true;
    rules.auth.faillock.settings = { deny = 5; unlock_time = 900; };
  };
};
```

Applied to `login`, `sudo`, **and** `sshd` — not just local console/sudo as
originally scoped, since `PasswordAuthentication` is still `true` per item
1's deferral, so SSH brute-force guessing needed the same coverage. This
pairs with the existing `MaxAuthTries = 3` in `network.nix`: `MaxAuthTries`
limits guesses *per TCP connection*, `faillock`'s `deny=5` limits guesses
*across* connections/time (15 minute lockout via `unlock_time=900`).

One caveat carried into the code as a comment: nixpkgs marks
`security.pam.services.<name>.rules` **experimental** ("subject to breaking
changes without notice") — worth a quick re-check of
`nixos/modules/security/pam.nix` after any nixpkgs bump.

---

## 5. Practical Tailscale + firewall walkthrough

You flagged you're not strong on networking and want more depth here, not
just the finding. Walking through what's actually happening in
`network.nix`:

**What `trustedInterfaces` does.** NixOS's `networking.firewall` is a
front-end over `nftables` (you already have `networking.nftables.enable =
true`, so it's using nftables directly rather than the legacy iptables
backend). `trustedInterfaces = [ tailscale0 ]` inserts a rule that
**short-circuits all filtering for traffic arriving on that interface** — not
"allow SSH over Tailscale," but "don't apply *any* firewall rule to anything
arriving over Tailscale." Concretely this means: if some other service on the
box binds to `0.0.0.0` (all interfaces) with no auth of its own — say you
`nix run` a debug HTTP server, or a package silently opens a listener — it
becomes reachable from *every device on your tailnet*, not just from
`localhost`, with zero firewall involvement. This is normal for a
Tailscale-as-VPN setup and is why Tailscale documents it as replacing your
firewall for tailnet traffic — but it means your real access-control boundary
for "who can reach what on my LAN-equivalent" is **Tailscale ACLs**
(configured at https://login.tailscale.com/admin/acls, not in this repo),
not nftables.

**What this means practically for you:**
- Anything you don't want reachable *from your other devices* needs either
  its own auth (e.g. SSH's key/password prompt) or must bind to `127.0.0.1`
  only, since the firewall isn't going to stop it.
- Your Tailscale admin console ACL policy is worth actually opening and
  reading once — by default (no custom ACL file), Tailscale allows *all*
  devices on your tailnet to reach *all* ports on all other devices. If it's
  never been customized, every device already has this same blanket access
  to every other device, and your Nix config's `trustedInterfaces` line is
  just formalizing what Tailscale's default policy already allows.

**Two concrete ways to tighten this, in increasing effort:**

1. **Tailscale ACL tags/rules** (no Nix changes, all in the admin console):
   scope which devices can reach which ports on which other devices, e.g.
   "laptop can SSH (port 22) to workstation, but not vice versa" or "only
   allow port 22 over tailscale0, nothing else." This is the correct place
   to express "who can talk to whom" for a personal tailnet — it's the same
   *kind* of rule as an nftables allow-list, just enforced by Tailscale's
   coordination server + each node's WireGuard config instead of by your
   local firewall.

2. **Tailscale SSH** — instead of (or alongside) OpenSSH, set
   `services.tailscale.extraUpFlags = [ "--ssh" ];` in `network.nix`. This
   makes Tailscale itself broker SSH sessions: identity is your Tailscale
   login (already OAuth'd through Google/GitHub/etc., no separate SSH key
   management at all), and *authorization* is expressed as ACL rules
   (`"ssh"` blocks in the same tailnet policy file) rather than
   `sshd_config`. Practically: you'd `ssh workstation` exactly like today,
   but Tailscale intercepts and can enforce things like requiring
   re-authentication for interactive sessions, without you managing
   `authorized_keys` at all. This sidesteps item 1's "no secrets management
   yet" blocker entirely, since there's no key material to store — auth
   piggybacks on your already-authenticated Tailscale identity. Worth trying
   before investing effort in sops-nix/agenix, since it may remove the need
   for declarative SSH keys altogether.

**Smallest immediate win regardless of the above:** add
`services.openssh.settings.AllowUsers = [ "elichall" ];` to `network.nix`.
Currently nothing restricts *which local account* may attempt SSH login — if
another user were ever created on the box, it'd be reachable over SSH too.
This is a one-line, zero-risk addition independent of the password-auth
question in item 1.

---

## 6. Kernel sysctl easy wins (`security.nix`) — DONE

You said any easy wins are welcome. Added to the existing `boot.kernel.sysctl`
set in `security.nix`:

```nix
"kernel.yama.ptrace_scope" = 1;      # a process can only ptrace its own children,
                                       # not arbitrary other processes — blocks a
                                       # common technique for stealing credentials/
                                       # secrets out of another running process's memory
"kernel.dmesg_restrict" = 1;          # unprivileged users can't read dmesg, which
                                       # otherwise leaks kernel pointer addresses
                                       # useful for defeating ASLR in local exploits
"net.ipv4.tcp_syncookies" = 1;        # SYN-flood resistance; usually kernel-default
                                       # already but worth pinning explicitly since
                                       # this file is your source of truth for sysctls
"fs.protected_hardlinks" = 1;         # stop hardlinking to files you don't own —
                                       # closes a classic local privesc/TOCTOU vector
"fs.protected_symlinks" = 1;          # same idea for symlinks in world-writable dirs
                                       # (e.g. /tmp)
```

All five are inert unless something on the box is already relying on the
loose behavior (rare in normal desktop/laptop use) — safe to add in one
batch.

---

## 7. VM / containerization (`sandbox.nix`) — you said this is scaffolding only, more detail wanted

You mentioned `sandbox.nix` is currently just plumbing you added without
having used VMs or containers yet. Breaking down what's actually enabled and
what each piece means for your security posture:

**`virtualisation.libvirtd.enable = true` + `users.users.elichall.extraGroups
= [ "libvirtd" ]`.** This is the QEMU/KVM *management* stack — `virsh`,
`virt-manager`, storage pools, virtual networks. The important thing to
understand: **membership in the `libvirtd` group is effectively
root-equivalent on the host.** This isn't a NixOS quirk, it's how libvirt
works everywhere: the default connection URI for a normal user is
`qemu:///system`, which talks to a systemd service running *as root*. Once
you're in that group, you can ask that root daemon to start a VM with, say, a
host disk device (`/dev/sda`) passed through directly, or with a hook script
that runs as root at VM start/stop. There's no sandbox between "member of
libvirtd" and "root," by design — libvirt assumes anyone in that group is
trusted like an admin.

The alternative is **`qemu:///session`** — a *per-user*, unprivileged libvirt
instance with no root daemon involved, storage/networking scoped to your own
account. It's more limited (no bridged networking without extra setup, no
access to host block devices) but doesn't hand out root-equivalent access
just to run a VM. If your actual use case turns out to be "spin up a
disposable Linux/Windows VM to test something," `qemu:///session` is very
likely sufficient and meaningfully lower-risk than what's currently wired up.
Nothing to change today since you're not using it yet — just worth knowing
before you start creating VMs, so you pick the connection URI deliberately
rather than defaulting to `qemu:///system` because it's what `virt-manager`
opens first.

**`swtpm.enable = true`** — software TPM 2.0 emulation for guests. This is
purely for compatibility (Windows 11 guests require a TPM to install at all;
some Linux full-disk-encryption setups want one too). It has no host security
implication either way — it's emulating a chip *inside* the guest, isolated
to that guest's own VM state.

**Podman, mentioned in your original module comment but not yet actually
enabled** (`virtualisation.podman.enable` isn't set anywhere currently — the
comment in `sandbox.nix` describes intent, the option isn't turned on). Worth
noting since if/when you do add it: Podman's headline security feature
relative to Docker is that it runs **rootless by default** — containers run
as your own unprivileged user via user namespaces, with no root-owned daemon
listening on a socket at all (Docker's `dockerd` running as root, with group
membership in `docker` being *another* root-equivalent grant, similar to the
libvirtd situation above, is the thing Podman was built to avoid). If you add
containerization later, Podman rootless is the safer on-ramt precisely
because you're new to this — you'd have to go out of your way
(`--privileged`, running as root explicitly) to get back to Docker-equivalent
risk, rather than that being the default.

**Bottom line for this section:** nothing needs to change in `sandbox.nix`
right now. The one thing worth deciding *before* you start actually using it:
default to `qemu:///session` for libvirt VMs and (if/when added) rootless
Podman for containers, unless a specific VM genuinely needs host-level
access (e.g. GPU passthrough, bridged networking to your LAN) — in which
case `qemu:///system` + `libvirtd` group membership is the deliberate,
understood trade-off rather than the accidental default.

---

## 8. Second-factor auth for untrusted/non-key-holding devices (new, deferred)

You want a way to SSH in from a device that *isn't* one of your registered
keypairs — e.g. a borrowed machine or a new device before it's been enrolled
— without falling back to a bare password. The shape you described is
Duo/TOTP-style: password + a second factor from something like Duo Mobile or
a standard authenticator app.

This needs its own research/design pass before implementation — options
worth comparing when you get to it:
- **PAM TOTP** (`pam_google_authenticator` or similar) — self-hosted, no
  third-party service, standard authenticator app (Google Authenticator,
  Authy, etc.) scans a QR code once per device/account at enrollment.
- **Duo** — third-party service, push-based approval instead of typing a
  code, but adds an external dependency or subscription for what's
  currently a fully self-contained personal setup.

Whichever is chosen, the intended end state is: key-holding devices skip
straight through (no change to their experience), while a device without a
registered key falls through to password + second factor instead of being
locked out entirely. This is why `PasswordAuthentication` was left `true` in
item 1 rather than disabled outright — disabling it now would remove the
untrusted-device path this item is meant to secure, not just tighten it.

---

## Summary / suggested order of implementation

| # | Item | Status |
|---|------|--------|
| 1 | SSH key-based auth (authorized_keys) | **Done** — `host.trustedSshKeys` option wired for t480 ↔ work desktop; `PasswordAuthentication` deliberately left on, see item 8 |
| 2 | `host.hostName` option + fix `network.nix` | **Done** — both hosts still point at `t480-nixos` (same physical machine); revisit at the Framework 13/server split |
| 3 | `trusted-users` | No action — already correct |
| 4 | PAM faillock, deny=5 | **Done** — `login`/`sudo`/`sshd`, no hardcoded module path needed |
| 5 | Tailscale ACL review + `AllowUsers` line | **Still open** — nothing applied yet (needs your input: admin console review, and whether to add `AllowUsers`/try Tailscale SSH) |
| 6 | 5 sysctl additions | **Done** |
| 7 | VM/container connection URI awareness | No code change — decision framework for when you start using it |
| 8 | 2FA/TOTP for untrusted devices | **Deferred** — needs its own design pass (PAM TOTP vs. Duo) |

Remaining open items: **5** — the `AllowUsers` line is still a one-line,
zero-risk addition whenever you want it, and the Tailscale ACL console review
plus a decision on Tailscale SSH vs. OpenSSH are yours to make outside this
repo — and **8**, which needs a design pass before any code lands.
