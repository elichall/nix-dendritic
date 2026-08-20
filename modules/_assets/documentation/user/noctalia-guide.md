# Noctalia Shell — User Guide

Noctalia Shell v5 is the desktop shell for our stable workstation stack. It
replaces the hand-rolled waybar + theme + awww + waypaper setup with a single
integrated shell: top bar, dock, launcher, control center, wallpaper manager,
clipboard history, notification daemon, and theme engine — all configured
declaratively via Home Manager.

**Current config**: `modules/display/desktop/noctalia.nix`
**Upstream docs**: https://docs.noctalia.dev/noctalia/

---

## 1. What Noctalia replaces

| Component | Before (experimental) | After (Noctalia) |
|---|---|---|
| Status bar | waybar (manual config) | Noctalia bar (declarative widgets) |
| Wallpaper | waypaper + awww daemon | Noctalia wallpaper manager |
| Theme engine | theme.nix (ghostty profile sync) | Noctalia theme engine (Catppuccin built-in) |
| Notifications | awww daemon | Noctalia notification daemon |
| Clipboard | wl-cliphist (manual) | Noctalia clipboard (built-in) |
| Launcher | rofi/wofi (external) | Noctalia launcher (built-in) |
| Settings panel | none | Noctalia settings panel |

The experimental stack (waybar, ghostty, theme, awww, waypaper) remains
available on the laptop host via `custom.terminal = "ghostty"` and the
`desktopExp` group.

---

## 2. Current configuration

Our current `noctalia.nix` configures:

```nix
programs.noctalia = {
  enable = true;
  settings = {
    theme = {
      mode = "dark";
      source = "builtin";
      builtin = "Catppuccin";    # Catppuccin Mocha theme
    };
    bar.default = {
      position = "top";
      start = [ "workspaces" ];
      end = [
        "battery"
        "volume"
        "clock"
      ];
    };
    dock.enabled = false;
    wallpaper = {
      directory = "/home/elichall/.nix/modules/_assets/aesthetics/wallpapers";
      enabled = true;
      fill_mode = "crop";
      fill_color = "#111111";
    };
    shell = {
      clipboard_enabled = true;
      clipboard_history_max_entries = 20;
      clipboard_auto_paste = "auto";
      setup_wizard_enabled = false;
    };
    accessibility = {
      ui_scale = 1.0;
      high_contrast = false;
    };
    idle.behavior = {
      lock.enabled = false;       # hypridle handles lock
      screen-off.enabled = false; # hypridle handles screen-off
    };
    notification.enable_daemon = true;
  };
};
```

---

## 3. Bar customization

The bar is configured under `settings.bar`. You can have named bars or use
`bar.default`.

### Available widgets

All widget IDs (use as strings in the `start`/`end`/`center` lists):

| Widget | Description |
|---|---|
| `workspaces` | Workspace indicators (tiled windows per workspace) |
| `battery` | Battery level + charging status (reads UPower D-Bus) |
| `volume` | Volume level + mute indicator |
| `clock` | Date/time display |
| `control-center` | Opens the control center panel |
| `network` | WiFi/Ethernet status |
| `bluetooth` | Bluetooth status |
| `media` | Now-playing media controls |
| `tray` | System tray icons |
| `brightness` | Screen brightness slider |
| `power-profile` | Power profile switcher (balanced/performance) |
| `notifications` | Notification history |
| `nightlight` | Night light toggle |
| `active_window` | Title of the focused window |
| `launcher` | App launcher button |
| `session` | Session menu (lock/logout/shutdown) |
| `screenshot` | Screenshot tool |
| `clipboard` | Clipboard history |
| `caffeine` | Caffeine mode (prevent idle) |
| `sysmon` | System monitor (CPU/RAM/disk) |
| `taskbar` | Running taskbar |
| `spacer` | Flexible spacer |
| `text` | Static text label |
| `custom_button` | Custom command button |
| `wallpaper` | Wallpaper selector button |
| `weather` | Weather display |
| `audio_visualizer` | Audio spectrum visualizer |
| `keyboard_layout` | Keyboard layout indicator |
| `lock_keys` | Caps/Num/Scroll lock indicators |
| `theme_mode` | Dark/light mode toggle |
| `privacy` | Privacy indicator (screen sharing) |
| `settings` | Settings panel button |

### Bar layout example

```nix
bar.default = {
  position = "top";     # "top" or "bottom"
  start = [
    "launcher"
    "workspaces"
  ];
  center = [
    "active_window"
  ];
  end = [
    "tray"
    "battery"
    "volume"
    "clock"
    "control-center"
  ];
};
```

### Bar appearance

```nix
bar.default = {
  # ... widgets ...
  density = "compact";          # "default" or "compact"
  show_outline = false;
  show_capsule = true;
  capsule_opacity = 0.93;
  widget_spacing = 6;
  content_padding = 2;
  font_scale = 1.0;
  margin_vertical = 4;
  margin_horizontal = 4;
  frame_thickness = 8;
  frame_radius = 12;
  background_opacity = 0.93;   # translucency
};
```

---

## 4. Theming

### Built-in themes

Noctalia ships with built-in themes. Set via:

```nix
settings.theme = {
  mode = "dark";          # "dark", "light", or "auto"
  source = "builtin";
  builtin = "Catppuccin"; # Built-in theme name
};
```

Other built-in themes include: Tokyo Night, Dracula, Nord, Gruvbox, Solarized,
and many more. Open **Settings → Theme** to browse.

### Custom color schemes

You can override Material 3 colors directly:

```nix
settings.colorSchemes = {
  predefinedScheme = "Monochrome";  # or omit to use custom
  darkMode = true;
  useWallpaperColors = false;       # auto-generate from wallpaper
  generationMethod = "tonal-spot";  # Material 3 color generation
};
```

### Wallpaper integration

Noctalia manages wallpapers declaratively:

```nix
settings.wallpaper = {
  enabled = true;
  default.path = "/path/to/wallpaper.png";
  fill_mode = "crop";          # "crop", "fit", "stretch", "center"
  fill_color = "#111111";
  transition_duration = 1500;  # ms
  transition_type = [ "fade" "disc" "wipe" ];
  set_wallpaper_on_all_monitors = true;
};
```

### App theming templates

Noctalia has a template engine that generates theme config files for
applications. Templates auto-apply on boot when the theme mode is Nightly
or Auto. They are stored in `~/.config/noctalia/templates/` and can be
managed declaratively via Home Manager.

#### How templates work

Noctalia injects **color tokens** from the active theme into template files.
Each template targets a specific app and writes a config file that the app
reads on startup.

Multi-app tokens (available in all templates):

| Token | Value |
|---|---|
| `${bgColor}` | Active background color |
| `${fgColor}` | Active foreground color |
| `${accentColor}` | Active accent color |
| `${warningColor}` | Warning color |
| `${errorColor}` | Error color |
| `${terminal.color0}`–`${terminal.color15}` | Full 16-color terminal palette |
| `${fontFamily}` | Active font family |
| `${fontFamilyMono}` | Active monospace font family |
| `${fontSize}` | Active font size |
| `${color}` | Alias for `${fgColor}` |
| `${greeting}` | Greeting text |

App-specific overrides use `apps.[appId].tokens.[tokenName]` to customize
tokens per application.

#### Built-in templates (pre-installed)

| Template | Config files generated | What it does |
|---|---|---|
| **GTK 3** | `~/.config/gtk-3.0/gtk.css`, `~/.config/gtk-3.0/colors.json` | Injects palette + imports `adw-gtk3` theme + syncs `color-scheme` |
| **GTK 4** | `~/.config/gtk-4.0/gtk.css`, `~/.config/gtk-4.0/colors.json` | Same for GTK4 apps |
| **Qt** | `~/.config/qt6ct/colors/noctalia.conf` | Generates Qt color scheme (requires `qt6ct` + `QT_QPA_PLATFORMTHEME=qt6ct`) |
| **KColorScheme** | `~/.local/share/color-scheme/noctalia.colors` | KDE-native color scheme for KDE apps |
| **Emacs** | `~/.cache/emacs/themes/noctalia-theme.el` | Generates Emacs color theme |
| **Umbriel** | `~/.icons/Umbrelix/colors.json` | Icon theme color overrides |

Enable built-in templates in config:

```nix
settings.templates = {
  enabled = true;
  enableUserTheming = true;   # enables template generation on boot
};
```

For GTK templates to work, also install `adw-gtk3` and `nwg-look`:

```nix
home.packages = with pkgs; [ adw-gtk3 nwg-look ];
```

And set the GTK theme:

```nix
gtk = {
  enable = true;
  theme.name = "adw-gtk3";
};
```

#### Community templates (installed as plugins)

From `github.com/noctalia-dev/community-templates`:

| Template | Target | What it generates |
|---|---|---|
| **neovim** | `~/.config/nvim/lua/noctalia/init.lua` | Reads `vim.g.terminal_color_*` from active terminal palette |
| **foot** | `~/.config/foot/foot.ini` | Generates `[colors-dark]` section with 16-color palette |
| **hyprland** | Hyprland color vars | Injects `$bg`, `$fg`, `$accent` as Hyprland env vars |
| **btop** | `~/.config/btop/catppuccin.conf` | Generates btop theme config |
| **cava** | Cava color config | Generates cava visualization colors |
| **starship** | Starship prompt config | Injects accent colors into starship prompt |
| **opencode** | OpenCode theme | Generates opencode color theme |
| **discord** | Discord color overrides | Injects palette into Discord |
| **firefox** | Firefox color overrides | Generates Firefox theme colors |
| **vscode** | VS Code workbench colors | Generates VS Code color theme |
| **steam** | Steam skin colors | Generates Steam UI colors |
| **zen** | Zen Browser colors | Generates Zen Browser theme |
| **obsidian** | Obsidian theme | Generates Obsidian CSS colors |
| **spotify** | Spotify color overrides | Generates Spotify theme |

#### Terminal sequences template (foot-specific)

The **Terminal sequences** community template pushes the active palette to
all running terminal emulator instances via escape sequences. This means
color changes are reflected instantly in open terminals without restart.

This template is **only relevant for foot** — other terminals (ghostty,
kitty, alacritty) don't support this protocol.

#### User templates (custom)

You can create your own templates by placing files in
`~/.config/noctalia/templates/`. Template syntax:

```nix
# Nix attrset → TOML template file
settings.templates.user = {
  "my-app.toml" = {
    source = ./my-app.toml.template;  # or inline content
    target = "~/.config/my-app/config.toml";
  };
};
```

Template file syntax supports:
- **Token substitution**: `${bgColor}`, `${terminal.color0}`
- **Regex transforms**: `${token:regex/find/replace}`
- **Case transforms**: `${token:lowercase}`, `${token:uppercase}`
- **Array syntax** (multi-line content):
  ```toml
  colors = [
    "${terminal.color0}",
    "${terminal.color1}",
  ]
  ```
- **Object syntax** (key-value):
  ```toml
  [colors]
  background = "${bgColor}"
  foreground = "${fgColor}"
  ```

#### Which apps need templates vs. which inherit terminal colors

**TUI apps read terminal colors automatically** — they inherit
`terminal.color0`–`terminal.color15` from the active terminal emulator
(foot). These do NOT need Noctalia plugins or templates:

| App | Color source | Template needed? |
|---|---|---|
| Neovim | Terminal palette via `:highlight` | **No** (uses Catppuccin already) |
| btop | Terminal palette | **No** |
| starship | Terminal palette | **No** |
| opencode | Terminal palette | **No** |
| tmux | Terminal palette | **No** |

**GUI apps need templates** — they read config files, not terminal colors:

| App | Color source | Template needed? |
|---|---|---|
| GTK3/GTK4 apps | `~/.config/gtk-{3,4}.0/` | **Yes** (built-in) |
| Qt apps | `qt6ct` config | **Yes** (built-in) |
| KDE apps | KColorScheme | **Yes** (built-in) |
| Emacs | Theme file | **Yes** (built-in) |
| Discord | CSS overrides | **Yes** (community) |
| Firefox | Color overrides | **Yes** (community) |
| VS Code | Workbench colors | **Yes** (community) |
| Steam | Skin colors | **Yes** (community) |

**Our current stack**: foot (built-in template handles theme), nvim
(Catppuccin via Nix, no template needed), btop/starship/opencode (inherit
terminal colors). The GTK/Qt built-in templates should be enabled if we
want GUI apps (file managers, settings panels, etc.) to match the shell
theme.

#### Enabling templates in our config

Add to `noctalia.nix`:

```nix
settings.theme.templates = {
  enable_builtin_templates = true;
  builtin_ids = [ "foot" ];  # opt-in per template
};
```

Available built-in template IDs (run `noctalia theme --list-templates`):

| Category | IDs |
|---|---|
| terminal | `foot`, `ghostty`, `kitty`, `alacritty`, `wezterm`, `starship` |
| compositor | `hyprland`, `sway`, `niri`, `mango`, `labwc`, `scroll`, `umbriel` |
| editor | `emacs`, `helix` |
| system | `gtk3`, `gtk4`, `qt`, `kcolorscheme` |
| audio | `cava` |
| misc | `btop` |

To add more templates later, append to `builtin_ids`:

```nix
builtin_ids = [ "foot" "hyprland" "btop" "gtk3" ];
```

Community templates (fetched from `api.noctalia.dev/templates`) use a
separate opt-in:

```nix
settings.theme.templates = {
  enable_community_templates = true;
  community_ids = [ "neovim" "opencode" "discord" ];
};
```

#### Foot integration pattern

Our `foot.nix` conditionally includes the Noctalia-generated theme file
when `programs.noctalia` is enabled. When Noctalia is not available (e.g.
laptop with ghostty), hardcoded Catppuccin colors serve as fallback:

```nix
{ ... }: {
  flake.modules.homeManager.foot = { config, ... }: {
    programs.foot = {
      enable = true;
      settings = {
        main = {
          # ... font, term, etc ...
        } // (if config.programs.noctalia.enable then {
          include = "~/.config/foot/themes/noctalia";
        } else { });
        # ... other sections ...
      } // (if config.programs.noctalia.enable then { } else {
        colors-dark = { /* fallback Catppuccin colors */ };
      });
    };
  };
}
```

When the `foot` template is enabled, Noctalia generates
`~/.config/foot/themes/noctalia` with the active palette (e.g. Catppuccin
dark). Foot's `include` directive loads this file, which provides the
`[colors-dark]` section. The hardcoded `colors-dark` block is omitted — no
conflict.

#### Hooks: injecting settings Noctalia doesn't export

Noctalia's foot template only generates color palette entries. Settings
like `alpha` (transparency) and `blur` are foot-specific and not part of
the template output. Since foot's `include` replaces the entire
`[colors-dark]` section, we can't put these in our foot config alongside
the include.

The solution: use a `colors_changed` hook to patch the theme file after
Noctalia regenerates it. This fires on startup AND on live theme changes
via the GUI.

Add to `noctalia.nix`:

```nix
settings.hooks.colors_changed =
  "T=\"$HOME/.config/foot/themes/noctalia\"; "
  + "[ -f \"$T\" ] && ! grep -q '^alpha=' \"$T\" && "
  + "sed -i '/^\\[colors-dark\\]/a alpha = 0.7\\nblur = true' \"$T\"";
```

The hook is idempotent — `grep -q '^alpha='` prevents double-injection.
Available hook events:

| Event | When it fires |
|---|---|
| `started` | Once after Noctalia finishes startup |
| `colors_changed` | After theme palette is resolved and templates updated |
| `theme_mode_changed` | After templates applied, when mode changes (dark/light) |
| `wallpaper_changed` | After wallpaper path change is applied |
| `session_locked` | When compositor confirms session lock |
| `session_unlocked` | When session leaves locked state |
| `battery_*` | Battery state changes (charging/discharging/plugged/percentage) |
| `power_profile_changed` | UPower power profile changes |

Hooks can be arrays for multiple commands:

```nix
settings.hooks.colors_changed = [
  "first-command"
  "second-command"
];
```

#### Hyprland integration pattern

The `hyprland` built-in template generates `~/.config/hypr/noctalia.lua`
with color variables (primary, surface, error, etc.) and an `apply_theme()`
function. To use it, add `hyprland` to `builtin_ids` and source the file
from our Lua config:

```nix
# In noctalia.nix:
builtin_ids = [ "foot" "hyprland" ];

# In hyprland.nix Lua config:
# dofile(os.getenv("HOME") .. "/.config/hypr/noctalia.lua")
```

The generated `noctalia.lua` exports a `colors` table and `apply_theme()`
function that configures Hyprland border colors, shadow, and groupbar
colors.

For GTK template support, also add:

```nix
home.packages = with pkgs; [ adw-gtk3 nwg-look ];

gtk = {
  enable = true;
  theme.name = "adw-gtk3";
};
```

---

## 5. Plugins

The plugin system is in **beta** but functional. Plugins provide bar widgets,
desktop widgets, panels, launcher providers, and background services.

### Official plugins

From `github.com/noctalia-dev/official-plugins`:

| Plugin | Type | Description |
|---|---|---|
| `screen_recorder` | service + widget | Screen recording via gpu-screen-recorder |
| `translator` | launcher provider | Google Translate from launcher (`/tr es hello`) |
| `timer` | desktop widget | Countdown timer with progress bar |
| `bongocat` | bar widget | Animated cat that taps to input/audio |
| `wallhaven` | panel + widget | Browse/download wallpapers from wallhaven.cc |
| `wallpaper_depth` | service | Depth-based widget layering (Depth Anything V2) |
| `mpvpaper` | service + panel | Video/animated wallpapers via mpv |
| `world_clock` | panel + widget | Track multiple timezones |

### Community plugins

From `github.com/noctalia-dev/community-plugins` — browse for additional
plugins contributed by the community.

### Enabling plugins declaratively

```nix
programs.noctalia = {
  # ... other config ...
  plugins = {
    sources = [
      {
        enabled = true;
        name = "Official Noctalia Plugins";
        url = "https://github.com/noctalia-dev/official-plugins";
      }
      {
        enabled = true;
        name = "Community Noctalia Plugins";
        url = "https://github.com/noctalia-dev/community-plugins";
      }
    ];
    states = {
      screen_recorder = {
        enabled = true;
        sourceUrl = "https://github.com/noctalia-dev/official-plugins";
      };
      # Add more plugins here
    };
    version = 2;
  };
  pluginSettings = {
    screen_recorder = {
      # Plugin-specific settings go here
    };
  };
};
```

### Recommended plugins for our stack

**screen_recorder** — useful for recording terminal sessions, presentations,
or documentation captures. Requires `gpu-screen-recorder` (available in
nixpkgs).

**wallhaven** — browse and apply wallpapers from wallhaven.cc directly from
the bar. Integrates with Noctalia's wallpaper manager.

**world_clock** — track multiple timezones in a panel. Useful for
collaboration across time zones.

### Enabling plugins from CLI

```bash
noctalia msg plugins list                              # list all plugins
noctalia msg plugins enable noctalia/screen_recorder   # enable a plugin
noctalia msg plugins disable noctalia/screen_recorder  # disable
noctalia msg plugins update official                   # update source
```

---

## 6. Keybindings (Hyprland IPC)

Noctalia is controlled via IPC commands in your Hyprland config. The syntax
in our Lua config:

```lua
local ipc = "noctalia msg "

-- Launcher
hl.bind("SUPER + Space", hl.dsp.exec_cmd(ipc .. "panel-toggle launcher"))

-- Control Center
hl.bind("SUPER + S", hl.dsp.exec_cmd(ipc .. "panel-toggle control-center"))

-- Settings
hl.bind("SUPER + comma", hl.dsp.exec_cmd(ipc .. "settings-toggle"))

-- Window switcher
hl.bind("ALT + Tab", hl.dsp.exec_cmd(ipc .. "window-switcher"))

-- Media keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(ipc .. "volume-up"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(ipc .. "volume-down"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(ipc .. "volume-mute"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(ipc .. "brightness-up"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(ipc .. "brightness-down"))
```

### Common IPC commands

| Command | Effect |
|---|---|
| `noctalia msg panel-toggle launcher` | Toggle app launcher |
| `noctalia msg panel-toggle control-center` | Toggle control center |
| `noctalia msg settings-toggle` | Toggle settings panel |
| `noctalia msg window-switcher` | Window switcher (Alt+Tab) |
| `noctalia msg volume-up` | Increase volume |
| `noctalia msg volume-down` | Decrease volume |
| `noctalia msg volume-mute` | Toggle mute |
| `noctalia msg brightness-up` | Increase brightness |
| `noctalia msg brightness-down` | Decrease brightness |
| `noctalia msg plugin <id> <target> <event>` | Send plugin IPC event |

### Plugin IPC examples

```bash
# Screen recorder
noctalia msg plugin noctalia/screen_recorder:service all toggle
noctalia msg plugin noctalia/screen_recorder:service all start focused

# Translator
# Type "/tr es hello world" in the launcher

# World clock
noctalia msg plugin noctalia/world_clock:service all add "America/Los_Angeles"
noctalia msg plugin noctalia/world_clock:service all list

# Bongo Cat
noctalia msg plugin noctalia/bongocat:cat focused toggle
```

---

## 7. Home Manager Nix syntax reference

Our Noctalia config uses the Home Manager module. Here's how to edit it:

### File location

```
modules/display/desktop/noctalia.nix
```

### Module structure

```nix
{ inputs, ... }: {
  flake.modules.homeManager.noctalia = { pkgs, ... }: {
    programs.noctalia = {
      enable = true;
      settings = { ... };      # TOML config as Nix attrset
      plugins = { ... };       # Plugin sources and states
      pluginSettings = { ... }; # Plugin-specific settings
    };
  };
}
```

### Nix attrset → TOML mapping

The `settings` attrset is serialized to TOML. Nesting maps to TOML sections:

```nix
settings = {
  theme.mode = "dark";           # → [theme] mode = "dark"
  bar.default.position = "top";  # → [bar.default] position = "top"
  dock.enabled = false;          # → [dock] enabled = false
};
```

is equivalent to:

```toml
[theme]
mode = "dark"

[bar.default]
position = "top"

[dock]
enabled = false
```

### Common patterns

**Adding a widget to the bar:**

```nix
bar.default.end = [
  "battery"
  "volume"
  "clock"
  "control-center"  # add new widget here
];
```

**Enabling a feature:**

```nix
dock.enabled = true;
```

**Changing a value:**

```nix
shell.clipboard_history_max_entries = 50;  # was 20
```

**Disabling a feature:**

```nix
idle.behavior.lock.enabled = false;
```

**Setting a path:**

```nix
wallpaper.directory = "/home/elichall/Pictures/Wallpapers";
```

**Setting a list:**

```nix
wallpaper.transition_type = [ "fade" "wipe" ];
```

**Setting a nested attrset:**

```nix
colorSchemes = {
  darkMode = true;
  predefinedScheme = "Catppuccin";
};
```

### Getting current settings

Since `~/.config/noctalia/settings.json` is a read-only symlink managed by
Nix, you can inspect the current live settings:

```bash
# Full settings dump
noctalia msg state all | jq .settings

# Copy settings from GUI
# Open Settings Panel → General → Copy Settings

# Diff between Nix config and live settings
nix shell nixpkgs#json-diff -c bash -c \
  "json-diff <(jq -S . ~/.config/noctalia/settings.json) \
             <(noctalia msg state all | jq -S .settings)"
```

### Validation

After editing, validate before rebuilding:

```bash
# Quick syntax check
nix-instantiate --parse modules/display/desktop/noctalia.nix

# Full eval (catches option conflicts)
nix eval .#modules --apply 'm: builtins.attrNames m.homeManager'
```

### Rebuild and apply

```bash
sudo nixos-rebuild switch --flake ~/.nix#workstation
```

After rebuild, restart Noctalia to pick up changes:

```bash
pkill noctalia-shell
# It will auto-restart from the hyprland autostart block
```

Or just log out and back in.

---

## 8. Required NixOS services

Noctalia's features depend on these NixOS services being enabled. Our
`system/battery.nix` and `system/network.nix` already enable most of these:

| Service | NixOS option | Purpose |
|---|---|---|
| NetworkManager | `networking.networkmanager.enable` | WiFi/Ethernet (bar network widget) |
| Bluetooth | `hardware.bluetooth.enable` | Bluetooth (bar bluetooth widget) |
| UPower | `services.upower.enable` | Battery status (bar battery widget) |
| Power profiles | `services.power-profiles-daemon.enable` or `services.tlp.enable` | Power profile switching |

**Note**: We use TLP instead of power-profiles-daemon. Noctalia's battery
widget reads UPower D-Bus, which works alongside TLP. If the battery widget
shows empty, verify UPower is running: `systemctl status upower`.

---

## 9. Troubleshooting

### Noctalia doesn't start

Check the autostart in hyprland:

```bash
# Verify noctalia binary is available
which noctalia-shell

# Check if it's running
pgrep -a noctalia

# Check hyprland logs for autostart errors
journalctl --user -u hyprland
```

### Battery widget is empty

UPower service must be running:

```bash
systemctl status upower
upower --dump  # should show battery info
```

### Bar doesn't appear

The bar needs the `workspaces` widget to function. Verify your config has
at least one widget in `start`, `center`, or `end`.

### Settings panel is blank

Noctalia settings panel requires the shell to be running. Make sure
`noctalia-shell` is in your process list.

### Plugin not showing up

1. Check the plugin is enabled: `noctalia msg plugins list`
2. Check the source is configured: `noctalia msg plugins source list`
3. Try enabling manually: `noctalia msg plugins enable <author/plugin>`

### Wallpaper not changing

Noctalia wallpaper manager reads from `settings.wallpaper.directory`. Make
sure the directory exists and contains image files.

---

## 10. Resources

| Resource | URL |
|---|---|
| Official docs | https://docs.noctalia.dev/noctalia/ |
| GitHub | https://github.com/noctalia-dev/noctalia |
| Discord | https://discord.noctalia.dev |
| Official plugins | https://github.com/noctalia-dev/official-plugins |
| Community plugins | https://github.com/noctalia-dev/community-plugins |
| Binary cache | https://app.cachix.org/cache/noctalia |
| NixOS wiki | https://wiki.nixos.org/wiki/Noctalia_Shell |
