# Skill: Flake Module Evaluation Validation

## Precondition
The flake will not evaluate until its source files are tracked by Git
(`nix` only sees tracked files). Run `git add flake.nix modules/` before
validation. A dirty tree after that is fine.

Note: asset files (icons, configs) must also be tracked. `modules/_assets/`
is inside the flake source; do NOT ignore it (the root-level `.gitignore`
rule `_assets/` was anchored to `/_assets/` so `modules/_assets` is tracked).

## Validation Workflow

Execute these commands in sequence to verify changes without running `nixos-rebuild switch`.

> **Scoping — when to run step 5 (full toplevel build)**: a full
> `nix build …toplevel` is required **only when core Nix items changed**
> (module option logic, packages/dependencies, imports, flake structure/inputs,
> or any Nix expression affecting evaluation topology). Editing application
> config/data files embedded via `builtins.readFile`/`writeText`/`replaceStrings`
> (e.g. `otter-launcher/config.toml`, profile JSON, swatches, script bodies that
> only change runtime behavior) changes the application's output data, not the
> Nix evaluation — skip step 5 and instead build the targeted derivation (e.g.
> `nix build .#nixosConfigurations.<hostname>.config.home-manager.users.<user>.xdg.configFile."otter-launcher/config.toml".source`),
> parse-check the format (`builtins.fromTOML`/`fromJSON`), and run the fast dry
> evals (steps 3–4). The user still deploys + smoke-tests after any change.

### 1. Syntax Verification
Check for syntax errors across all modules imported by `import-tree`:
~~~bash
nix-instantiate --parse modules/**/*.nix > /dev/null
~~~
Note: empty `.nix` files are syntax errors. Keep placeholders valid
(e.g. `{ inputs, ... }: { }`).

### 2. Trace Flake Module Export Registry
Verify that `flake-parts` registered every module attribute path under
`config.flake.modules`:
~~~bash
nix eval .#modules --apply 'm: { nixos = builtins.attrNames m.nixos; homeManager = builtins.attrNames m.homeManager; }'
~~~
(There is no `.#flakeModules` output on this flake.)

### 3. Fast Dry Evaluation of Host Configurations
Instantiate top-level NixOS attributes without building binaries:
~~~bash
nix eval .#nixosConfigurations.<hostname>.config.system.build.toplevel.drvPath
~~~
Works since `nixos.hardwareConfig` (t480 fileSystems/boot) was wired into
`workstation.nix`; previously failed on the `fileSystems` assertion.

If host is a standalone home manager configuration then:
~~~bash
nix eval .#homeConfigurations.<hostname>.activationPackage.drvPath
~~~

### 4. Fast Dry Evaluation of Home Manager Configurations
Instantiate Home Manager attributes for a specific user:
~~~bash
nix eval .#nixosConfigurations.<hostname>.config.home-manager.users.<user>.home.activationPackage.drvPath
```
The whole home-manager config must type-check; both this and the `toplevel`
eval are now valid exit gates before committing.

### 5. Warning-Free Evaluation
Capture eval output and assert there are no warnings before switching:
~~~bash
nix build .#nixosConfigurations.workstation.config.system.build.toplevel 2>&1 | rg -i "warning|renamed|mismatch" || echo "NO WARNINGS"
~~~
Only run this full build for core Nix changes (see the scoping note above).
Two warnings must never reappear:
- `'system' has been renamed to/replaced by 'stdenv.hostPlatform.system'` —
  a `pkgs.system` accessor leaked back in. Grep modules for `pkgs\.system`.
- Home Manager "versions mismatched" — the `home-manager` input is not on the
  release branch matching nixpkgs (currently `release-26.05`).

### 6. drvPath Identity Gate (comment/docs-only changes)
For changes that must not alter evaluation (comment trims, doc edits,
header→docs consolidation): both drvPaths must be byte-identical before/after.
Record the known-good paths from the last full build:
~~~bash
nix eval --raw .#nixosConfigurations.workstation.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.workstation.config.home-manager.users.elichall.home.activationPackage.drvPath
```
A hash change here means the change was NOT comments-only.

### 7. Post-Switch Verification
After a deployed switch, run `./post-switch-smoke-test.sh` (read-only) and
confirm 0 failures. See `modules/_assets/documentation/user/maintenance.md` for the rebuild/update
ritual.

## Failure Diagnostics
- **`attribute '...' missing`**: Verify that `modules/flake-parts.nix` exports `inputs.flake-parts.flakeModules.modules`.
- **`infinite recursion encountered`**: Check for circular references between `config.flake.modules` exports and top-level `specialArgs`; also check that every file under `modules/` is a proper flake module (`flake.modules.*`) — a bare NixOS module (raw `imports = [ (modulesPath + ...) ]` path/string, `fileSystems`, `boot.*`) pulled in by `import-tree` will recurse the flake-parts eval. Wrap machine-specific NixOS configs as registry modules (see `dendritic-conventions` skill).
- **`Module imports can't be nested lists`**: `mkFlake` takes a *single* module as its second argument — pass `(inputs.import-tree ./modules)` directly, not `[ ... ]`.
- **`home-manager.users.<user>.modules` does not exist`**: Current Home Manager uses `imports` for user config, not `modules`.
- **`fzf ... nushell integration` assertion**: HM 26.05 defaults every shell integration on. Disable unused ones (`home.shell.enableNushellIntegration = false` etc.).
- **`function ... unexpected argument 'specialArgs'`**: Current `homeManagerConfiguration` takes `extraSpecialArgs`, not `specialArgs`.
- **Home Manager "versions mismatched" warning**: `home-manager` input resolved off its release branch. Fix = pin `home-manager` to the nixpkgs-matching release (`github:nix-community/home-manager/release-26.05`) + `nix flake lock --update-input home-manager`, then commit flake.nix + flake.lock.
- **`'system' has been renamed` warning**: a `pkgs.system` accessor. Fix = `pkgs.stdenv.hostPlatform.system` (3 known sites: `display/otter-launcher/otter.nix`, `display/waybar.nix`, `display/tui.nix`).
- **`result` symlink appears in `git status`**: transient `nix build` output. Don't commit it; `.gitignore` covers `results*/` but not singular `result`.
- **Spot-checking `environment.systemPackages` membership**: never compare with `builtins.elem "<name>"` against the raw list — it holds *derivations*, and `p.name` includes the version (`"awww-0.9.2"`). Map names first:
  ~~~nix
  map (p: (builtins.parseDrvName p.name).name) config.environment.systemPackages
  ~~~
- **`Path '...' does not exist in Git repository` on `builtins.readDir`/path literals**: relative paths resolve from the *file's* directory, and Nix verifies them against the tracked git tree. Compute the literal relative to the module file's own directory:
  - `modules/home.nix` (depth 1) reaches `modules/_assets/icons` via `./_assets/icons`.
  - `modules/display/tui.nix` (depth 2) reaches the same dir via `../_assets/icons`.
  - Anything resolving to `<repo-root>/_assets/icons` (outside the tree) fails with this error. Paths must also be `git add`ed.
- **Redundancy refactor (TUI launcher)**: TUI app binaries + desktop entries + wrappers + icons are a *display-launcher* feature, not core system programs — keep them isolated in `modules/display/tui.nix` (`homeManager.tui`), NOT in `nixos.main` systemPackages or `homeManager.main`. Relocating a module between directories is safe (no cross-module imports); only path *literals* to `_assets` must be recomputed per the rule above.
