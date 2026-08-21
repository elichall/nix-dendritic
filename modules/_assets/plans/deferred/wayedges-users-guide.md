# Way-Edges Users Guide

A users guide to the [way-edges](https://github.com/way-edges/way-edges) package
framework, written to validate the hub/side-panel plan in
`modules/_assets/plans/wayedges.md`. It documents the *framework* — what the
package can and cannot express — and explicitly does **not** implement any of
the plan's concrete widgets.

## 1. Version pinning

Everything below is verified against **way-edges 0.12.1**:

- Installed package (nixpkgs `way-edges`): `/nix/store/iyrhhmwgfidhws2yqwqkwg4rb3gih0r9-way-edges-0.12.1`
- Upstream tag commit: `ffcda9ee59b6fdff86ad693f4cffd0a623420fab`
- Authoritative per-build schema: run `way-edges -c <config-path> schema` on
  your own binary (see §14) — this package's schema is the source of truth;
  upstream `master` may have moved on.

## 2. What way-edges is

A Wayland (wlr-layer-shell) application that renders hidden widgets on screen
edges. Widgets pop out when the pointer touches their trigger zone, and can be
"pinned" to stay visible.

- Language/stack: Rust, `smithay-client-toolkit` + `gtk4-layer-shell` (wlr
  layer-shell protocol). It is a Wayland **client** — it needs a Wayland
  compositor (works with Hyprland and niri; see §13).
- Process model: a single process renders and runs everything. The `daemon`
  subcommand is deprecated; you just run `way-edges`.
- Inter-process control: a Unix socket at
  `$XDG_RUNTIME_DIR/way-edges{suffix}.sock` (suffix set by `-i/--ipc-namespace`).
  Clients send a JSON body `{"command": "...", "args": [...]}`.
- Commands: `togglepin` (toggle a widget's pin), `reload` (re-parse config and
  rebuild all widgets), `q` (quit).

## 3. Running it

```
way-edges [-d] [-c <path>] [-i <ns>] [schema|togglepin <ns>|reload|quit]
```

| Flag | Meaning |
|---|---|
| `-d`, `--mouse-debug` | print the mouse button key to the log on press/release — use to discover `event-map`/`pin-key` codes |
| `-c`, `--config-path <path>` | override the config file. **Must appear before the subcommand** (`-c` after `schema` is an unexpected argument) |
| `-i`, `--ipc-namespace <ns>` | suffix for the IPC socket name, so two independent way-edges instances can coexist (`way-edges.ns.sock`) |
| `schema` | print the JSON schema of the configuration to stdout (see §14) |
| `togglepin <ns>` | toggle the pin of every widget whose `namespace` equals `<ns>` (see §8) |
| `reload` | reload widget configuration (same as the file watcher's auto-reload, §10) |
| `quit` | close the running instance |

Notes:

- `schema` requires a config path to exist: with no `-c` it looks up the default
  paths and **panics** if none exists. `way-edges -c <path> schema` with an
  (even empty) file works.
- A `config` helper binary ships alongside `way-edges`; it prints nothing and is
  a no-op in 0.12.1.
- The binary logs to stderr (`RUST_LOG`, default `info,system_tray=error,zbus=warn`).

## 4. Configuration discovery

With no `-c`, way-edges searches `$XDG_CONFIG_HOME` for the **first existing**
file in this order:

1. `way-edges/config.kdl`
2. `way-edges/config.jsonc`
3. `way-edges/config.json`

The file extension selects the parser: `.kdl` → KDL, `.json`/`.jsonc` →
JSON/JSON-with-comments. An unknown extension tries KDL first, then JSON.

## 5. Config formats

Two formats describe the same structure:

- **KDL** — the author's recommended format (`config.kdl`). No schema support
  yet (the `$schema` key is JSON-only).
- **JSON / JSONC** — `config.json`/`config.jsonc`. Supports a `$schema` key
  pointing at the output of `way-edges -c <path> schema` for editor validation.

JSON field names are kebab-case and correspond to the KDL node/argument names.

The config root is `{ "widgets": [...] }` — a list of widget definitions.

## 6. The widget model

Every widget (`btn`, `slider`, `wrap-box`, `workspace`) shares a common set of
layout/interaction properties:

| Property | Meaning |
|---|---|
| `edge` (required) | which screen edge: `top`, `bottom`, `left`, `right` |
| `position` | secondary anchor to corner a widget (e.g. `edge "right" position "top"`) |
| `layer` | wlr layer: `background`, `bottom`, `top`, `overlay` |
| `monitor` | where to spawn: `0` (id), `"eDP-1"` (name), `"*"` (all), or a list. Default `0` |
| `margins` | `{left top right bottom}` margins in px |
| `offset` | absolute px or percentage along the edge |
| `thickness` / `length` | widget size across / along the edge; absolute or `"25%"` |
| `extra-trigger-size` | transparent hover zone beyond the visible widget |
| `preview-size` | how far the content extends out of the edge |
| `animation-curve` | `linear`, `ease-quad`, `ease-cubic` (default), `ease-expo` |
| `transition-duration` | pop animation duration in ms (default 300) |
| `namespace` | identifier used by `togglepin` (see §8). Required to pin remotely |
| `pinnable` | allow pinning (gate for all pin options) |
| `pin-on-startup` | start pinned (needs `pinnable`) |
| `pin-with-key` / `pin-key` | pin with a mouse button; `pin-key` default is 274 (middle). Discover codes with `--mouse-debug` |
| `ignore-exclusive` | ignore other layers' exclusive zones (stick to the edge) |
| `event-map` | mouse-button → shell command map (see §9) |

## 7. Widget types

### 7.1 `btn` — a clickable slab

```kdl
btn {
  namespace "demo:btn"
  edge "left"
  thickness 30
  length "25%"
  color "#ffeeddaa"
  border-width 2
  border-color "#112233aa"
  event-map {
    "mouse-left" "pkill nwg-drawer || nwg-drawer"
    "mouse-right" "hyprctl dispatch togglespecialworkspace bar"
    "mouse-middle" "kc-274"
  }
}
```

Fields: `color`, `border-color`, `border-width`, `thickness`, `length`,
`event-map`.

### 7.2 `slider` — a draggable value control

```kdl
slider {
  namespace "demo:volume"
  edge "right"
  thickness 25
  length "50%"
  fg-color "#f1fa8c"
  bg-color "#9f9f9f"
  preset "speaker" {
    device "alsa_output.pci-0000_00_1f.3.analog-stereo"
  }
}
```

Field set: `fg-color`, `fg-text-color`, `bg-color`, `bg-text-color`,
`border-color`, `border-width`, `radius`, `obtuse-angle`, `scroll-unit`,
`redraw-only-on-internal-update`, `thickness`, `length`, `preset`.

Presets:

| Preset | Purpose | Options |
|---|---|---|
| `speaker` | PulseAudio/pipewire output volume (drag to change, click to mute) | `mute-color`, `mute-text-color`, `animation-curve`, `device` |
| `microphone` | input volume | same as `speaker` |
| `backlight` | screen backlight | `device` |
| `custom` | arbitrary value driven by commands | see below |

Custom slider:

```kdl
slider {
  edge "right"
  thickness 25
  length "50%"
  redraw-only-on-internal-update
  preset "custom" {
    update-command "brightnessctl g"        // stdout parsed as f64 → progress
    update-interval 2000
    on-change-command "brightnessctl s {float:0,255}" // {float} = dragged value
    event-map {
      "mouse-middle" "brightnessctl set 50%"
    }
  }
}
```

Semantics (from source):

- `update-command` runs every `update-interval` ms; its stdout (trimmed) is
  parsed as a float and drives the progress fill. Empty command or
  `update-interval 0` disables the runner.
- `on-change-command` is a template string; `{float}` is substituted with the
  dragged value (e.g. `{float:0,255}` → 0–255 scale). Runs non-blocking on drag.
- `redraw-only-on-internal-update` suppresses drag-redraw (so the visual only
  follows the reported value).
- `scroll-unit` scales mouse-wheel steps.

### 7.3 `wrap-box` — the panel container

A wrap-box is the hub building block: a grid that holds **boxed items**
(§8), optionally wrapped in a styled frame.

```kdl
wrap-box {
  namespace "demo:hub"
  edge "right"
  thickness "100%"
  length "100%"
  outlook "window" {
    margins { left 10 right 10 top 10 bottom 10 }
    color "#282c34"
    border-radius 10
    border-width 3
  }
  gap 10
  align "center-center"
  item "text" {
    index 0 0
    preset "custom" {
      update-interval 5000
      cmd "uptime -p"
    }
  }
  item "ring" {
    index 1 0
    preset "cpu" { update-interval 2000 }
  }
}
```

Fields: `outlook`, `gap` (default 10), `align` (one of `top-left`,
`center-center`, ... 9 combos), `items`.

`outlook` is the panel **frame**, not a widget:

- `outlook "window"` — bordered box: `margins`, `color`, `border-radius`
  (default 5), `border-width` (default 15).
- `outlook "board"` — plain backdrop: `margins`, `color`, `border-radius`.

### 7.4 `workspace` — workspace switcher

Renders workspace pills and reacts to focus/active changes via a compositor
backend:

```kdl
workspace {
  namespace "demo:ws"
  edge "bottom"
  thickness 30
  length "100%"
  preset "hyprland"   // or "niri", or a niri config object
  default-color "#333"
  hover-color "#444"
  focus-color "#fff"
  active-color "#f1fa8c"
  active-increase 1
  gap 5
  border-radius 5
  border-width 1
  output-name "eDP-1"
  invert-direction
}
```

Preset `hyprland` or `niri` (niri accepts extra options). The Hyprland backend
talks to `hyprctl` / the Hyprland socket (`backend/src/workspace/hypr.rs`).

## 8. Boxed items (inside a wrap-box)

Exactly three item kinds exist in 0.12.1 (`BoxedWidget` enum — no terminal,
no image, no canvas):

| Item | Purpose |
|---|---|
| `ring` | circular percentage gauge (CPU/RAM/swap/battery/disk/custom) |
| `text` | label fed by a clock or a shell command |
| `tray` | system tray (StatusNotifier) |

Each item gets an `index [row col]` in the box grid.

### 8.1 `ring`

```kdl
item "ring" {
  index 0 1
  radius 13
  ring-width 5
  bg-color "#9f9f9f"
  fg-color "#f1fa8c"
  text-transition-ms 300
  prefix "{float:2,100}%"
  suffix " {preset}"
  preset "cpu" { update-interval 2000 }
}
```

Fields: `radius` (13), `ring-width` (5), `bg-color` (`#9f9f9f`), `fg-color`
(`#f1fa8c`), `text-transition-ms` (300), `animation-curve`, `prefix`/`suffix`
templates, `prefix-hide`/`suffix-hide`, `font-family`, `font-size`, `event-map`,
`preset`.

Presets (each auto-provides both a progress value and a human string):

| Preset | Options | Progress source | Preset text |
|---|---|---|---|
| `ram` | `update-interval` | used/total | `512.00MiB / 7.61GiB [6.57%]` |
| `swap` | `update-interval` | used/total | same style |
| `cpu` | `update-interval`, `core` (optional index) | per-core or total | `12.34%` |
| `battery` | `update-interval` | charge level | `78.00% Charging` |
| `disk` | `update-interval`, `partition` (default `/`) | used/total | `[Partition: /] ...` |
| `custom` | `update-interval`, `cmd` | stdout parsed as f64 → progress (0–1 expected; not clamped) | empty |

### 8.2 `text`

```kdl
item "text" {
  index 0 0
  fg-color "#abb2bf"
  font-size 14
  font-family "monospace"
  event-map {
    "mouse-left" "kitty -e tsm"
  }
  preset "custom" {
    update-interval 3000
    cmd "tmux list-sessions -F '#S'"
  }
}
```

Fields: `fg-color`, `font-size` (24), `font-family` (`monospace`), `event-map`,
`preset`.

Presets:

- `time`: `format` (strftime, default `%Y-%m-%d %H:%M:%S`), `time-zone`
  (IANA name, optional), `update-interval` (1000).
- `custom`: `cmd` (stdout becomes the text), `update-interval` (1000).

Rendering notes (verified in `util/src/text/draw.rs`):

- Text is drawn with `cosmic-text` at a **single color** (`fg-color`); there is
  no per-glyph color, no ANSI parsing. Escape sequences would appear literally.
- Multi-line is supported: the text buffer shapes runs, so embedded `\n` lines
  stack and the item auto-sizes.
- The whole item is one click target: `event-map` fires on any click anywhere on
  the item. There is **no per-line interaction**.

### 8.3 `tray`

StatusNotifier (SNI) system tray.

```kdl
item "tray" {
  index 1 0
  icon-size 18
  icon-theme "Papirus-Dark"
  tray-gap 5
}
```

Fields: `icon-size`, `icon-theme`, `tray-gap`, `grid-align`,
`header-menu-stack`/`header-menu-align`, `header-draw-config`,
`menu-draw-config`, `font-family`. Each tray icon pops its application menu on
click.

## 9. Templates

`prefix`/`suffix` (rings) and `on-change-command` (custom sliders) are template
strings. Syntax: `{name:arg1,arg2}`.

| Token | Meaning |
|---|---|
| `{float}` | the current progress value, 2 decimals (`0.51`) |
| `{float:0}` | zero decimals |
| `{float:2,100}` | value × 100, 2 decimals (`51.25`) |
| `{preset}` | the preset-provided human string (rings only) |

Escaping and failure (from `util/src/template/base.rs`):

- `\{` and `\}` render a literal brace; stray backslashes are stripped from
  literal text.
- An unknown token is **dropped** and logged as an error — no crash, but you get
  silently empty output for that token.
- Ring `prefix`/`suffix` register the `float` and `preset` tokens; slider
  `on-change-command` registers only `float`.

## 10. Reload & plug-and-play

- `way-edges reload` (or the `reload` IPC message) re-reads the config file,
  tears down every existing widget and rebuilds them (scheduled via an idle
  callback; rapid reloads are coalesced by a guard).
- The running process also watches the config file with **inotify** and
  auto-reloads ~700 ms after a change (`backend/src/config_file_watch.rs`).

Consequence for the plan: editing the config file (e.g. a Nix-managed
`config.kdl`) live-applies new/changed widgets without a rebuild of anything —
true plug-and-play panels.

## 11. Pin & visibility model

Widgets are hidden by default and animate out when the pointer enters their
trigger zone, then retract when it leaves.

- `pinnable true` enables the pin state; a pinned widget stays out.
- `pin-on-startup` starts pinned.
- `pin-with-key` + `pin-key` let a mouse button toggle pin locally; the default
  `pin-key` is 274 (mouse middle). Find your own codes with `--mouse-debug`.
- `togglepin <ns>` toggles the pin of **every widget whose `namespace` exactly
  equals `<ns>`** (this is how a keybind/waybar opens the panel — see §12).

Critical facts about `togglepin` (verified in `frontend/src/wayland/app.rs`):

- The argument is matched **literally** against the widget's `namespace` field.
  The `<group>:<widget>` colon in the CLI help and docs is a **naming
  convention**, not a parsed mechanism: name your widgets e.g.
  `namespace "hub:specs"`, then `way-edges togglepin hub:specs`.
- There is **no group logic and no exclusivity** — pinning one widget never
  un-pins another, and any number of widgets can be pinned at once. "Tabs"
  therefore require an external script that unpins the current tab and pins the
  next (see §12).
- `togglepin` affects all monitor duplicates of the same namespace at once.

## 12. Framework validation for the hub plan

| Plan idea | Framework mechanism | Verdict |
|---|---|---|
| Side panel opened by keybind and by a waybar module | `pinnable` wrap-box per tab + `way-edges togglepin hub:<tab>` from a Hyprland bind and a waybar `custom` module (`exec = way-edges togglepin ...`) | ✓ |
| System specs (CPU/RAM/GPU/temps/disks) | `ring` presets (`cpu`, `ram`, `disk`, custom) + `text` items fed by `cmd` (lscpu/gpuinfo/sensors) | ✓ |
| Toggles (services, features) | `btn` widgets and/or clickable `text`/`ring` items with `event-map` shell commands (`systemctl start/stop …`, `hyprctl dispatch …`) | ✓ |
| Volume knobs (draggable) | `slider` presets `speaker`/`microphone`/`backlight`; `custom` for arbitrary values via `update-command` + `on-change-command {float}` | ✓ |
| Programs / agents / containers / tmux sessions | multi-line `text` item fed by `cmd` (`docker ps`, `tmux list-sessions -F '#S'`, …) | ✓ with caveat |
| Tabs with per-panel content | multiple wrap-boxes sharing an edge/position, distinct namespaces, toggled via `togglepin`; auto-reload for new panels | ⚠ no tab container — pin exclusivity must be scripted |
| Cava audio visualization | — | ✗ no terminal/GPU item; see below |
| Dynamic ANSI art on the default panel | `text` item fed by a `cmd` generator | ⚠ single-color only; block glyphs (`█░`) fine if the font has them |

Caveats to design around:

- **List interactivity is coarse.** A `text` item has one `event-map` for the
  whole item. A tmux-sessions listing can't have per-line click targets; the
  click should instead open an interactive picker (e.g. a terminal running
  `tsm`/`fzf`) that lets you choose — the listing is informative, the action
  happens in the picker. Same for containers/programs.
- **Tabs are scripted pins, not a real tab widget.** The launcher/script should
  `togglepin hub:current` then `togglepin hub:next` (or set one
  `pin-on-startup` and toggle the others). Two simultaneously pinned tabs
  overlap in the same edge; stacking is compositor-determined and transparent
  pixels of the top surface don't reveal the one below.
- **No terminal embedding and no per-glyph color.** Boxed items are `ring`,
  `text`, `tray` only, and `text` is single-color `cosmic-text`. Cava must live
  in an external overlay (e.g. a floating `ghostty` window positioned by
  Hyprland) or be dropped; the ANSI "art" reduces to monochrome block art.
- Everything else the plan lists is natively supported and, thanks to §10,
  genuinely plug-and-play.

## 13. Hyprland notes

- wlr-layer-shell is supported by Hyprland; `way-edges` runs as a normal client.
- Monitor names come from `hyprctl monitors`; use them in `monitor`.
- Upstream examples bind `event-map` to `niri msg action …`. On this host use
  `hyprctl dispatch …` or plain shell instead (the plan's widgets will).
- `ignore-exclusive` matters on `bottom`/`top` edges where the waybar already
  claims exclusive space; the hub is `edge "right"` so it reserves the right
  edge unless `ignore-exclusive` is set.
- An `overlay` layer surface ignores exclusive zones entirely and floats above
  panels — the natural layer for a pinned hub.

## 14. Tooling

Regenerate the authoritative schema for the installed binary:

```bash
touch /tmp/we.config.kdl
way-edges -c /tmp/we.config.kdl schema > schema.json   # -c before the subcommand
```

Inspect it (jq):

```bash
jq '.["$defs"].WidgetConf' schema.json            # widget variants
jq '.["$defs"].RingPreset' schema.json            # ring presets
jq -r '.["$defs"].Slide.properties | keys[]' schema.json
```

Discover mouse key codes:

```bash
way-edges -c <config> --mouse-debug
```

## Sources

- Local package: `/nix/store/iyrhhmwgfidhws2yqwqkwg4rb3gih0r9-way-edges-0.12.1`
- Upstream repo at tag `ffcda9ee59b6fdff86ad693f4cffd0a623420fab`
  (`doc/cmd.md`, `doc/config/`, and crate source cited inline)
- Author's real-world config: `github.com/ogios/dots` → `way-edges/config.kdl`
- Companion plan: `modules/_assets/plans/wayedges.md`
