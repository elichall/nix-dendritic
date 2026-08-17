# nix-dendritic

A **dendritic Nix configuration** — a single, universal, monolithic repository
capable of configuring any target machine, built on
[`flake-parts`](https://flake.parts/) and
[`import-tree`](https://github.com/denful/import-tree).

Configuration is grouped by **feature aspect**, not by target system. A single
module file holds all scales of one feature — system-level (NixOS),
user-level (Home Manager), and (future) macOS (`nix-darwin`) — and hosts
simply aggregate the aspects they need.

> Status: the **workstation** (Lenovo T480) is fully migrated and deployed via
> this flake (2026-08-11). WSL / Ubuntu / macOS / server host stubs exist.

## Quick start

```bash
# Rebuild + switch the workstation (ALWAYS pass --flake + host)
sudo nixos-rebuild switch --flake ~/.nix#workstation
```

## How it works

- `flake.nix` passes `./modules` to `import-tree`, which recursively imports
  every non-underscore `.nix` file into the flake-parts module system.
- Each file exports `flake.modules.nixos.<feature>` (system scope) and/or
  `flake.modules.homeManager.<feature>` (user scope) — the *registry*.
- `modules/hosts/<hostname>.nix` aggregates registry modules into a
  `nixosConfiguration` or `homeManagerConfiguration` (if host isn't NixOS); aspect groups (`base`, `desktop`, `toolbox`) are
  presets that bundle related aspects.
- `flake.lock` is the only version pin — there are no channels. Inputs
  `home-manager`, `wlctl`, and `otter-launcher` follow the pinned nixpkgs
  (26.05) so the whole tree evaluates against one dependency closure.

## Repository layout

```
flake.nix / flake.lock   Entrypoint + version pin (no channels)
modules/                 The dendritic root (auto-imported by import-tree)
  _assets/               Static resources + docs (icons, wallpapers, decisions…)
  _lib/                  Shared non-module helpers (browser, theme, interaction-watch)
  hosts/                 Host configurations (workstation + wsl/ubuntu/macos/server stubs)
  groups/                Aspect-group presets (base, desktop, toolbox)
  system/ display/ programs/   Feature aspects
legacy/                  (gitignored) frozen snapshot of the pre-flake config
```

## Documentation (`modules/_assets/`)

| Doc | Purpose |
|---|---|
| `decisions.md` | ADR-style decision log — why the architecture and rules exist |
| `module-contracts.md` | Module registry map + cross-module interface contracts |
| `maintenance.md` | System upkeep vs the static `/etc/nixos` standard (updates, rollback, GC) |
| `ghostty-transparency.md` | GTK palette-only postmortem |
| `state-implementation.md` | `services.state.items` runtime-persistence framework |

## Architecture rules (summary)

1. **Aspect-oriented structure** — one file per feature, all scopes inside.
2. **Path agnosticism** — `import-tree` auto-imports; never relative-import
   between feature modules; underscore-prefixed paths are ignored.
3. **Strict scope separation** — `nixos.*` is system-wide; `homeManager.*` is
   user-level.
4. **Dependency self-containment** — every module declares every package it
   uses; duplicate declarations across modules are allowed (lists merge).

## Development & validation

```bash
# Parse sweep + registry eval + dry drvPath gates (no rebuild needed)
for f in $(find modules -name '*.nix'); do nix-instantiate --parse "$f" >/dev/null; done
nix eval .#modules --apply 'm: { nixos = builtins.attrNames m.nixos; homeManager = builtins.attrNames m.homeManager; }'
nix eval --raw .#nixosConfigurations.workstation.config.system.build.toplevel.drvPath

# Full dry build
nix build .#nixosConfigurations.workstation.config.system.build.toplevel
```

Notes: files must be `git add`ed before evaluation (the flake only sees
tracked files), and evals must be warning-free before switching.
