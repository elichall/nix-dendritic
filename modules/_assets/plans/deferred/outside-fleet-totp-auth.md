# Outside-Fleet SSH Auth via Google Authenticator — Considered, Not Pursued

**Status: deferred.** Considered and deliberately not implemented — kept
here as a record of the reasoning, not as an active plan. Moved to
`plans/deferred/`.

## Why this was dropped

Written after disabling `PasswordAuthentication` on the NixOS fleet (t480:
`workstation`/`laptop`), this doc originally planned a password+TOTP
fallback (§2-5 below) for a device without a registered
`host.trustedSshKeys` entry. On review, that turned out to be solving a
problem not actually encountered, and going against the direction common
practice actually points:

- **The industry trend is away from standing password fallbacks, not
  toward them** — the modern answer to "flexible access" is short-lived,
  purpose-scoped credentials (SSH certificate authorities), not an
  always-available password+TOTP door. Pubkey-only with a curated device
  list (what's already in place) is the *more* current-best-practice
  posture, not a gap.
- **What this was actually reaching for has a name: "break-glass" access**
  — and the standard version of that pattern is deliberately *inconvenient*
  to use (physical possession required), not *available* (reachable from
  any networked device at any time). A live password+TOTP path is the wrong
  shape for that need even if the need itself is real.
- **The scenario is compound-rare**: it requires losing the t480 *and* the
  iPhone *and* not being physically at the work desktop simultaneously —
  and the t480 always has a non-network fallback anyway (walk up to it,
  use the console).
- **Bulk-deployment tooling (the wrapper-plan idea) doesn't actually depend
  on this.** Deploying dotfiles/config onto a fresh machine via this flake
  is that machine building its *own* environment locally — it doesn't
  require the existing fleet to accept *inbound* connections from anywhere.
  The two are orthogonal.
- **Cross-device data/config portability belongs in git/cloud storage**
  (which this repo already is), not in a standing SSH backdoor on personal
  infrastructure.

## Kept for later: the version of this that *would* be worth building

Not in scope now, but attractive enough to record rather than lose: a
genuine **offline break-glass key** — a dedicated keypair whose private half
lives only on a USB drive kept somewhere physical (e.g., a backpack), never
on any networked device, with its public half already trusted
(`host.trustedSshKeys`) on whichever hosts should honor it. Recovery would
require **physical possession of that USB drive** plus the account
password plus a TOTP code (in this case tied to a personal Google
account/authenticator, not a separate secret) — three real factors,
only reachable by someone who has the physical object in hand, not by
anything sitting on the network 24/7. This is architecturally different
from §2-5 below (which made the fallback *always* network-reachable) and
would be worth designing properly if this ever becomes a real need — revisit
this doc if that happens, rather than starting over.

---

## Original planning (kept for reference, not being pursued)

## 1. Why this is a real question, not hypothetical

Before this session's work, `PasswordAuthentication = true` was — whether
intentionally or not — the fleet's outside-device fallback: lose your
phone, sit down at a borrowed machine, whatever, and the account password
got you in. That's gone now. Nothing currently replaces it. This doc exists
so that gap is a documented, deliberate decision rather than a surprise the
next time it's needed.

## 2. The core design: `AuthenticationMethods` with alternative method-sets

OpenSSH's `AuthenticationMethods` accepts **multiple space-separated
alternatives**, each itself a comma-separated *combination* that must all
succeed together. This is the mechanism that makes a tiered fleet/non-fleet
policy possible in one line:

```
AuthenticationMethods publickey keyboard-interactive
```

Read as: authenticate via **either** `publickey` alone (fast path — any
device holding a `host.trustedSshKeys`-registered key), **or**
`keyboard-interactive` alone (slow path — no key at all, falls into
whatever PAM's `auth` stack for `sshd` demands).

**This does *not* reopen `PasswordAuthentication`.** The outside-fleet path
runs entirely over `keyboard-interactive`/PAM, the same mechanism already
proven working on the work desktop for key+TOTP — it's a genuinely
different SSH-level method than the native `password` method, so
`PasswordAuthentication` can stay `false` exactly as just configured while
this fallback still exists. No contradiction between the two changes.

## 3. What the PAM side needs to enforce for the fallback path

Unlike the work desktop (key + TOTP, password intentionally *removed* from
the stack via commenting out `@include common-auth`), the outside-fleet path
here needs the **opposite composition**: password *and* TOTP both required,
since there's no key in the picture at all to serve as the first factor.

NixOS's PAM module already includes Unix password checking by default
(`security.pam.services.<name>.unixAuth`, defaults `true` — confirmed in
`nixos/modules/security/pam.nix`, the same file the `faillock` and
`googleAuthenticator` work already touched). So the addition needed is just:

```nix
security.pam.services.sshd.googleAuthenticator.enable = true;
```

layered on top of the existing default Unix-password rule — NixOS composes
these declaratively (no `@include`-style manual stacking/footgun like the
Debian-style PAM file hit on the work desktop). The result: the
`keyboard-interactive` branch of `AuthenticationMethods` above would prompt
for the account password *and* a TOTP code, both required, before a
non-fleet device gets in.

## 4. Open questions — real trade-offs, not implementation details

This isn't a pure technical exercise; adding *any* password-reachable path
back onto the fleet, even TOTP-gated, is a deliberate re-widening of the
attack surface `PasswordAuthentication = false` just closed. Worth deciding
consciously before implementing, not defaulting into:

- **Same account, or a separate one?** Using `elichall`'s own real Unix
  password as one of the two factors means a compromised or guessed
  password is only one factor away from getting in (mitigated by
  `deny=5` faillock lockout already in `security.nix`, but not eliminated).
  A dedicated low-privilege guest account with its own password could scope
  the blast radius, at the cost of extra setup (a second account, its own
  TOTP secret, deciding what that account is even allowed to do once in).
- **Is this actually needed, or is it solving a problem that doesn't exist
  yet?** The fleet today is small (t480, work desktop, iPhone) and you
  control all of it. "Outside fleet access" matters most for scenarios like
  a lost/wiped phone with no other enrolled device nearby — worth naming the
  actual scenario this needs to cover before building for it, since a
  narrower need might have a narrower (and safer) answer than "password +
  TOTP always available."
- **Should this exist on every NixOS host, or just the t480?** Per the same
  per-host philosophy as `host.trustedSshKeys`, this probably shouldn't be a
  blanket fleet policy — worth deciding per host whether the fallback path
  should even exist there at all.
- **Rate-limiting/lockout interaction:** `security.pam.services.sshd`
  already has `faillock` (`deny=5`, `unlock_time=900`, from
  `security-hardening.md` item 4) — confirm it actually applies to the
  `keyboard-interactive`/password branch specifically once this is added,
  not just the paths it was originally verified against.

## 5. Not-yet-decided implementation sketch (for when the above is resolved)

```nix
# modules/system/network.nix, nixos.network
services.openssh.settings.AuthenticationMethods = "publickey keyboard-interactive";

# modules/system/security.nix, nixos.security
security.pam.services.sshd.googleAuthenticator.enable = true;
# allowNullOTP = true;  # first-rollout safety net, matching the work-desktop
                          # runbook's `nullok` — flip off once verified
```

Same safe-rollout discipline as the work desktop: enable with
`allowNullOTP = true` first, enroll (`google-authenticator`, run once as
`elichall`), verify from a fresh session while keeping the current one open,
*then* flip `allowNullOTP` off.

## Verification

None yet — planning only. Once §4's questions are answered, verification
would mirror the work desktop's: confirm fleet devices (`host.trustedSshKeys`
holders) still get in via pubkey alone with no behavior change, then confirm
a device *without* a registered key gets prompted for password + TOTP
rather than being rejected outright.
