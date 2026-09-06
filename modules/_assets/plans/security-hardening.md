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

The t480 (`workstation.nix`/`laptop.nix`) trusts the work desktop's and the
iPhone's (Termius) keys; `work.nix` trusts the t480's and the iPhone's keys.
WSL work laptop and Framework 13 aren't real host files yet — extending is a
one-line append per host once they exist.

**Verified end to end, both directions, both machines:**
- iPhone (Termius) → t480: connects with the key, no password prompt, once
  Tailscale itself was reachable from the phone (the actual blocker that day
  — Tailscale's VPN extension had gone idle on iOS, unrelated to this repo).
- t480 → work desktop (`dakota` on Tailscale): `ssh dakota whoami` returns
  `elichall` with `BatchMode=yes` (would hard-fail rather than fall back to a
  password prompt) — confirms `work.nix`'s `homeManager.network` activation
  script correctly appended the t480's key into `~/.ssh/authorized_keys` on
  the work desktop after `nix build .#homeConfigurations.work.activationPackage
  && ./result/activate`.

**Update — `PasswordAuthentication = false` is now DONE.** Key-based login
was verified fleet-wide (work desktop, iPhone/Termius) before flipping this,
per the original plan. `modules/system/network.nix` now sets both
`PasswordAuthentication = false;` and `KbdInteractiveAuthentication = false;`
on the t480.

**New concern raised by the work-desktop test, worth flagging explicitly:**
before this change, reaching the work desktop over Tailscale required an
active step on that end (the work desktop's Tailscale client isn't a
persistent boot-time service the way the t480's is — see the Tailscale
client-persistence discussion below) that may have doubled as a soft
re-authentication gate. Key-based SSH now succeeds in one shot with no such
gate in the loop. For a personal machine that's a pure improvement; for a
work-owned machine holding proprietary data, it's a real access-control
regression from the employer's point of view — the argument for treating
item 8 as higher priority *specifically for that host*, not a nice-to-have.

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

## 8. Second-factor auth for select hosts — DONE on the work desktop

**Implemented and verified:** see
[`completed/2fa-select-hosts-research.md`](./completed/2fa-select-hosts-research.md) for the full
research (personal Duo account, Baylor's institutional Duo, privacyIDEA,
Tailscale SSH check mode) plus the compliance flag specific to this host
(Baylor lab machine, ITAR/DoD-contracted work — verifying with your PI/
Baylor's IT security process is still the right move independent of which
technical option was picked). **Google Authenticator TOTP was chosen** —
zero cost, zero account/signup, zero third-party service in the auth path —
and is now the **preferred pathway** for 2FA on this fleet going forward.
SSH into the work desktop now requires the t480's key *and* a TOTP code, no
Unix password anywhere in the flow. That doc's §4 has the full runbook and
the gotchas actually hit (Tailscale SSH silently superseding the real
`sshd`, a client-config/server-config filename mixup, a PAM double-auth
overcorrection, and a same-filename key mixup across hosts) — worth reading
before doing this again on another host.

**Remaining work, not this host:** the future NixOS server host (t480,
post-Framework-13-handoff) will very likely need the same treatment,
declaratively this time (`security.pam.services.<name>.googleAuthenticator.enable`
in `security.nix`, plus `AuthenticationMethods` in `network.nix`) — see
`completed/2fa-select-hosts-research.md` §9. Not implemented since that host doesn't
exist yet.

**Original priority-raise context, for the record:** following the
work-desktop key-trust test, key-based SSH worked end to end with no
secondary gate at all
(see the flag at the end of item 1). For a work-owned machine holding
proprietary data, "any personal device holding the right key gets in, no
second factor" is a real concern — you specifically don't want that machine
left with effectively no failsafe/independent check once the key-only path
is what's actually used day to day. This is no longer just a "nice to have
for borrowed devices" item; it's now the top open item for the work desktop
specifically.

**Scope: per-host, not fleet-wide.** This should land as a property of
individual hosts (the work desktop first; the t480/personal devices are
lower priority since the "failsafe if I lose my key" risk there is entirely
your own to accept) — not a single fleet-wide policy. It composes naturally
with the existing per-host `host.trustedSshKeys` design: a future
`host.require2fa` (or similar) option would let `network.nix`/`homeManager.network`
branch per host as trust-model needs already do.

**Two use cases this needs to cover, not just one:**
1. **Untrusted/non-key-holding device** (a borrowed machine, a new device
   before enrollment) — falls through to password + second factor instead of
   being locked out entirely.
2. **Key-holding device on a sensitive host** (the work desktop case just
   found) — even a *registered* key shouldn't be sufficient on its own for
   that specific machine; the second factor should apply there regardless of
   whether the connecting device already holds a trusted key. This is the
   part the original framing (item 8 as originally written) didn't cover and
   the work-desktop test surfaced.

This still needs its own research/design pass before implementation — options
worth comparing when you get to it:
- **PAM TOTP** (`pam_google_authenticator` or similar) — self-hosted, no
  third-party service, standard authenticator app (Google Authenticator,
  Authy, etc.) scans a QR code once per device/account at enrollment. Can be
  layered so it fires unconditionally on a given host regardless of key
  auth, addressing use case 2 above.
- **Duo** — third-party service, push-based approval instead of typing a
  code, but adds an external dependency or subscription for what's
  currently a fully self-contained personal setup. Also worth checking
  whether your employer already runs Duo for other systems — if so,
  integrating with their existing instance may be preferable to standing up
  a separate personal one on a work-owned machine.

**Update:** `PasswordAuthentication` is now `false` (item 1). Use case 1
(untrusted device, no key) is no longer covered by leaving password auth on
— it's tracked separately in item 9, considered and deliberately not
pursued. Use case 2 (key-holder still gated on a select host) remains what
§4 of this item and item 8 actually solved.

---

## 9. Outside-fleet fallback auth — CONSIDERED, NOT PURSUED

Now that `PasswordAuthentication = false` fleet-wide (item 1) removes the
old implicit "just use the password" fallback, a password+TOTP fallback for
devices without a registered `host.trustedSshKeys` entry was designed and
then deliberately dropped on review — moved to
[`deferred/outside-fleet-totp-auth.md`](./deferred/outside-fleet-totp-auth.md).

**Why:** a standing, always-network-reachable password fallback goes against
where common practice actually points (pubkey-only + curated device list is
the more current-best-practice posture, not a gap to fill), the scenario it
covers is compound-rare (would need to lose every registered device
simultaneously), and the bulk-deployment-tooling motivation for wanting
"access from anywhere" turned out to be orthogonal — deploying config onto a
new machine doesn't require the existing fleet to accept inbound connections
from it.

**Kept for later, not in scope now:** a genuine offline **break-glass**
keypair — private half on a USB drive kept physically on hand, never on a
networked device, combined with the account password and a TOTP code for a
real three-factor recovery path that's only reachable by someone holding the
physical object. Architecturally different from the dropped design (that one
made the fallback always-available over the network); worth building
properly if this ever becomes a real need. See the deferred doc for the
full reasoning.

---

## Summary / suggested order of implementation

| # | Item | Status |
|---|------|--------|
| 1 | SSH key-based auth + disable `PasswordAuthentication` | **Done, fully** — key trust verified fleet-wide, then `PasswordAuthentication`/`KbdInteractiveAuthentication` set to `false` on the t480 |
| 2 | `host.hostName` option + fix `network.nix` | **Done** — both hosts still point at `t480-nixos` (same physical machine); revisit at the Framework 13/server split |
| 3 | `trusted-users` | No action — already correct |
| 4 | PAM faillock, deny=5 | **Done** — `login`/`sudo`/`sshd`, no hardcoded module path needed |
| 5 | Tailscale ACL review + `AllowUsers` line | **Still open** — nothing applied yet (needs your input: admin console review, and whether to add `AllowUsers`/try Tailscale SSH) |
| 6 | 5 sysctl additions | **Done** |
| 7 | VM/container connection URI awareness | No code change — decision framework for when you start using it |
| 8 | 2FA for select hosts (work desktop first) | **Done** — Google Authenticator TOTP live on the work desktop, key+TOTP verified end to end; now the preferred pathway; NixOS server host (future) still pending, see `completed/2fa-select-hosts-research.md` §9 |
| 9 | Outside-fleet fallback auth (no key → password+TOTP) | **Considered, not pursued** — see `deferred/outside-fleet-totp-auth.md`; offline break-glass USB key kept as a possible future item, not in scope |

Remaining open item: **5** — the `AllowUsers` line is still a one-line,
zero-risk addition whenever you want it, and the Tailscale ACL console review
plus a decision on Tailscale SSH vs. OpenSSH are yours to make outside this
repo. Item **8** is done for the work desktop; its only remaining piece is
the future NixOS server host, not actionable until that host exists. Item
**9** is closed as "not pursued" — no further action unless a real need for
break-glass access actually shows up.
