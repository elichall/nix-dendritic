# Module Contracts & Provenance

Cross-module interface contracts and the module registry map. This is the
single source of truth for how feature modules fit together; module files
point here instead of re-encoding these contracts in their headers. Decisions
and rationale live in `decisions.md`; tool-specific deep dives in
`otter-strategy.md`, `ghostty-transparency.md`, `state-implementation.md`, and
`maintenance.md`.

---

## 1. Module registry map

Registry is strictly 2-level (`class -> name -> module`); groups are aggregate
presets whose `imports` reference sibling entries. `self.modules.<class>.<name>`
is the access path. Verified with:

```bash
nix eval .#modules --apply 'm: { nixos = builtins.attrNames m.nixos; homeManager = builtins.attrNames m.homeManager; }'
```

### nixos (system scale)

| Key | File | Owns |
|---|---|---|
| `nixos.main` | `configuration.nix` | Base identity: stateVersion, bootloader+zram, time/locale, users, nix-ld, fonts, base systemPackages, flatpak, tmpfiles, **nix.settings/gc (intentionally kept, user choice)** |
| `nixos.hardwareConfig` | `system/hardware-t480.nix` | Machine-specific t480: fileSystems, boot modules, microcode |
| `nixos.network` | `system/network.nix` | hostName, networkmanager, openssh, tailscale, firewall/nftables |
| `nixos.hardware` | `system/hardware.nix` | bluetooth (powerOnBoot + profiles), fstrim, fwupd, microcode, earlyoom |
| `nixos.audio` | `system/audio.nix` | rtkit, pipewire (alsa + pulse + 32-bit) |
| `nixos.security` | `system/security.nix` | kernel sysctl hardening ONLY |
| `nixos.battery` | `system/battery.nix` | TLP power mgmt (+ ppd disable): charge thresholds 75/80 on BOTH BAT0+BAT1 (T480 dual-battery); `PLATFORM_PROFILE_*` kept for Framework 13 Pro (no-op on T480 — no `platform_profile` sysfs) |
| `nixos.mime` | `system/mime.nix` | custom-mime package + `xdg.mime.defaultApplications` |
| `nixos.display` | `display/display.nix` | WLR/OZONE session vars, XDG portal, ly display manager |
| `nixos.hyprland` | `display/hyprland.nix` | Compositor (programs.hyprland) ONLY; user tooling → `homeManager.hyprland` |
| `nixos.cmdLine` | `programs/cmdLine.nix` | programs.bash enable, direnv system-wide |
| `nixos.nvim` | `programs/nvim.nix` | neovim system package + EDITOR/VISUAL/SUDO_EDITOR |
| `nixos.rclone` | `programs/rclone.nix` | `programs.fuse.userAllowOther` only (binary → `homeManager.rclone`) |
| `nixos.base` | `groups/base.nix` | Preset: battery, network, hardware, audio, security |
| `nixos.desktop` | `groups/desktop.nix` | Preset: display, hyprland, mime |

### homeManager (user scale)

| Key | File | Owns |
|---|---|---|
| `homeManager.main` | `home.nix` | stateVersion, user, XCOMPOSECACHE, pointerCursor, xdg.enable, portal-gtk (MUST stay user-scale) |
| `homeManager.cmdLine` | `programs/cmdLine.nix` | bash/starship/zoxide/fzf/direnv/ble.sh config, aliases, dotfiles |
| `homeManager.git` | `programs/git.nix` | git config |
| `homeManager.tmux` | `programs/tmux.nix` | tmux config + plugins |
| `homeManager.initProject` | `programs/utils/initProject.nix` | `init-project` scaffold CLI (writeShellApplication, shellcheck at build): git init `-b main`, `uv init`, minimal flake devShell (nix/python/cpp toolchain, pure-eval `x86_64-linux` template), `use flake` envrc, .gitignore, agent dirs, `direnv allow` + initial commit; bails in existing git repo |
| `homeManager.nvim` | `programs/nvim.nix` | neovim config + 6 LSPs + tree-sitter + ltex-ls; SOLE owner of `xdg.configFile."nvim"` (recursive store symlink of `_assets/dotfiles/nvim`; build-time inflection expansion: `en.utf-8.add` (base, mixed-case) → `en.utf-8.expanded` (base + `'s` + plurals) → `en.utf-8.add.spl`; acronyms in CAPS / proper names in Title-Case; ltex reads `.expanded` fallback `.add`; docs: `dictionary-expansion.md` + `session-resume-spell-inflections.md`) |
| `homeManager.yazi` | `programs/yazi.nix` | yazi config/keymap, FILEMANAGER/TERM_FILE_CHOOSER vars, ripdrag, theme icon rules via 26.x `prepend_dirs`/`prepend_files` (exact names, no trailing slash) |
| `homeManager.opencode` | `programs/opencode.nix` | opencode binary + poppler-utils (PDF pipeline dep), SOLE owner of `xdg.configFile."opencode/tui.json"` + global `/pdf` command (`opencode/commands/pdf.md`) |
| `homeManager.fastfetch` | `programs/fastfetch.nix` | fastfetch binary + chafa block-image logo config (`symbols = "block"`), auto height, explicit `modules` list = default structure (2.63.1 prints NOTHING but the logo without it) (HOME-ONLY, user directive) |
| `homeManager.rclone` | `programs/rclone.nix` | rclone binary + rclone-box user unit |
| `homeManager.zotero` | `programs/zotero.nix` | zotero flatpak desktop entry |
| `homeManager.clipboard` | `system/clipboard.nix` | wl-clipboard (cross-host core; future `nixos.clipboard` may grow here) |
| `homeManager.ghostty` | `display/ghostty.nix` | ghostty binary + SOLE owner of `xdg.configFile."ghostty/config"` |
| `homeManager.hyprland` | `display/hyprland.nix` | hyprland user config (keybinds, autostart, rules) + deps (hypridle, grimblast, brightnessctl, playerctl, waybar, way-edges, tmux, yazi, ghostty); autostart block starts a headless ghostty server FIRST (`otterServer`: `--class=com.otter.launcher --initial-window=false --quit-after-last-window-closed=false --gtk-single-instance=true`) so the first `otter-open`/`otter-power` press hand-offs via `+new-window` (0.09s) instead of cold-starting ghostty (2-5s) |
| `homeManager.tui` | `display/tui.nix` | TUI launcher: wlctl (flake input), tuiApps list, desktop entries + icons, yazi-open |
| `homeManager.otterLauncher` | `display/otter-launcher/otter.nix` | otter-launcher (flake input) + wrappers + config.toml + otter-diagnose; `th` preview consumes theme profiles + swatches (C19); `tsm` = tmux session manager (tmux-fzf parity: switch/new/rename/detach/kill + `tsm <action> <session>` one-liner via shell-split of the `{}` argument) |
| `homeManager.showoff` | `display/showoff.nix` | showoff scripts/configs + dashboard deps + interaction-watch |
| `homeManager.awww` | `display/awww.nix` | awww binary (daemon launched via hyprland autostart, C10) |
| `homeManager.waypaper` | `display/waypaper.nix` | waypaper binary (restore via hyprland autostart, C10) |
| `homeManager.waybar` | `display/waybar.nix` | waybar config/style + user-scope deps; battery `full-at = 80` (TLP-capped batteries → full icon at 80%); workspaces-style rounded pill darken on hover for every module except the nixos logo (`background-color: rgba(0,0,0,0.65)` on `#<module>:hover` — modules are windowed `Gtk::EventBox`es that paint rounded backgrounds; pill stays opaque, boundary not washed out) |
| `homeManager.theme` | `display/theme.nix` | theme engine (profiles, sync, switch CLI) + wallpaper provisioning; owns `generated/previews/*.swatch` (C19) |
| `homeManager.toolbox` | `groups/toolbox.nix` | Preset: cmdLine, git, tmux, nvim, yazi |
| `homeManager.utils` | `groups/utils.nix` | Preset: initProject |
| `homeManager.desktop` | `groups/desktop.nix` | Preset: hyprland, ghostty, tui, otterLauncher, zotero, showoff, awww, waypaper, waybar, theme |

### Host wiring (`hosts/workstation.nix`)

- System: `main`, `hardwareConfig`, `base`, `desktop`, `cmdLine`, `nvim`, `rclone`.
- User (`home-manager.users.elichall.imports`): `main`, `toolbox`, `desktop`,
  `opencode`, `clipboard`, `rclone`, `fastfetch`, `utils`.
- `home-manager.useGlobalPkgs/useUserPackages = true`.

### Legacy provenance

| Module | Ported from |
|---|---|
| `configuration.nix` | legacy `/etc/nixos/configuration.nix` |
| `home.nix` | legacy `/etc/nixos/home.nix` inline content (feature bits split to aspect modules) |
| `system/mime.nix` | legacy `/etc/nixos/modules/mime.nix` |
| `system/battery.nix` | legacy `/etc/nixos/modules/tlp.nix` (key renamed `nixos.tlp` → `nixos.battery`) |
| `system/hardware-t480.nix` | `/etc/nixos/hardware-configuration.nix` |
| `display/theme.nix` | **LIVE** `/etc/nixos/modules/theme.nix` (NOT `legacy/` — legacy carries the pre-fix gtk.css transparency bug) |
| `display/showoff.nix` | legacy `/etc/nixos/modules/showoff.nix` |
| `display/waybar.nix` | legacy `/etc/nixos/modules/desktop-stable.nix` |
| `display/hyprland.nix` | legacy `/etc/nixos/modules/hyprland.nix` |
| `display/otter-launcher/` | legacy `/etc/nixos/modules/otter-launcher/` |
| `programs/*` | legacy `/etc/nixos/modules/programs/*` |

---

## 2. Contract inventory

### C1. Ghostty config ownership (ghostty ↔ theme)
- `homeManager.ghostty` is the SOLE owner of `xdg.configFile."ghostty/config"`.
- The theme module must NOT declare it (conflicting definition). It only
  rewrites the runtime `theme.conf` and signals ghostty to reload.
- Shared path source: `_lib/theme.nix` (`ghosttyThemeConf`); ghostty.nix and
  theme.nix must agree on all paths in `_lib/theme.nix`.
- Enforced: comment contracts; drvPath eval catches a conflict.

### C2. Theme path indirection & GTK palette-only
- No Nix config encodes a theme value. `~/.local/share/theme/active.json` is
  the single source of truth; `generated/ghostty/theme.conf` is the stable
  config-file target.
- `home.activation.initTheme` re-syncs after every HM switch (bootstrap +
  consistency re-link; headless-safe, reloads guarded).
- GTK CSS is **palette-only** — NEVER add an element rule. User-priority CSS
  loads in every GTK3/4 app; element rules leak (opaque `window` → ghostty
  transparency dead; `label` → waybar white workspaces; `.drag` → ripdrag
  pill). Postmortem: `ghostty-transparency.md`. Restyle apps in their own
  config, never in this CSS.
- Runtime symlink targets written by sync-ghostty: `hypr/palette.lua`,
  `waybar/colors.css`, `tmux/colors.tmux`, `nvim/lua/lean/core/palette.lua`,
  `cava/themes/nixos-generated`, `gtk-{3,4}.0/gtk.css` + `settings.ini`.

### C3. Wallpaper provisioning sync (theme.nix ↔ `_assets/aesthetics/wallpapers`)
- `theme.nix` provisions 17 wallpapers via `home.file` into
  `~/Pictures/Wallpapers`: 12 theme-profile + 5 waypaper library.
- The `wallpaperFiles` list and `modules/_assets/aesthetics/wallpapers/` must stay in
  sync; waypaper `--restore` and the waypaper app read the same directory.

### C4. yazi.desktop ↔ mime (tui ↔ mime)
- `homeManager.tui` defines the `yazi.desktop` target with
  `mimeType = [ "inode/directory" ]`.
- `nixos.mime` maps `"inode/directory" = "yazi.desktop"` — the desktop ID must
  stay in sync with that entry.

### C5. Otter dismiss & window-class contract
- Dismiss callback = `pkill -x otter-launcher` (exact comm: kills only the
  launcher; server survives). Bail = `--bail-comm otter-launcher` (exact
  `pgrep -x`, never self-matches, never matches ghostty server/client).
- `hyprctl dispatch closewindow` is NOT config-agnostic (Lua `hl.dispatch`
  hook rejects plain syntax) — do not reintroduce it.
- Window classes (keep in sync between hyprland rules and config.toml):

  | Class | Hyprland rule | config.toml consumers |
  |---|---|---|
  | `com.otter.launcher` | float, 550x250 centered | launcher itself |
  | `com.special.window` | magic workspace 1 | `ned`, `nrb` (root terminals) |
  | `com.waybar.tui` | float, 900x600 | `nsh`, `man` (popup terminals) |
  | default (`ghostty`) | normal | `pro`, `ssh` (tmux sessions) |

### C6. Rule 4 Hybrid for otter (module-owned CLIs)
- config.toml menu modules shell out via `sh -c`; every binary must be either
  declared in `homeManager.otterLauncher` `home.packages`/runtimeInputs, or
  listed in `otter-diagnose`.
- Module-owned CLIs (`theme`, `otter-apps`) cannot be re-declared as
  `home.packages` here → audited by `otter-diagnose` (18 checks, exit 1 on
  missing) + `home.activation.otterDiagnose` warning hook (never fails build).
- System-scope binaries (hyprctl, sudo, systemctl, loginctl, nixos-rebuild,
  xdg-settings) stay PATH-based.

### C7. `config.toml` token protocol
- `config.toml` is a template; injectable lines use `@TOKEN@` placeholders.
  `mkOtterConfig` substitutes them; each menu variant (app/pow) is an attrset
  override. Adding a token = edit both `config.toml` and `otter.nix`.
- Current tokens: `DEFAULT_MODULE`, `DEFAULT_MODULE_MESSAGE`, `OVERLAY_IMAGE`
  (→ repo asset `modules/_assets/aesthetics/nixos-image.png`), `THEME_DIR` (→
  `_lib/theme.nix` `dir`), `THEME_SWATCHES` (→ `_lib/theme.nix` `generated` +
  `/previews`).

### C19. Theme swatch ↔ otter `th` preview (theme ↔ otterLauncher)
- `homeManager.theme` **owns** both `profiles/*.json` (data) and
  `generated/previews/*.swatch` (derived artifacts). `swatchScript` runs from
  `initTheme` after sync on every activation (one loop over all profiles,
  headless ghostty palette resolve, guarded `|| continue` per profile).
- `homeManager.otterLauncher` **consumes** them read-only: the `th` preview
  reads `@THEME_DIR@/profiles/{1}.json` wallpaper via `jq -r .wallpaper`,
  renders `chafa -s "${FZF_PREVIEW_COLUMNS:-34}x$((FZF_PREVIEW_LINES-3))"`
  (kitty-protocol image sized to the pane), then cats
  `@THEME_SWATCHES@/{1}.swatch` (`--preview-window=right:50%,wrap`).
- Rule 4 deps: `jq` declared in `homeManager.otterLauncher` (consumed by the
  preview) — do not rely on the theme module's jq; `chafa` already a declared
  dep. `otter-diagnose` gained a `jq` check.
- Adding a new profile requires no otter change; swatches regenerate on the
  next activation.
- **otter `{}` pitfall (postmortem 2026-08-13)**: otter-launcher substitutes
  every bare `{}` in a module `cmd` with the module argument (empty for the
  `th` picker) before `sh -c` (`mod_exec.rs`). NEVER use bare `{}` in otter
  module cmds; use fzf's `{1}` (whole line) / `{+}` placeholders. A bare `{}`
  becomes an empty string, silently breaking `-f` checks and `-q`.
- **Kitty-graphics preview**: `chafa` without `-f symbols` emits kitty protocol
  images which fzf's text-based preview clearing cannot erase. Any image
  preview must (a) emit the kitty delete-all sequence first
  (`printf "\033_Ga=d,d=A\033\\"` — escapes doubled for TOML), (b) size chafa
  from `FZF_PREVIEW_COLUMNS/LINES` so it fits the launcher pane (550x250 →
  ~26–34 x 12–15 cells; a fixed size overflows and covers the swatch), and (c)
  emit `$LN` blank lines after chafa — fzf lays out preview text independently
  of the kitty image, so without the padding the swatch text lands at the top
  of the pane, under the image box (image = rows 0..LN-1, swatch at row LN+1).
- Swatches are a single blocks-only line (16 ANSI backgrounds, no label or
  column numbers).

### C8. PATH strategy for desktop configs
- User-scope binaries referenced by **absolute store path** (graphical session
  does not reliably carry the HM profile on PATH).
- System-scope binaries (nmcli, bluetoothctl, wpctl, hyprctl, systemctl, bash,
  flatpak) stay PATH-based (system profile always present).
- Module-owned wrappers (otter-open/otter-power/otter-apps, showoff) stay
  PATH-based until their focused passes land.
- Hyprland keybinds/autostart reference absolute paths for user-scope deps;
  every binary referenced is declared in `home.packages` (Rule 4).

### C9. UWSM tracks execution (systemd.enable = false)
- `homeManager.waybar` and `homeManager.hyprland` set `systemd.enable = false`
  — UWSM autostart tracks execution instead of the HM systemd daemon.
- Wallpaper restore runs inside hyprland's `hl.on("hyprland.start")` autostart
  block — do NOT reintroduce a `waypaper-restore`/`awww-daemon` systemd unit
  (graphical-session.target never activates under UWSM; see decision #23).

### C10. Wallpaper daemon + restore launch (hyprland autostart)
- `awww-daemon` and `waypaper --restore` are launched via
  `hl.exec_cmd` in the hyprland autostart block (absolute store paths,
  restore deferred 0.5s after the daemon — mirrors the old unit chain).
- Both binaries are declared in `home.packages` (Rule 4) in
  `homeManager.hyprland`; the daemon must start before the restore fires.

### C11. Shell-integration defaults
- `homeManager.cmdLine` explicitly disables fish/ion/nushell/zsh integration
  (`home.shell.* = false`) — HM 26.05 defaults them on and unused ones trip
  assertions (fzf nushell requires fzf ≥ 0.73.0).
- `enableBashIntegration = false` for starship (manual injection due to
  blesh) and fzf (readline binds inert under ble.sh).

### C12. portal-gtk scope
- `xdg-desktop-portal-gtk` MUST stay in `homeManager.main` user profile — the
  daemon finds it there; system placement breaks the portal (user-confirmed).

### C13. Assets path resolution
- Path literals resolve from the consuming file's OWN directory against the
  tracked git tree. `modules/home.nix` (depth 1) → `./_assets/aesthetics/icons`;
  `modules/display/tui.nix` (depth 2) → `../_assets/aesthetics/icons`.
- Everything in `modules/_assets/` must be tracked (root `.gitignore` rule is
  root-anchored `/_assets/`; do not un-anchor).

### C14. `_lib` access convention
- Shared non-module values via explicit relative import:
  `(import ../_lib/browser.nix).desktop`, `import ../_lib/theme.nix { ... }`,
  `import ../_lib/interaction-watch.nix { inherit pkgs; }`.
- `_lib` files define no `flake.modules.*`; never import a feature module from
  `_lib`; only genuinely shared (2+ consumer) values belong there.

### C15. interaction-watch interface
```
interaction-watch [--tag NAME] [--grace SECS] [--interval SECS]
                  [--bail-pattern REGEX] [--bail-comm COMM] --on-move CMD
```
- `--tag NAME` → cmdline becomes `interaction-watch --tag NAME`, reaped via
  `pkill -f "interaction-watch --tag NAME"`.
- `--grace` (0.5) delay before reference cursor capture; `--interval` (0.1)
  poll via `hyprctl cursorpos`.
- `--bail-pattern` (pgrep -f regex) / `--bail-comm` (pgrep -x comm): exit
  without firing when the surface is gone. `--bail-comm` can never match the
  watcher's own cmdline.
- `--on-move CMD` (required) runs via `sh -c` on first pointer move, then exits.
- Consumers: showoff (`--tag showoff --on-move "showoff --kill"`), otter
  (`--tag otter --bail-comm otter-launcher --on-move "pkill -x otter-launcher"`).

### C16. Registry groups are presets
- `nixos.base` = battery, network, hardware, audio, security.
- `nixos.desktop` = display, hyprland, mime.
- `homeManager.desktop` = hyprland, ghostty, tui, otterLauncher, zotero,
  showoff, awww, waypaper, waybar, theme.
- `homeManager.toolbox` = cmdLine, git, tmux, nvim, yazi.
- Individual keys remain importable alongside groups.

### C17. hardwareConfig wrap requirement
- Machine/NixOS-only config must be wrapped as `flake.modules.nixos.*` — a
  bare NixOS module under `modules/` recurses the flake-parts eval. Port
  regenerated hardware config into `system/hardware-t480.nix`, never as a
  raw file.

### C18. Showoff dependency surface (Rule 4)
- Dashboard deps: tty-clock, gping, cava, cmatrix, cbonsai,
  asciiquarium-transparent, sl, lolcat, cowsay (term-rotator/layout panes),
  weathr (waybar weather on-click), ghostty (TERMINAL, absolute path),
  fastfetch + btop (tmux panes), interaction-watch (pointer dismiss).

---

## 3. Wrapper / PATH status table

| Wrapper | Module | Currently | Lands |
|---|---|---|---|
| `otter-open` / `otter-power` / `otter-apps` | otterLauncher | PATH-based | — (module-owned, stays) |
| `showoff` (+ layout/term-rotator) | showoff | PATH-based via HM profile | — |
| `otter-launch` / `otter-launch-inner` | otterLauncher | absolute ghostty + PATH launcher | — |
| hyprland keybinds/autostart | hyprland | absolute user-scope paths | — |
| waybar on-clicks/exec | waybar | absolute user-scope, PATH system-scope | otter-open stays PATH-based |

---

## 4. Do-not-touch registers

- `homeManager.cmdLine` `bashrcExtra` hm-session-vars sourcing — user-reported
  issues; frozen (TODO stretch).
- `services.state.items` bluetooth — REACH, as-is (`state-implementation.md`).
- Ghostty window rules/classes (incl. dead `com.center.focus`) — kept as legacy
  (phase-3 decision, void).
- `dk`/`obs` config.toml stubs — left as-is.
- `_lib/` naming (no `modules/utils/` move) — kept (phase-3 decision).
