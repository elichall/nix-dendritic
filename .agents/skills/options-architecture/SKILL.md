# Skill: Options Architecture (Auto-Wiring Defaults)

## Purpose
How cross-module values flow in this repository. This is the central design
pattern for sharing values between unrelated modules.

## The Problem
Some values need to be shared across multiple modules that don't know about
each other (e.g. `terminal.name` is read by hyprland, otter, showoff, tui,
waybar). Without a shared mechanism, modules would either hardcode values
(duplicated, fragile) or import each other directly (coupled).

## The Solution: Options with Auto-Wiring Defaults
Cross-module values use the NixOS module system's own option mechanism:

1. **Options file** (`modules/options/*Opt.nix`): declares `options.<scope>.<name>`
   with `mkDefault` values that auto-resolve.
2. **Feature modules**: create derivations, add to `home.packages`. Do NOT
   set config values they don't own.
3. **Hosts**: set config overrides (identity choices). Most config resolves
   by defaults.

## File Convention: `*Opt.nix` Suffix
Options files use the `Opt.nix` suffix in their filename. This:
- Enables mini.pick file searching (jump to options versions of files
  that share names with feature modules)
- Distinguishes `options/terminalOpt.nix` (declarations) from
  `display/desktop/foot.nix` (feature module)

## Current Options Files
| File | Module Name | Options | Who Overrides |
|------|-------------|---------|---------------|
| `options/terminalOpt.nix` | `homeManager.terminal` | `terminal.{name,term,package,packages,exec,execClass}` | Hosts set `terminal.name` |
| `options/browserOpt.nix` | `homeManager.browser` | `browser.{appId,command,desktop}` | Hosts may override `browser.desktop` |
| `options/themeOpt.nix` | `homeManager.optionsTheme` | `theme.{dir,active,generated,ghosttyThemeConf}` | Path defaults, rarely overridden |
| `options/utilsOpt.nix` | `homeManager.optionsUtils` | `utils.{notifySend,interactionWatch}` | Set by utils modules (bridge pattern) |

## Key Design Points

### Derived values cascade from identity choices
```nix
# terminalOpt.nix — terminal.name is the identity choice
term.default = lib.getExe pkgs.${config.terminal.name};
package.default = pkgs.${config.terminal.name};
exec.default = cmd: "${config.terminal.term} -e ${cmd}";
```
When a host sets `config.terminal.name = "ghostty"`, ALL derived values
cascade automatically. No intermediate config-setting module needed.

### Lazy defaults
Default values reference other options lazily:
```nix
ghosttyThemeConf.default = "${config.theme.generated}/ghostty/theme.conf";
```
The path is computed even when ghostty isn't installed — it's just a string.
This is acceptable because the cost is zero (no derivation, no build).

### Utility options are a bridge
`utils.notifySend` and `utils.interactionWatch` exist because the
derivation depends on `config.programs.noctalia.enable` — an HM config
value. Flake outputs CAN'T reference HM config values (they're evaluated
at flake scope, not module scope). The option bridges this gap:
- Feature module creates the derivation + sets `config.utils.notifySend`
- Consumer reads `config.utils.notifySend`
- The `utilsOpt.nix` file explains WHY this bridge exists

### Import order
Options must be imported BEFORE consumers. The host import order is:
1. `self.modules.homeManager.options` (declares all options)
2. Feature modules (may read options)
3. Groups (import feature modules)

## Rules
- Feature modules NEVER set config values they don't own.
- Hosts set config overrides inside `users.<name> = { ... }` blocks.
- Options files declare with `mkDefault` so hosts can override.
- Option names in `*Opt.nix` files must use prefixed module names
  (`optionsUtils`, `optionsTheme`) to avoid collisions with feature
  modules that export the same scope (e.g. `homeManager.notifySend`).
