# Required-Option Errors — a reusable "no default, clear message" pattern

## Context

`modules/options/hostOpt.nix` declares `host.hostName` with no default,
nixos-scope only. This was done so any `nixosConfiguration` missing it fails
at eval time, since two NixOS hosts (`workstation`, `laptop`) currently
target the same physical machine and are kept in sync on hostname on
purpose — but that will need to diverge once the Framework 13 Pro comes in
and the t480 becomes a server host. An accidental unset/duplicate hostname
across genuinely distinct machines would create real collisions (Tailscale
device identity, SSH `known_hosts`, nftables logs), so it needed to be a
hard failure, not a silent default.

Turns out no extra code was needed for `hostName` specifically: `network.nix`
does `networking.hostName = config.host.hostName;` unconditionally, and
upstream `nixos/modules/tasks/network-interfaces.nix` always forces
evaluation of `config.networking.hostName` — it's read inside an `mkIf`
condition, which NixOS's module system evaluates on every build regardless
of which branch is taken. So an unset `host.hostName` already hard-fails any
real build with Nix's standard error:

```
error: The option `host.hostName' is used but not defined
```

`homeConfigurations` never see this at all, since `host.hostName` is only
declared in `flake.modules.nixos.optionsHost`, not
`flake.modules.homeManager.optionsHost` — pure home-manager hosts
(`wsl.nix`, `linux.nix`) don't touch networking identity and shouldn't be
forced to declare it.

This doc exists because that "just works" property is **specific to
`hostName`** — it relies on some *other* always-evaluated upstream module
happening to force the option's evaluation. That's not something to count on
for an arbitrary future "must be set per-host, no sane default" option. If a
second case like this comes up — some option that genuinely has no safe
default and should hard-fail with a clear message if left unset, but isn't
lucky enough to be forced by an unrelated upstream `mkIf` — this is the
pattern to reach for instead of solving it ad hoc again.

**Not built yet.** No second real case exists today, so this is a documented
design, not live code — building it now would be dead infrastructure
(YAGNI). Revisit this file when a second required-option need actually shows
up.

## Design

A small helper pair — `mkRequired` (option) + `requiredAssertion` (message)
— in a new file, `modules/_lib/requiredOption.nix`. This is generic
plumbing, not a `host.*` concern, so it doesn't belong in `hostOpt.nix`.

```nix
# modules/_lib/requiredOption.nix
{ lib, ... }:
{
  # Declares an option that must be set explicitly per-consumer (per-host,
  # per-module, etc). Uses a *nullable* type with `default = null` so
  # evaluating the option never throws Nix's raw "used but not defined"
  # error — that failure is deferred to a paired `requiredAssertion` entry
  # with a hand-written message pointing at what to fix.
  mkRequired =
    { type, description }:
    lib.mkOption {
      type = lib.types.nullOr type;
      default = null;
      inherit description;
    };

  # Pairs with `mkRequired` in the consuming module's `config.assertions`.
  requiredAssertion =
    optionPath: value: hint:
    {
      assertion = value != null;
      message = "`${optionPath}` must be set explicitly (no default by design). ${hint}";
    };
}
```

Consumption sketch — illustrative only, not wired into any real option
today:

```nix
# hypothetical future required option
{ lib, config, ... }:
let
  inherit (import ../_lib/requiredOption.nix { inherit lib; })
    mkRequired
    requiredAssertion
    ;
in
{
  options.host.someRequiredThing = mkRequired {
    type = lib.types.str;
    description = "...";
  };
  config.assertions = [
    (requiredAssertion "host.someRequiredThing" config.host.someRequiredThing
      "set it in modules/hosts/*.nix"
    )
  ];
}
```

## When to reach for this vs. a plain no-default option

- **Check first** whether the option is already read unconditionally by some
  other always-evaluated module (as `hostName` is, via
  `networking.hostName`'s upstream `mkIf` check). If so, a plain
  `lib.mkOption` with no default — no extra machinery — already hard-fails
  correctly, exactly like `host.hostName` today.
- **Reach for `mkRequired`/`requiredAssertion`** only when nothing forces
  the option's evaluation on its own, so a plain no-default option would
  otherwise fail silently (never referenced, never errors, defeats the
  point).
- `assertions` exists in both the nixos and home-manager module systems, so
  the helper works unmodified in either scope — it isn't nixos-specific like
  `hostOpt.nix`'s current `hostName` declaration is.
