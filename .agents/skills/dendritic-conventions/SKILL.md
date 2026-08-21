# Skill: Dendritic Nix Conventions

## Purpose
How this repository's module system is structured. Read this before creating,
moving, or modifying any `.nix` file under `modules/`.

## Core Mechanism
`flake.nix` passes `./modules` to `import-tree`, which recursively discovers
every non-underscore `.nix` file and feeds them into `flake-parts`. Every
file MUST export at least one `flake.modules.*` attribute. Files that don't
export a module break the eval.

## Module Naming
- **Feature modules**: `flake.modules.<scope>.<featureName>` — the
  `<featureName>` is the registry key (e.g. `homeManager.hyprland`,
  `nixos.mime`).
- **Options modules**: `flake.modules.homeManager.<name>Opt` or
  `options<Name>` — distinct from the feature module name to avoid
  collisions. Suffix `Opt` in filenames enables mini.pick file searching.
- **Group modules**: `flake.modules.<scope>.<groupName>` — aggregate
  imports only, no config setting (e.g. `homeManager.desktop`,
  `nixos.base`).

## Dual-Scope Modules
A single file can export both `flake.modules.nixos.*` and
`flake.modules.homeManager.*`. This is correct when a feature has both
system-level and user-level concerns in one aspect (e.g. `hyprland.nix`
exports `nixos.hyprland` for the compositor and `homeManager.hyprland`
for keybinds; `mime.nix` exports `nixos.mime` for XML registration and
`homeManager.mimeDefaults` for default applications).

## Group Structure
Groups live in `modules/groups/` and bundle related aspects:
- `nixos.base` = battery, network, hardware, audio, security
- `nixos.desktop` / `nixos.desktopExp` = display, hyprland, mime
- `homeManager.options` = option declarations (`options/*Opt.nix`)
- `homeManager.toolbox` = cmdLine, git, tmux, nvim, yazi, opencode
- `homeManager.desktop` / `homeManager.desktopExp` = display features
- `homeManager.utils` = interactionWatch, notifySend, initProject
- `homeManager.researchGroup` = research, obsidian, zotero

Groups are imported by hosts. Individual keys remain importable alongside
groups.

## Underscore Prefix Convention
Files/directories prefixed with `_` (e.g. `_assets/`, `_draft.nix`) are
IGNORED by `import-tree`. Use this for:
- Static resources (`_assets/`)
- Work-in-progress files (`_draft.nix`)
- Anything that should NOT be auto-imported

## Path Agnosticism (Rule 2)
Moving a file within `modules/` must never break the build. Consequence:
- Never use `import ../foo/bar.nix` between feature modules.
- Path LITERALS to `_assets/` are OK (they resolve from the file's own
  directory) — recompute the relative path when moving files.
- Registry access is always via `self.modules.<scope>.<name>`, never
  via file paths.

## Scope Separation (Rule 3)
- `nixos.*` (system scope): kernel, boot, hardware, system services,
  system packages, user account definitions.
- `homeManager.*` (user scope): shell aliases, dotfiles, user packages,
  desktop styling, tool-specific settings.

Never mix: a `homeManager.*` module must not set NixOS options, and
vice versa.

## Dependency Self-Containment (Rule 4)
Every module declares every package it uses in its own `home.packages` or
`environment.systemPackages`. Duplicate declarations across modules are
allowed (lists merge; same store path deduplicated). This ensures removing
one module never breaks another's runtime.

## Adding a New Module
1. Create `modules/<category>/<feature>.nix`.
2. Export `flake.modules.<scope>.<feature> = { ... }: { ... };`.
3. If it's a feature module: add packages to `home.packages` / `environment.systemPackages`.
4. If it's an option module: use `*Opt.nix` suffix, export under `options<Name>`.
5. Add to the relevant group in `modules/groups/` if it belongs to a preset.
6. `git add` the file (nix only sees tracked files).
7. Run the validation workflow (see `flake-validator` skill).
