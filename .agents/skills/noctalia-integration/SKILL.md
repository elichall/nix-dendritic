# Skill: Noctalia Shell Integration

## Purpose
How Noctalia Shell integrates with the rest of the system. Noctalia is the
stable desktop shell (replaces hand-rolled waybar/hyprland config). It
provides theming, bar, dock, notifications, and wallpaper management.

## Core Module
`modules/display/desktop/noctalia.nix` — exports `homeManager.noctalia`.
Configures `programs.noctalia.enable = true` and all settings.

## Integration Points

### 1. Theme Hooks (`colors_changed`)
Noctalia fires `colors_changed` after theme palette resolution (startup +
live GUI theme changes). Our hook in `noctalia.nix` does:
1. Patches `alpha` and `blur` into `~/.config/foot/themes/noctalia`
   (idempotent via `grep -q '^alpha='` guard)
2. Runs `hyprctl reload` (compositor re-reads colors)
3. Runs `noctalia-theme-sync` script (generates palette files for tmux,
   neovim, opencode, waybar, hyprland, cava, gtk)
4. Sources `tmux source-file` for live tmux reload

### 2. Theme Templates (builtin)
Noctalia generates config files via built-in templates:
- `foot` → `~/.config/foot/themes/noctalia`
- `hyprland` → `~/.config/hypr/noctalia.lua` (color vars + `apply_theme()`)
- `btop`, `gtk3`, `gtk4`, `qt`, `starship`, etc.

Enabled via `builtin_ids` in noctalia settings. Foot and hyprland templates
are the primary integration points.

### 3. Conditional Branching (`config.programs.noctalia.enable`)
Multiple modules check `config.programs.noctalia.enable` to adapt behavior:
- **foot.nix**: conditionally `include`s `~/.config/foot/themes/noctalia`
  when enabled; hardcoded Catppuccin fallback when disabled
- **hyprland.nix**: conditionally `dofile`s `~/.config/hypr/noctalia.lua`
  with key mapping + `noctalia.apply_theme()`
- **tui.nix**: excludes noctalia-replaced TUI apps (wlctl, bluetui, jolt)
  when enabled; adds noctalia desktop entries (settings, control center)
- **notifySend.nix**: routes notifications to `notify-send` (Noctalia D-Bus)
  or `hyprctl notify` (compositor) based on the flag

### 4. Night/Noon Theme Derivations
The `noctalia-theme-sync` script in `noctalia.nix` creates derivations:
- Reads `~/.config/foot/themes/noctalia` for the active palette
- Writes `colors.tmux` (tmux status bar colors)
- Pushes palette to running foot instances via OSC escape sequences
- Reloads palette in running neovim instances via `--remote-expr`
- Signals opencode to reload theme via `SIGUSR2`

### 5. Autostart
Noctalia is launched via hyprland autostart (`exec-once`).
The `noctalia` binary path comes from `inputs.noctalia.packages.*.default`.

## Rules
- Only documented Noctalia settings are valid. Validate with
  `noctalia config validate` (zero warnings expected).
- Hooks go in `[hooks]` section. Available events: `started`,
  `colors_changed`, `theme_mode_changed`, `wallpaper_changed`,
  `session_locked/unlocked`, `battery_*`, `power_profile_changed`.
- `colors_changed` fires AFTER templates are regenerated — safe to patch
  generated files in the hook.
- The `programs.noctalia.enable` flag is the static branch point. Use
  `config.programs.noctalia.enable` in Nix expressions, NOT runtime
  `pgrep` detection.
- Template IDs are opt-in via `builtin_ids`. Community templates use
  `community_ids`.
