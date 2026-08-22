# nix-dendritic

A **dendritic Nix configuration** — a single, universal, monolithic repository
capable of configuring any target machine, built on
[`flake-parts`](https://flake.parts/) and
[`import-tree`](https://github.com/denful/import-tree). 

Nix will be a long term home for my development stack, so I wanted to a have multiyear active development repository for all my platforms across school, work, and personal use. Because of the long term scope, documentation in the form of decision logs, user guides, plans, architectural contracts/rules, and agent files are of top priority.

Configuration is grouped by **feature aspect**, not by target system. A single
module file holds all scales of one feature — system-level (NixOS),
user-level (Home Manager), and (future) macOS (`nix-darwin`) — and hosts
simply aggregate the aspects they need.

> Status: the **workstation** (Lenovo T480) is fully migrated and deployed via
> this flake (2026-08-11). WSL / linux (non-NixOS) are in active development. macOS / server host stubs exist.

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
  `nixosConfiguration` or `homeManagerConfiguration` (if host isn't NixOS);
  aspect groups (`base`, `desktop`, `toolbox`) are presets that bundle
  related aspects.
- `modules/options/*Opt.nix` files declare cross-module option skeletons
  with auto-wiring defaults. Hosts override identity choices; feature
  modules never set config values they don't own.
- `flake.lock` is the only version pin — there are no channels. Inputs
  `home-manager`, `wlctl`, and `otter-launcher` follow the pinned nixpkgs
  (26.05) so the whole tree evaluates against one dependency closure.

## Repository layout

```
flake.nix / flake.lock   Entrypoint + version pin (no channels)
modules/                 The dendritic root (auto-imported by import-tree)
  _assets/               Static resources + docs (icons, wallpapers, decisions…)
  hosts/                 Host configurations (workstation + wsl/ubuntu/macos/server stubs)
  options/               Cross-module option declarations (*Opt.nix suffix)
  groups/                Aspect-group presets (base, desktop, toolbox, options, utils)
  system/ display/ programs/ utils/ research/   Feature aspects
legacy/                  (gitignored) frozen snapshot of the pre-flake config
```

## Documentation (`modules/_assets/`)

| Dir | Purpose |
|---|---|
| `documentation/` | Decision logs, module contracts, and rationale (the project knowledge base) |
| `documentation/user/` | User-facing guides (maintenance, research workflow) |
| `plans/` | Active work plans (top-level `.md` files) |
| `plans/completed/` | Finished plans (reference only) |
| `plans/deferred/` | Paused or deferred plans |
| `aesthetics/` | Icons, wallpapers, and visual assets |
| `dotfiles/` | Nix-managed application dotfiles (e.g. `dotfiles/nvim/`) |

## Architecture rules (summary)

1. **Aspect-oriented structure** — one file per feature, all scopes inside.
2. **Path agnosticism** — `import-tree` auto-imports; never relative-import
   between feature modules; underscore-prefixed paths are ignored.
3. **Strict scope separation** — `nixos.*` is system-wide; `homeManager.*` is
   user-level.
4. **Dependency self-containment** — every module declares every package it
   uses; duplicate declarations across modules are allowed (lists merge).
5. **Option auto-wiring** — cross-module values use options files
   (`options/*Opt.nix`) that declare with sensible defaults. Hosts set
   config overrides; feature modules create derivations but never set
   config values they don't own.

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

## AI usage

This project was developed with [opencode](https://opencode.ai) as the
agentic platform. The AI contributed across four areas: authoring
documentation (decision logs, module contracts, maintenance guides),
executing architectural refactors (dendritic flake migration, `_lib`
elimination, options pattern, `lib.getExe` bulk refactor), researching
NixOS module system semantics and flake-parts conventions, and translating
human intent into working Nix/HM syntax for waybar, theme
engines, and Noctalia integration.

The human drives architectural decisions and design philosophy; the AI
executes implementation, proposes alternatives, and catches
inconsistencies. The `AGENTS.md` file and `.agents/skills/<name>/SKILL.md` files encode project conventions so
AI agents follow the same patterns as the original collaboration.
