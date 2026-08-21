# Skill: Package Provisioning — Order of Operations

When adding a package to this repository, source it in this order. Do NOT
skip tiers: a package already in nixpkgs must not be fetched or built
locally, and a repo with a flake must not be fetched as a tarball.

## Tier 1 — nixpkgs (preferred)

Prefer `pkgs.<name>` from nixpkgs.

1. Check if the package exists:
   ~~~bash
   nix eval nixpkgs#<name>.pname
   ~~~
   - Success → packaged. Use `pkgs.<name>` in the module.
   - `does not provide attribute ...` → not in nixpkgs; go to Tier 2.
2. Beware name differences: the nixpkgs attribute often differs from the
   upstream binary (e.g. `jolt-tui` not `jolt`, `blesh` not `ble.sh`,
   `asciiquarium-transparent`). Use `nix search nixpkgs <name>` if unsure.

## Tier 2 — upstream flake input

The project repo ships a `flake.nix` exposing `packages.<system>.<name>` (or
`default`). Import it as a pinned flake input.

1. Verify the repo has a flake and a usable tag:
   ~~~bash
   curl -s https://raw.githubusercontent.com/<owner>/<repo>/main/flake.nix
   git ls-remote --tags https://github.com/<owner>/<repo>
   ~~~
2. Add to `flake.nix`, pinning to the tag and following our nixpkgs:
   ~~~nix
   wlctl = {
     url = "github:aashish-thapa/wlctl/v0.1.9";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ~~~
   `inputs.nixpkgs.follows` builds the package against OUR pinned nixpkgs
   (single dependency closure) instead of upstream's pinned one.
3. Lock and use it:
   ~~~bash
   nix flake lock
   ~~~
   In the module, `inputs` is already in the file-level signature
   (`{ inputs, ... }`); the `flake.modules.*` deferred-module closure
   captures it. Reference the output:
   ~~~nix
    { inputs, ... }: {
      flake.modules.homeManager.tui = { pkgs, ... }:
      let
        wlctl = inputs.wlctl.packages.${pkgs.stdenv.hostPlatform.system}.default;
      in { ... };
    }
    ~~~
    Use `packages.${pkgs.stdenv.hostPlatform.system}.default` (or the explicit
    attr name) — not the tarball, not a local `buildRustPackage`. NEVER use
    `pkgs.system`: the bare accessor is deprecated and emits the
    `'system' has been renamed to/replaced by 'stdenv.hostPlatform.system'`
    evaluation warning on every rebuild.

## Tier 3 — build from source (last resort)

No nixpkgs attribute and no upstream flake. Keep the derivation local to the
feature module that uses it.

~~~nix
src = builtins.fetchTarball {
  url = "https://github.com/<owner>/<repo>/archive/refs/tags/v<ver>.tar.gz";
  sha256 = "<nix-prefetch-url output>";
};

pkg = pkgs.rustPlatform.buildRustPackage {
  pname = "<name>";
  version = "<ver>";
  src = <src>;
  cargoLock.lockFile = "${src}/Cargo.lock";
  meta = with pkgs.lib; {
    description = "...";
    homepage = "...";
    license = licenses.gpl3Only;
    mainProgram = "<name>";
    platforms = platforms.linux;
  };
};
~~~
Compute the sha256 with `nix-prefetch-url --unpack <tarball-url>`.

## Validation

After provisioning, always:
1. `git add` the changed files (nix only evaluates tracked files).
2. Parse sweep: `find modules -name '*.nix' -exec nix-instantiate --parse {} \;`.
3. Full HM eval (see flake-validator skill):
   ~~~bash
   nix eval .#nixosConfigurations.workstation.config.home-manager.users.elichall.home.activationPackage.drvPath
   ~~~
4. Spot-check the package resolves in `home.packages` and that no
   `fetchTarball` remains for a Tier 2 package.
5. Rebuild must be warning-free: no `'system' has been renamed` (use
   `stdenv.hostPlatform.system`) and no Home Manager release-mismatch.

## Input pinning notes

- Inputs that `follows nixpkgs` (home-manager, wlctl, otter-launcher) build
  against OUR pinned nixpkgs. When nixpkgs moves release, pin `home-manager`
  to the matching release branch (currently `release-26.05`) so the HM
  release check does not fire.

## Current package → tier table

| Package | Tier | Provisioning |
|---|---|---|
| btop, gdu, bluetui, jolt-tui | 1 | `pkgs.*` |
| LSPs (nil, marksman, lua-language-server, texlab, bash-language-server) | 1 | `pkgs.*` |
| wlctl | 2 | `inputs.wlctl.packages.${pkgs.stdenv.hostPlatform.system}.default` |
| otter-launcher | 2 | `inputs.otter-launcher.packages.${pkgs.stdenv.hostPlatform.system}.otter-launcher` |
