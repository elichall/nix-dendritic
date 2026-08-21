# Dendritic Nix Architecture Directive

This repository implements a **Dendritic Nix** configuration architecture powered by [`flake-parts`](https://flake.parts/) and [`import-tree`](https://github.com/denful/import-tree). All contributors and autonomous agents must strictly adhere to the patterns and principles defined below when modifying or expanding this codebase.

---

## 1. Project Objectives

### Short-Term Goal — COMPLETE (workstation deployed 2026-08-11)
The workstation is fully migrated: the legacy `/etc/nixos` config was ported
to the dendritic flake and is LIVE on this machine via
`nixos-rebuild switch --flake ~/.nix#workstation`. Remaining
work is cross-platform hosts (`wsl`/`ubuntu`/`macos`/`server` stubs exist,
blocked on `specialArgs` → `extraSpecialArgs`) and stretch items (see TODO.md).

### Long-Term Goal
Build a universal, monolithic Nix repository capable of configuring **any** target machine from a single clone:
- **NixOS Workstations**
- **NixOS Servers**
- **Non-NixOS Linux** (via standalone Home Manager)
- **macOS** (via `nix-darwin` + Home Manager)
- **WSL Instances** (Windows Subsystem for Linux)

Target systems instantiate their environment by creating a specific host entry (e.g., `modules/hosts/<hostname>.nix`) that sets explicit feature flags (e.g., `isWSL = true;`, `isDesktop = true;`, `isServer = true;`). System and user modules dynamically read these flags and adapt their evaluations accordingly.

---

## 2. Workspace Layout & Existing Configuration

- `./modules/`: The dendritic root. `import-tree` recursively traverses and imports every tracked `.nix` file (except `_`-prefixed) into the `flake-parts` pipeline.
- `./flake.nix` / `./flake.lock`: High-level entrypoint loading inputs and passing `./modules` to `import-tree`. `flake.lock` is the ONLY version pin — there are no channels.
- `./modules/_assets/`: Tracked static resources, documentation, and plans (see §8).
  - `_assets/aesthetics/`: Visual resources — `icons/`, `wallpapers/`, `nixos-image.png`, `font_vault.md`.
  - `_assets/dotfiles/`: Nix-managed application dotfiles (e.g. `dotfiles/nvim/`).
  - `_assets/documentation/`: Decision logs, module contracts, and user guides — the project's knowledge base.
    - `documentation/decisions.md` — ADR-style decision log (WHY).
    - `documentation/module-contracts.md` — Module registry map + cross-module interface contracts.
    - `documentation/ghostty-transparency.md` — GTK palette-only postmortem.
    - `documentation/user/` — User-facing guides to system functionality.
      - `user/maintenance.md` — System upkeep (updates, rollback, GC, cheat sheet).
      - `user/research.md` — Research workflow guide.
  - `_assets/plans/`: Active and archived work plans.
    - `plans/*.md` — Active plans (top-level files).
    - `plans/completed/` — Finished plans (reference only).
    - `plans/deferred/` — Paused or deferred plans.
- `./modules/_lib/`: Shared non-module Nix helpers (`browser`, theme paths, `interaction-watch`). Not auto-imported; consumed via explicit relative `import`.
- `./legacy/` (gitignored): Frozen snapshot of the pre-flake `/etc/nixos` config — reference only. NOTE: `legacy/` carries pre-fix bugs (e.g. the gtk.css transparency bug); port from the LIVE `/etc/nixos` tree when in doubt.
- `./nixos -> /etc/nixos` (gitignored symlink): inert pre-switch config. A bare `nixos-rebuild switch` (no `--flake`) would fall back to it — ALWAYS pass `--flake`.
- `./post-switch-smoke-test.sh`: read-only post-rebuild verification script (run after every switch).

---

## 3. Core Architecture Rules

### Rule 1: Aspect-Oriented Module Structure
Do **NOT** split features into separate directories based on target system classes (e.g., avoiding `nixos/`, `home-manager/`, `darwin/` subtrees). 

Instead, group configurations by **feature aspect**. A single file must contain all system-level, user-level, and target-specific definitions for that specific tool or feature under `flake.modules`.

```nix
# Example: modules/editors/neovim.nix
{ inputs, ... }: {
  flake.modules = {
    # System scale (NixOS)
    nixos.neovim = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.neovim ];
    };

    # User scale (Home Manager)
    homeManager.neovim = { pkgs, ... }: {
      programs.neovim = {
        enable = true;
        defaultEditor = true;
      };
    };

    # Darwin scale (macOS)
    darwin.neovim = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.neovim ];
    };
  };
}
```

### Rule 2: Path Agnosticism & Import Tree
- Every `.nix` file in `./modules/` is imported automatically by `import-tree`.
- Never use explicit relative imports (`import ../foo/bar.nix`) between feature modules inside `./modules/`.
- Moving a file to a different folder inside `./modules/` must **never** break the build.
- Files or directories prefixed with an underscore (e.g., `_draft.nix` or `_lib/`) are ignored by `import-tree`.

### Rule 3: Strict Scope Separation
- **NixOS / System Scope (`flake.modules.nixos.<feature>`)**: Restrict to system-wide concerns—kernel parameters, bootloaders, hardware graphics, system-level systemd services, binary caches, user account definitions, and system packages.
- **Home Manager / User Scope (`flake.modules.homeManager.<feature>`)**: Restrict to user-level configurations—shell aliases, dotfiles, user binaries, desktop environment styling, user systemd units, and tool-specific settings (e.g., `programs.starship`, `programs.git`).

### Rule 4: Per-Module Dependency Self-Containment
Every feature module must declare **all** of the packages it depends on **inside its own module** — regardless of whether that module is the one that *configures* the tool. Package presence and package configuration are independent concerns.

- A module may add a dependency without owning its configuration. Example: a `noctalia` module adds `pkgs.fastfetch` to `home.packages` so its user scripts reach the binary via PATH, while the actual fastfetch customization lives in `modules/programs/fastfetch.nix`.
- Duplicate declarations of the same package across modules are **explicitly allowed and encouraged** for isolation. `environment.systemPackages` and `home.packages` are list options that merge by concatenation; the same store path appearing more than once is harmless (deduplicated in the final profile).
- **Consequence**: removing a module from a host never breaks another module's runtime. A host importing `homeManager.noctalia` *without* `homeManager.fastfetch` still gets a working (unconfigured, default) `fastfetch`; importing both applies the fastfetch configuration on top.
- **Limits**: the rule applies to mergeable list options only. Non-list options set to different values across modules raise "conflicting definitions" errors — feature *configuration* must remain owned by exactly one module. Also declare a dependency at a single scope level matching its consumer (user tooling in `home.packages`, system services in `environment.systemPackages`); avoid redundant system + user duplication of the same package.
- **Reference example**: `modules/programs/fastfetch.nix` (`homeManager.fastfetch`) is home-only; `modules/display/experimental/waybar.nix` declares the same binary as a dependency (list merge — deduplicated in the final profile).

---

## 4. Host Configuration & Flag Adaptation Pattern

Host definitions aggregate feature aspects from `config.flake.modules` and expose feature flags to conditionally adapt system behaviors.

```nix
# Example: modules/hosts/workstation-wsl.nix
{ inputs, config, lib, ... }: {
  flake.nixosConfigurations.wsl-workstation = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      inputs.wsl.nixosModules.default
      inputs.home-manager.nixosModules.home-manager

      # Import feature aspects from dendritic registry
      config.flake.modules.nixos.cmdLine
      config.flake.modules.nixos.git

      ({ pkgs, ... }: {
        wsl.enable = true;
        wsl.defaultUser = "elijah";
        networking.hostName = "wsl-workstation";
        system.stateVersion = "24.05";

        # Custom system flags accessible by modules
        custom.flags = {
          isWSL = true;
          isDesktop = false;
        };

        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;

        home-manager.users.elijah = { ... }: {
          imports = [
            config.flake.modules.homeManager.cmdLine
            config.flake.modules.homeManager.git
          ];
          home.stateVersion = "24.05";
        };
      })
    ];
  };
}
```

---

## 5. Agent Migration Checklist

The workstation migration is COMPLETE (all legacy `nixos/*.nix` and
`modules/*.nix` ported; see TODO.md). Use this checklist for any future ports
(cross-platform hosts, quickshell). When porting a legacy configuration file
from the live `/etc/nixos` tree or the `legacy/` snapshot:
1. Identify all tools/features declared in the file.
2. Create or locate the corresponding feature module in `./modules/<category>/<feature>.nix`.
3. Separate NixOS options (`environment.systemPackages`, `services.*`) into `flake.modules.nixos.<feature>`.
4. Separate Home Manager options (`programs.*`, `home.file`, `home.packages`) into `flake.modules.homeManager.<feature>`.
5. Remove redundant manual hooks (e.g., `hm-session-vars.sh` sourcing) when handled natively by Home Manager integration.
6. Verify syntax and option domains before finalizing changes.

## 6. Repository State & Skill Maintenance Protocol

Autonomous agents operating in this repository must actively manage project execution state and refine their domain tooling.

### TODO.md Tracking Rules
Agents must create and maintain a `TODO.md` file at the repository root to reflect active work.
- **Task Classifications**:
  - `[ ]` **Unassigned / Backlog**: Pending migration tasks or unstarted feature modules.
  - `[/]` **In Progress**: Currently active task being processed by the agent.
  - `[x]` **Completed**: Tested, validated, and fully integrated dendritic module.
  - `[S]` **Stretch Goals**: Optional architecture enhancements (e.g., custom Flake checks, `nix-darwin` integration, automated integration tests).
- **Update Frequency**: Every file modification or porting step must immediately be reflected in `TODO.md` before concluding an execution cycle.

### Self-Maintenance of Agent Skills
- **Skill Creation**: If an agent discovers recurring edge cases, domain bugs, or novel refactoring patterns during migration, it must create or update the relevant skill file in `.agents/skills/<skill>/SKILL.md`.
- **Skill Refinement**: When a skill instruction leads to an evaluation error, the agent must correct the instruction in the corresponding skill file once the root cause is resolved.

### Existing Skills (load before working)
| Skill | Path | When to load |
|-------|------|-------------|
| `dendritic-conventions` | `.agents/skills/dendritic-conventions/SKILL.md` | Any module creation, move, or restructuring |
| `options-architecture` | `.agents/skills/options-architecture/SKILL.md` | Cross-module value sharing, options files, host overrides |
| `noctalia-integration` | `.agents/skills/noctalia-integration/SKILL.md` | Noctalia hooks, templates, conditional branching |
| `assets-lib` | `.agents/skills/assets-lib/SKILL.md` | `_assets/` references, path literals, docs convention |
| `domain-classifier` | `.agents/skills/domain-classifier/SKILL.md` | NixOS vs HM scope classification |
| `flake-validator` | `.agents/skills/flake-validator/SKILL.md` | Evaluation, validation, diagnostics |
| `package-provisioning` | `.agents/skills/package-provisioning/SKILL.md` | Adding new packages (tier 1/2/3) |
- **Docs Convention**: Extended prose (decisions, contracts, rationale) lives in `modules/_assets/` docs (see §8) — NOT in module headers. Module headers carry only short pointers. When a decision/contract changes, update the relevant `_assets` doc in the same change.
- **Post-Switch Verification**: after deploying a new generation, run `./post-switch-smoke-test.sh` (read-only) and confirm 0 failures before concluding the cycle.

---

## 7. Deployment, Verification & Maintenance

### Rebuild (always `--flake`)
```bash
sudo nixos-rebuild switch --flake ~/.nix#workstation
```
A bare `nixos-rebuild switch` reads the inert `/etc/nixos` config — always pass
the flake path + host key. Dry-run/build without switching:
`nix build .#nixosConfigurations.workstation.config.system.build.toplevel`.

### Verification scoping (when a full build is required)
A full `nix build .#…config.system.build.toplevel` is required **only when
core Nix items changed**: module option logic, packages/dependencies, imports,
flake structure/inputs, or any Nix expression that affects evaluation topology.
Run the fast dry evals + warning gate instead for everything else (see the
`flake-validator` skill).

Editing **application config/data files** — anything embedded via
`builtins.readFile` / `writeText` / `replaceStrings` (e.g.
`modules/display/otter-launcher/config.toml`, profile JSON, swatches,
script bodies that only change runtime behavior) — changes the *application's
output data*, not the Nix evaluation. A full toplevel build adds no signal;
validate with the targeted derivation build (e.g.
`nix build .#nixosConfigurations.workstation.config.home-manager.users.elichall.xdg.configFile."otter-launcher/config.toml".source`),
a config format check (`builtins.fromTOML`/`fromJSON`), and the fast dry evals.
The user still runs the deploy + smoke test after any change.

### Dependency input hygiene
- Inputs `home-manager`, `wlctl`, `otter-launcher` follow our `nixpkgs` pin.
  `home-manager` is pinned to `release-26.05` to match nixpkgs 26.05 (prevents
  the Home Manager release-mismatch warning).
- Flake-input package lookups use `inputs.<name>.packages.${pkgs.stdenv.hostPlatform.system}`,
  NEVER `pkgs.system` (deprecated accessor; emits an eval warning).
- Provision packages in tier order (nixpkgs → pinned flake input → build from
  source) — see the `package-provisioning` skill.
- Evals must be warning-free before switching (no `'system' has been renamed`,
  no HM version mismatch).

### Full maintenance reference
All day-to-day upkeep (flake.lock update workflow, rollback, GC, hardware
regeneration, command cheat sheet) is documented in
`modules/_assets/documentation/user/maintenance.md` — do not duplicate it here.

---

## 8. Documentation & Knowledge Base (`modules/_assets/`)

The `_assets/` tree is organized into four subdirectories:

### `documentation/` — Project Knowledge Base
Decision logs, contracts, and guides. This is the authoritative reference for
WHY things are the way they are. Module files point here via short header
pointers — never re-embed long prose in module headers.

| Doc | Purpose |
|---|---|
| `decisions.md` | ADR-style decision log — WHY the architecture and rules exist |
| `module-contracts.md` | Module registry map + cross-module interface contracts (the consolidated module headers) |
| `ghostty-transparency.md` | GTK palette-only postmortem |

#### `documentation/user/` — User Guides
System functionality guides written for the end user (not agents).

| Doc | Purpose |
|---|---|
| `maintenance.md` | System upkeep vs the static `/etc/nixos` standard (updates, rollback, GC, cheat sheet) |
| `research.md` | Research workflow guide (nvim, obsidian, vault integration) |

### `plans/` — Work Plans
Active, completed, and deferred work plans. Top-level `.md` files are active;
`completed/` and `deferred/` are archives.

| Dir | Purpose |
|---|---|
| `plans/*.md` | Active plans currently being worked on or under review |
| `plans/completed/` | Finished plans — reference only, do not modify |
| `plans/deferred/` | Paused or deferred plans — may be revisited later |

### `aesthetics/` — Visual Resources
Icons, wallpapers, and branding assets referenced by display modules.

### `dotfiles/` — Nix-managed Application Config
Application dotfile trees installed read-only via `xdg.configFile` (e.g.
`dotfiles/nvim/`).

Convention: cross-module contracts and extended rationale belong in
`documentation/` docs, referenced from module files via short header pointers.
Never re-embed long prose blocks in module headers.
