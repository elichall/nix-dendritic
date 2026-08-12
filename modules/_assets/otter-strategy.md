# Otter-Launcher — Results & Strategy Guide

Status: Phase 1 in progress (legacy refinement). Live evidence gathered 2026-08-11.
Scope: the otter-launcher (`kuokuo123/otter-launcher`, v0.7.6) module in the
legacy `/etc/nixos` tree and its pending dendritic port.

---

## 1. What otter-launcher is

A hackable CLI/TUI launcher built for keyboard-centric WM users. On this system
it is the primary app/menu launcher: bound to `$mainMod + F` (menu) and used as
the power menu (`otter-power`), with a companion `otter-apps` desktop-file
picker and a persistent headless ghostty server for near-instant spawning.

Architecture at a glance:

```
keybind (super+F) -> otter-open -> otter-launch
                                        |-- pgrep toggle? -> pkill (close)
                                        |-- ghostty +new-window --class=com.otter.launcher
                                        |        -e otter-launch-inner <config.toml>
                                        |           `-> exec otter-launcher -c <config>
                                        `-- dismiss-on-pointer (BROKEN, see §3)
persistent server: ghostty --class=com.otter.launcher --initial-window=false
                  --quit-after-last-window-closed=false --gtk-single-instance=true
```

Files (legacy `/etc/nixos/modules/otter-launcher/`):

| File | Lines | Role |
|---|---|---|
| `otter.nix` | 128 | `fetchTarball` build, `mkOtterConfig` token substitution, wrapper scripts, deps |
| `app-launcher.sh` | 105 | `otter-apps`: XDG desktop-file scan + cache + fzf picker + icon preview |
| `dismiss-on-pointer.sh` | 29 | Pointer-move dismiss for the launcher window |
| `config.toml` | 261 | Template consumed by `mkOtterConfig`; all menu modules live here |

Wiring outside the module:

| Consumer | Reference |
|---|---|
| `hyprland.nix` (legacy) | `menu = "otter-open"`, `systemManager = "otter-power"`, autostart `otter-apps --refresh-cache` + persistent ghostty server, `otter_launcher_rule` window rule |
| `desktop-stable.nix` (legacy) | waybar power on-click `otter-open` |
| `home.nix` (legacy) | `import ./modules/otter-launcher/otter.nix`; ghostty/qalc/chafa deps |

---

## 2. Live diagnostic findings (2026-08-11)

Deployed system is the **legacy `/etc/nixos` config** (Hyprland 0.55.4, Lua
config provider; not the dendritic flake). All otter binaries present in the
home-manager profile; the persistent ghostty server runs.

### Root cause of the broken dismiss (confirmed empirically)

`dismiss-on-pointer.sh` keys its entire logic off `pgrep -f "/bin/otter-launcher"`.
The real launcher process cmdline is **`otter-launcher`** (bash `exec` preserves
the bare argv[0]; observed PID 76841 `otter-launcher`). Therefore:

1. The wait loop (dismiss-on-pointer.sh:12-15) spins for `60 x 0.05s = 3s`.
2. The while-loop bail-check (line 22) then sees no match and **exits the
   watcher** — observed: watcher exited ~3s after launch while the launcher was
   still open. **Pointer-move dismissal never fires.**

Also observed:

- The open path works: the ghostty `+new-window -e` handoff to the persistent
  server spawns the launcher correctly.
- `hyprctl dispatch closewindow "class:com.otter.launcher"` is **broken on this
  system**: the Lua config intercepts `dispatch` (`hl.dispatch(...)` shorthand)
  and rejects the plain syntax — so hyprland-native dismissal is not
  config-agnostic here.
- The naive `pkill -f` fix would over-match: the ghostty server cmdline
  contains `--class=com.otter.launcher` and the client's cmdline contains the
  config path `*-otter-launcher.toml` — both would be killed.

### Verified working dismiss

`pkill -x otter-launcher` (exact comm match, 14-char name): kills only the
launcher, its window closes naturally, the persistent server survives. This is
the dismiss callback the shared interaction-watch helper uses at port (phase 2).

---

## 3. Legacy implementation critique

### 3.1 Dependency web (Rule 4 concern — the central problem)

Every binary the module reaches for at runtime:

| Consumer | Binaries | Declared? |
|---|---|---|
| `otter-launch` | `ghostty`, `pgrep`/`pkill`, `sleep` | ghostty **NOT declared** (bare at otter.nix:83/:86) |
| `otter-launch-inner` | `otter-launcher`, coreutils | OK |
| `dismiss-on-pointer` | `hyprctl`, `pgrep`/`pkill`, `sleep` | OK — but its *pattern* is broken (§2) |
| `app-launcher.sh` | `fzf`, `chafa`, `awk`, `grep`, `sort`, `tee`, `find`, `mkdir`, `setsid` | **writeShellScriptBin, zero runtimeInputs** — rides on system PATH |
| `config.toml` modules | `ghostty`, `nvim`, `fzf`, `qalc`, `wl-copy`, `tmux`, `tailscale`, `xdg-open`, `hyprctl`, `sudo`/`systemctl`/`loginctl`, `nixos-rebuild`, `theme`, `otter-apps` | nothing — bare shell strings via `exec_cmd = "sh -c"` |

Because the launcher shells out through `sh -c` in whatever environment ghostty
provides, a PATH that lacks the HM profile silently kills menu modules. The
module must declare the nixpkgs/flake deps (Rule 4 Hybrid, §5) and must be able
to *audit* itself for the module-owned CLIs (`theme`, `otter-apps`).

### 3.2 Hardcoded / stale paths

| Location | Value | Problem |
|---|---|---|
| config.toml `nrb` | `sudo nixos-rebuild switch` (**no `--flake`**) | On a flake-deployed machine this rebuilds the dormant legacy config — **would un-deploy the flake**. Highest-severity bug. |
| config.toml `ned` | `find /etc/nixos` | Wrong tree once the config of record is the repo. |
| config.toml `overlay_cmd` | `/etc/nixos/assets/nixos-image.png` | Legacy asset path; tracked copy lives at `modules/_assets/nixos-image.png`. |
| otter.nix header | `# use ootter-launcher's flake once I change to flake dendritic configuration` | Stale — that change is now the plan. |

### 3.3 Duplication / fragmentation

- The ghostty spawn-class idiom (`--class=com.waybar.tui` / `com.special.window`
  / `com.otter.launcher`) is hand-repeated in config.toml, otter wrappers, and
  mirrored by hyprland window rules.
- `dismiss-on-pointer.sh` and showoff's inline `showoff_watcher` are two
  implementations of the same cursor-watch idea — and the showoff one works.
  Phase 1 unifies them (§4).
- `nsp`/`gg` duplicate the browser-focus idiom, reimplementing domain knowledge
  owned by `_lib/browser.nix` (flatpak id `app.zen_browser.zen`).
- `appConfig`/`powConfig` repeat identical token pairs (`DEFAULT_MODULE` =
  `EMPTY_MODULE`, and both `*_MESSAGE` values match).

### 3.4 Dead / questionable code

- `app-launcher.sh` parses `--blocks` (line 71) but never uses it.
- `dk` (docker) and `obs` (obsidian) are empty WIP menu stubs — visible dead
  entries.
- `name !~ /^btop\+/` filter (app-launcher.sh:48) — btop+ fork artifact.
- `waypaper.desktop` skip (app-launcher.sh:57) — hardcoded filter; brittle.
- `otter-launch`'s `pgrep -f "/bin/otter-launcher"` toggle (otter.nix:75-78) is
  the same broken pattern as the dismiss — it "works" today only because the
  pattern correctly does not match when no launcher runs (self-match behavior of
  pgrep/pkill is build-dependent; do not rely on it).

### 3.5 What to preserve

- Toggle-close semantics (one keypress opens/closes).
- Persistent-ghostty fast path with cold fallback.
- `mkOtterConfig` token substitution — clean multi-config pattern (app/pow).
- Desktop-app cache with freshness check (`find -newer`).
- XDG icon resolution (hicolor sizes + Adwaita).
- Everything already isolated in one directory (good import-tree shape).

---

## 4. Shared interaction-detection: `interaction-watch`

Phase 1 introduces `modules/_lib/interaction-watch.nix` (tracked) — a
process-agnostic cursor watcher modelled on **showoff's working** watcher, not
otter's broken one.

Interface:

```
interaction-watch [--tag NAME] [--grace SECS] [--interval SECS]
                  [--bail-pattern REGEX] --on-move CMD
```

- `--tag NAME` → cmdline is `interaction-watch --tag NAME`, so consumers reap it
  with `pkill -f "interaction-watch --tag NAME"`.
- `--grace` (0.5) → delay before the reference cursor position is captured.
- `--interval` (0.1) → poll interval for `hyprctl cursorpos`.
- `--bail-pattern` → exit without firing when the regex no longer matches.
- `--on-move` (required) → run via `sh -c` on first pointer move.

Consumers:

| Consumer | Invocation |
|---|---|
| showoff (phase 1) | `interaction-watch --tag showoff --on-move "showoff --kill"` |
| otter (phase 2) | `interaction-watch --tag otter --bail-pattern "otter-launcher" --on-move "pkill -x otter-launcher"` |

Why `pkill -x otter-launcher` and not `hyprctl dispatch closewindow`: verified
live — exact comm match kills only the launcher; the server survives. The Lua
config breaks plain `dispatch closewindow` syntax, so a config-agnostic callback
is safer.

---

## 5. Rule 4 policy for otter (Hybrid — codified exception)

Otter is the most pervasive module for system interconnectedness. Per AGENTS.md
Rule 4 it must declare all of the packages it depends on in its own module.
Otter is granted a **narrow, documented exception** for the module-owned CLIs
(`theme`, `otter-apps`) that live in sibling modules and cannot be cleanly
re-declared as `home.packages`:

1. **External packages (full Rule 4 compliance):** `ghostty`, `fzf`, `chafa`,
   `libqalculate` (qalc), `wl-clipboard` (wl-copy), `nvim`, `tmux`, `tailscale`,
   `xdg-utils`, `procps`, `util-linux`, `gawk`, `grep` — declared in the otter
   module's own `home.packages` and/or `writeShellApplication` runtimeInputs.
2. **Module-owned CLIs (exception):** `theme`, `otter-apps` — covered by
   `otter-diagnose` (CLI audit, phase 1 legacy) and a home.activation warning at
   port (phase 2). The activation hook warns but does not fail the build.
3. No otter module may run a menu command that depends on a binary the module
   has not either declared or listed in `otter-diagnose`.

---

## 6. Window-class contract

| Class | Hyprland rule | config.toml consumers |
|---|---|---|
| `com.otter.launcher` | float, 550x250 centered (otter_launcher_rule) | the launcher itself (otter-launch) |
| `com.special.window` | magic workspace 1 (`special:window`) | `ned`, `nrb` (root terminals) |
| `com.waybar.tui` | float, 900x600 | `nsh`, `man` (popup terminals) |
| default (`ghostty`) | normal window | `pro`, `ssh` (tmux sessions) |

Keep this table in sync between the hyprland module and config.toml.

---

## 7. Three-phase roadmap

### Phase 1 — Refine legacy implementation (current)

Goals: make the legacy module safe, self-contained, and documented so the port
is mechanical. Delivered:

- [x] Live diagnostics + confirmed dismiss root cause (§2).
- [x] `modules/_lib/interaction-watch.nix` + showoff adoption (validated
      live — showoff still dismisses on pointer move).
- [x] This strategy guide.
- [ ] Legacy diff (scratch, applied by user): `nrb`/`ned` → flake/repo paths;
      `otter-launch` += ghostty; `app-launcher.sh` → writeShellApplication +
      declared runtimeInputs + drop `--blocks`; collapse duplicate config
      tokens; comment out `dk`/`obs`; add `otter-diagnose`; drop stale comment.
- [ ] Dismiss fix deliberately deferred to phase 2 (user decision).

Exit criteria: legacy module refined + audited; every port-time unknown resolved
(paths, deps, class contract, policy); strategy guide committed.

### Phase 2 — Port to dendritic

- Provision via flake input (`inputs.otter-launcher`, upstream v0.7.6 ships a
  flake exposing `packages.<system>.otter-launcher`) instead of
  `builtins.fetchTarball`.
- New module `modules/display/otter-launcher/otter.nix` with
  `flake.modules.nixos` + `flake.modules.homeManager` scopes; consumes
  `_lib/interaction-watch.nix` for dismiss.
- Replace the placeholder in `modules/display/otter-launcher/otter.nix`.
- `otter-diagnose` + home.activation warning (Rule 4 Hybrid, §5).
- Wire into `hyprland.nix` (`menu`/`systemManager`/autostart/server/window
  rule), `waybar.nix` (on-click), absorb qalc/chafa from `homeManager.main`.
- Resolve every path in the hardcoded-path inventory (§3.2) against the repo.

Exit criteria: `flake check` + host build pass; super+F opens, power works,
pointer-dismiss works; `otter-diagnose` reports all OK.

### Phase 3 — Refine the ported result

- Decide the `waypaper.desktop` / `btop\+` legacy filters.
- Collapse `nsp`/`gg` browser-focus idiom onto `_lib/browser.nix`.
- Revisit the `ssh` module (hashed known_hosts, tailscale dep) and `pro`/
  `ssh` ghostty class vs the contract table.
- Complete or cut the `dk`/`obs` stubs.
- Consider a shared ghostty spawn-class helper.

---

## 8. Port-time path resolutions

| Legacy | Ported |
|---|---|
| `nixos-rebuild switch` | `nixos-rebuild switch --flake "$HOME/Projects/nix-dendritic"` |
| `find /etc/nixos` | `find "$HOME/Projects/nix-dendritic"` |
| `/etc/nixos/assets/nixos-image.png` | flake-tracked `../_assets/nixos-image.png` |
| `fetchTarball` build | `inputs.otter-launcher.packages.${pkgs.system}.otter-launcher` |
