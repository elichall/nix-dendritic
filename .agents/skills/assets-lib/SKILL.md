# Skill: `_assets` Directory Usage

## Purpose
Defines the purpose and conventions for `modules/_assets/` — the tracked
static resource directory inside `modules/`. Underscore-prefixed entries are
IGNORED by `import-tree`, so nothing in `_assets/` is auto-imported into the
flake.

## `modules/_assets/` — Static Resources & Documentation
Tracked binary/text resources that feature modules need at eval/build time but
that are NOT Nix modules:
- `aesthetics/icons/` — app icons for desktop entries (btop, gdu, yazi, wlctl, jolt, bluetui, noctalia)
- `aesthetics/wallpapers/` — wallpapers provisioned by the theme module; keep
  `theme.nix` `wallpaperFiles` in sync
- `aesthetics/nixos-image.png` — otter-launcher overlay image (referenced via `@OVERLAY_IMAGE@`)
- `aesthetics/font_vault.md` — font vault reference
- `dotfiles/` — Nix-managed application dotfiles (e.g. `dotfiles/nvim/`)
- `documentation/` — Decision logs, contracts, and user guides:
  - `decisions.md` — ADR-style decision log (WHY)
  - `module-contracts.md` — module registry map + cross-module interface contracts
  - `ghostty-transparency.md` — GTK palette-only postmortem
  - `user/maintenance.md` — system upkeep (updates, rollback, GC)
  - `user/research.md` — research workflow guide
- `plans/` — Active work plans (top-level `.md` files)
  - `completed/` — finished plans (reference only)
  - `deferred/` — paused or deferred plans

### Docs convention
Extended prose (contracts, decisions, rationale) lives in `_assets/documentation/`
docs, NOT in module headers. Module headers carry only short pointers (e.g.
`# ... : modules/_assets/documentation/module-contracts.md (C8)`). When adding
an extended comment to a module, put the prose in the relevant `documentation/`
doc instead and leave a pointer. Contracts belong in `module-contracts.md`;
why-decisions in `decisions.md`.

### Rules
- Must be `git add`ed to be visible to the flake (nix only reads tracked files).
- The root `.gitignore` rule `/_assets/` is root-anchored; `modules/_assets/`
  IS tracked. Never un-anchor it.
- Referenced from modules via path literals resolved from the consuming file's
  OWN directory:
  - `modules/home.nix` (depth 1): `./_assets/icons`
  - `modules/display/tui.nix` (depth 2): `../_assets/icons`
- Do NOT reference the legacy `/etc/nixos/assets` (untracked, outside flake).

## Quick Reference
| Where | Purpose | Imported by import-tree? | Access method |
| :--- | :--- | :--- | :--- |
| `modules/_assets/` | Static resources + documentation (icons/wallpapers/images/docs/plans) | No | Path literal from consuming module (recompute depth) |
| `modules/<feature>.nix` | Aspect modules | Yes | Registry key via `self.modules.<domain>.<name>` |
| `modules/options/*Opt.nix` | Option declarations with defaults | Yes | Registry key, imported via `groups/options.nix` |
