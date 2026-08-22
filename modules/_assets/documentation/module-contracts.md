# Module Contracts & Provenance

Cross-module interface contracts and the module registry map. This is the
single source of truth for how feature modules fit together; module files
point here instead of re-encoding these contracts in their headers. Decisions
and rationale live in `decisions.md`; system upkeep in `user/maintenance.md`.

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
| `nixos.battery` | `system/battery.nix` | TLP power mgmt (+ ppd disable): charge thresholds 75/80 on BOTH BAT0+BAT1 (T480 dual-battery); `PLATFORM_PROFILE_*` kept for Framework 13 Pro (no-op on T480 — no `platform_profile` sysfs); **UPower** (`services.upower.enable = true`) for battery status D-Bus (consumed by Noctalia battery widget) |
| `nixos.mime` / `homeManager.mimeDefaults` | `system/mime.nix` | custom-mime package (NixOS) + default app associations (HM) — dual-scope |
| `nixos.display` | `display/display.nix` | WLR/OZONE session vars, XDG portal, ly display manager; `options.custom.terminal` (default `"foot"` — host-level terminal choice) |
| `nixos.hyprland` | `display/hyprland.nix` | Compositor (programs.hyprland) ONLY; user tooling → `homeManager.hyprland` |
| `nixos.cmdLine` | `programs/cmdLine.nix` | programs.bash enable, direnv system-wide |
| `nixos.nvim` | `programs/nvim.nix` | neovim system package + EDITOR/VISUAL/SUDO_EDITOR |
| `nixos.rclone` | `programs/rclone.nix` | `programs.fuse.userAllowOther` only (binary → `homeManager.rclone`) |
| `nixos.sandbox` | `programs/sandbox.nix` | libvirtd (QEMU/KVM VM management, swtpm); KVM via `hardware-t480.nix` kernelModules |
| `nixos.base` | `groups/base.nix` | Preset: battery, network, hardware, audio, security |
| `nixos.desktop` | `groups/desktop.nix` | Preset: display, hyprland, mime (NixOS side — custom-mime package only, defaultApplications moved to HM `mimeDefaults`) |
| `nixos.desktopExp` | `groups/desktopExp.nix` | Preset: display, hyprland, mime (NixOS side — same as desktop) |
| `nixos.options` | `groups/options.nix` | Preset: cross-module option declarations NixOS-side (currently optionsHost only) |
| `nixos.optionsHost` | `options/hostOpt.nix` | Host scaffold `host.*`: isNixos, isWsl, displayProtocol, shell, identity — dual-scope declarations with shared let-in defaults (see C28) |

### homeManager (user scale)

| Key | File | Owns |
|---|---|---|
| `homeManager.main` | `home.nix` | stateVersion, user, XCOMPOSECACHE, pointerCursor, xdg.enable, portal-gtk (MUST stay user-scale) |
| `homeManager.cmdLine` | `programs/cmdLine.nix` | bash/starship/zoxide/fzf/direnv/ble.sh config, aliases, dotfiles; WSL-only `nvim` drain-buffer alias when `host.isWsl` (win32yank autopaste workaround) |
| `homeManager.git` | `programs/git.nix` | git config; commit identity from `config.host.identity.gitUsername/gitEmail` (C28) — requires `options` group imported first |
| `homeManager.tmux` | `programs/tmux.nix` | tmux config + plugins |
| `homeManager.initProject` | `utils/initProject.nix` | `init-project` scaffold CLI (writeShellApplication, shellcheck at build): git init `-b main`, `uv init`, minimal flake devShell (nix/python/cpp toolchain, pure-eval `x86_64-linux` template), `use flake` envrc, .gitignore, agent dirs, `direnv allow` + initial commit; bails in existing git repo |
| `homeManager.interactionWatch` | `utils/interactionWatch.nix` | `interaction-watch` pointer-dismiss watcher (writeShellApplication, shellcheck at build); flake.utils export for cross-module `runtimeInputs` access (showoff, otter) |
| `homeManager.notifySend` | `utils/notifySend.nix` | `hybrid-notify` notification wrapper (writeShellApplication, shellcheck at build): routes to Noctalia (`notify-send` via D-Bus) or Hyprland (`hyprctl notify`, compositor-internal) based on active daemon; flake.utils export for cross-module access |
| `homeManager.nvim` | `programs/nvim.nix` | neovim config + 6 LSPs + tree-sitter + ltex-ls; SOLE owner of `xdg.configFile."nvim"` (recursive store symlink of `_assets/dotfiles/nvim`; build-time inflection expansion: `en.utf-8.add` (base, mixed-case) → `en.utf-8.expanded` (base + `'s` + plurals) → `en.utf-8.add.spl`; acronyms in CAPS / proper names in Title-Case; ltex reads `.expanded` fallback `.add`; docs: `dictionary-expansion.md` + `session-resume-spell-inflections.md`) |
| `homeManager.yazi` | `programs/yazi.nix` | yazi config/keymap, FILEMANAGER/TERM_FILE_CHOOSER vars, ripdrag, theme icon rules via 26.x `prepend_dirs`/`prepend_files` (exact names, no trailing slash) |
| `homeManager.opencode` | `programs/opencode.nix` | opencode binary + poppler-utils (PDF pipeline dep), SOLE owner of `xdg.configFile."opencode/tui.json"` + global `/pdf` command (`opencode/commands/pdf.md`) |
| `homeManager.fastfetch` | `programs/fastfetch.nix` | fastfetch binary + chafa block-image logo config (`symbols = "block"`), auto height, explicit `modules` list = default structure (2.63.1 prints NOTHING but the logo without it) (HOME-ONLY, user directive) |
| `homeManager.rclone` | `programs/rclone.nix` | rclone binary + rclone-box user unit |
| `homeManager.zotero` | `research/zotero.nix` | zotero flatpak desktop entry |
| `homeManager.clipboard` | `system/clipboard.nix` | Platform-aware clipboard tooling branching on `host.*` (C28): `displayProtocol` selects wl-clipboard/xclip; `isWsl` adds vendored win32yank (fetchzip of upstream release, dual-name `win32yank{,.exe}`) + `wslview` shim (wslu removed from nixpkgs — project archived) + xclip (WSLg exposes x11 too). Requires `options` group imported first |
| `homeManager.ghostty` | `display/experimental/ghostty.nix` | ghostty binary + SOLE owner of `xdg.configFile."ghostty/config"` (experimental stack only) |
| `homeManager.foot` | `display/desktop/foot.nix` | foot terminal via `programs.foot.enable` (HM native module); stable stack terminal |
| `homeManager.noctalia` | `display/desktop/noctalia.nix` | Noctalia Shell via `programs.noctalia.enable`; stable stack shell/bar (themes, top bar, wallpaper, clipboard, notifications) |
| `homeManager.hyprland` | `display/hyprland.nix` | hyprland user config (keybinds, autostart, rules) + deps (hypridle, grimblast, brightnessctl, playerctl, tmux, yazi); autostart block starts noctalia shell; uses `config.terminal.*` abstraction (host selects foot or ghostty via `custom.terminal`) |
| `homeManager.tui` | `display/tui.nix` | TUI launcher: wlctl (flake input), tuiApps list, desktop entries + icons, yazi-open; uses `config.terminal.*` abstraction |
| `homeManager.otterLauncher` | `display/otter-launcher/otter.nix` | otter-launcher (flake input) + wrappers + config.toml + otter-diagnose; uses `config.terminal.*` abstraction for launcher exec (foot: `--app-id`, ghostty: `--class`); interaction-watch + hybrid-notify via `config.utils.*`; `th` preview consumes theme profiles + swatches (C19); `tsm` = tmux session manager (tmux-fzf parity: switch/new/rename/detach/kill + `tsm <action> <session>` one-liner via shell-split of the `{}` argument) |
| `homeManager.showoff` | `display/experimental/showoff.nix` | showoff scripts/configs + dashboard deps + interaction-watch (via `config.utils.interactionWatch`); uses `config.terminal.*` abstraction (foot: `--app-id`, ghostty: `--class`) |
| `homeManager.awww` | `display/awww.nix` | awww binary (daemon launched via hyprland autostart, C10) |
| `homeManager.waypaper` | `display/waypaper.nix` | waypaper binary (restore via hyprland autostart, C10) |
| `homeManager.waybar` | `display/waybar.nix` | waybar config/style + user-scope deps; uses `config.terminal.*` abstraction; battery `full-at = 80` (TLP-capped batteries → full icon at 80%); workspaces-style rounded pill darken on hover for every module except the nixos logo (`background-color: rgba(0,0,0,0.65)` on `#<module>:hover` — modules are windowed `Gtk::EventBox`es that paint rounded backgrounds; pill stays opaque, boundary not washed out) |
| `homeManager.theme` | `display/experimental/theme.nix` | theme engine (profiles, sync, switch CLI) + wallpaper provisioning; owns `generated/previews/*.swatch` (C19); experimental stack only |
| `homeManager.toolbox` | `groups/toolbox.nix` | Preset: cmdLine, git, tmux, nvim, yazi, opencode (core dev tools — no GUI, no extensions) |
| `homeManager.utils` | `groups/utils.nix` | Preset: initProject, interactionWatch, notifySend (options moved to dedicated `options` group) |
| `homeManager.options` | `groups/options.nix` | Preset: cross-module option declarations (browser, optionsTheme, optionsUtils, optionsHost) — terminal follows merged pattern (declares + sets in one file) |
| `homeManager.optionsHost` | `options/hostOpt.nix` | Host scaffold `host.*` HM-side copy: isNixos, isWsl, displayProtocol, shell, identity — same tree as nixos scope, shared literal defaults via file-level let (C28) |
| `homeManager.browser` | `programs/browser.nix` | Sets `config.browser.{appId,command,desktop}` (Firefox flatpak) |
| `homeManager.mimeDefaults` | `programs/mimeDefaults.nix` | User-level MIME associations (`xdg.mimeApps.defaultApplications`) |
| `homeManager.themePaths` | `display/theme-paths.nix` | Sets `config.theme.{dir,active,generated,ghosttyThemeConf}` |
| `homeManager.desktop` | `groups/desktop.nix` | Preset (stable): hyprland, foot, tui, noctalia, otterLauncher, showoff, browser, mimeDefaults, themePaths |
| `homeManager.desktopExp` | `groups/desktopExp.nix` | Preset (experimental): hyprland, ghostty, tui, otterLauncher, showoff, awww, waypaper, waybar, theme, browser, mimeDefaults, themePaths |
| `homeManager.researchGroup` | `groups/research.nix` | Preset: research (pandoc/texlive), obsidian (nvim vault integration), zotero (flatpak desktop entry) |
| `homeManager.research` | `research/default.nix` | pandoc (HM module, citeproc + xelatex defaults) + texlive (slim: latexmk/biber/bibtex + pandoc template deps only); user-scale |
| `homeManager.obsidian` | `research/obsidian.nix` | obsidian.nvim + blink-cmp-bibtex + obsidian_ls LSP; generates lean/research feature Lua files → activation-merged into nvim config (adaptive framework, see C21) |

### Host wiring

#### `hosts/workstation.nix` (stable — foot + Noctalia)
- System: `main`, `hardwareConfig`, `base`, `desktop`, `cmdLine`, `nvim`, `rclone`, `sandbox`, `options`.
- User (`home-manager.users.elichall.imports`): `main`, `options`, `toolbox`, `desktop`,
  `researchGroup`, `utils`, `clipboard`, `rclone`, `fastfetch`.
- Terminal: relies on `terminal.name` default `"foot"` (no host override needed).
- Noctalia shared via `home-manager.sharedModules`; `useGlobalPkgs/useUserPackages = true`.

#### `hosts/laptop.nix` (experimental — ghostty + hand-rolled stack)
- System: `main`, `hardwareConfig`, `base`, `desktopExp`, `cmdLine`, `nvim`, `rclone`, `sandbox`.
- User (`home-manager.users.elichall.imports`): `main`, `options`, `toolbox`, `desktopExp`,
  `researchGroup`, `utils`, `clipboard`, `rclone`, `fastfetch`.
- Terminal: `config.terminal.name = "ghostty"` set inside the HM user block
  (cascades to all derived `config.terminal.*` values).
- Noctalia shared via `home-manager.sharedModules`; `useGlobalPkgs/useUserPackages = true`.

#### `hosts/server.nix` (stub — headless)
- Empty placeholder.

#### `hosts/linux.nix` (standalone HM — foreign-distro, headless template)
- `homeConfigurations.linux` via `homeManagerConfiguration` (toolbox style).
- Imports: `options`, `toolbox`, `utils`, `clipboard` + inline base block
  (identity from `config.host.identity.username`, stateVersion 26.05,
  `host.isNixos = false`, `targets.genericLinux.enable`, fontconfig +
  JetBrainsMono/Noto in `home.packages`, `programs.home-manager`).
- No theming, no display stack (by design — full-feature parity first).
- Deploy: `nix build .#homeConfigurations.linux.activationPackage && ./result/activate`.

#### `hosts/wsl.nix` (standalone HM — toolbox style, WSL template)
- `homeConfigurations.wsl`; same shape as linux plus
  `host.isWsl = true` → clipboard ships win32yank/wslview/xclip; cmdLine adds
  the nvim drain-buffer alias. `isNixos = false`.
- A NixOS-in-WSL flavor (`nixosConfigurations` + nixos-wsl input) remains a
  future addition; `isWsl × isNixos` distinguish flavors.
- Deploy: build + activate inside the WSL distro; interop changes need
  `wsl --shutdown` from Windows.

#### `hosts/{ubuntu,macos}.nix`
- ubuntu stub REMOVED (renamed → `linux.nix`, plan D7). macos remains an empty
  placeholder (no hardware; deferred).

### Legacy provenance

| Module | Ported from |
|---|---|
| `configuration.nix` | legacy `/etc/nixos/configuration.nix` |
| `home.nix` | legacy `/etc/nixos/home.nix` inline content (feature bits split to aspect modules) |
| `system/mime.nix` | legacy `/etc/nixos/modules/mime.nix` |
| `system/battery.nix` | legacy `/etc/nixos/modules/tlp.nix` (key renamed `nixos.tlp` → `nixos.battery`) |
| `system/hardware-t480.nix` | `/etc/nixos/hardware-configuration.nix` |
| `display/experimental/theme.nix` | **LIVE** `/etc/nixos/modules/theme.nix` (NOT `legacy/` — legacy carries the pre-fix gtk.css transparency bug); moved to experimental/ when Noctalia replaced theme engine on stable stack |
| `display/experimental/showoff.nix` | legacy `/etc/nixos/modules/showoff.nix`; moved to experimental/ with terminal abstraction |
| `display/experimental/waybar.nix` | legacy `/etc/nixos/modules/desktop-stable.nix`; moved to experimental/ when Noctalia replaced waybar on stable stack |
| `display/experimental/ghostty.nix` | new (replaces the old `display/ghostty.nix` at root); stable stack uses foot instead |
| `display/desktop/foot.nix` | new (Noctalia-era stable terminal) |
| `display/desktop/noctalia.nix` | new (Noctalia-era stable shell/bar — replaces waybar, theme, awww) |
| `display/hyprland.nix` | legacy `/etc/nixos/modules/hyprland.nix`; now uses terminal abstraction |
| `display/otter-launcher/` | legacy `/etc/nixos/modules/otter-launcher/`; now uses terminal abstraction |
| `programs/*` | legacy `/etc/nixos/modules/programs/*` |

---

## 2. Contract inventory

### C1. Ghostty config ownership (ghostty ↔ theme) — experimental stack only
- `homeManager.ghostty` is the SOLE owner of `xdg.configFile."ghostty/config"`.
- The theme module must NOT declare it (conflicting definition). It only
  rewrites the runtime `theme.conf` and signals ghostty to reload.
- Shared path source: `config.theme.ghosttyThemeConf` (set by
  `homeManager.themePaths`); ghostty.nix and theme.nix must agree on these
  paths.
- Enforced: comment contracts; drvPath eval catches a conflict.
- **Stable stack (workstation)**: ghostty is replaced by foot (`programs.foot.enable`);
  theme engine replaced by Noctalia. This contract applies only to the experimental
  stack (laptop, `custom.terminal = "ghostty"`).

### C2. Theme path indirection & GTK palette-only
- No Nix config encodes a theme value. `~/.local/share/theme/active.json` is
  the single source of truth; `generated/ghostty/theme.conf` is the stable
  config-file target. Paths are declared as options in `config.theme.*` (set by
  `homeManager.themePaths`).
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
- Theme directory path: `config.theme.dir` (set by `homeManager.themePaths`).

### C4. yazi.desktop ↔ mime (tui ↔ mimeDefaults)
- `homeManager.tui` defines the `yazi.desktop` target with
  `mimeType = [ "inode/directory" ]`.
- `homeManager.mimeDefaults` maps `"inode/directory" = [ "yazi.desktop" ]` —
  the desktop ID must stay in sync with that entry.

### C5. Otter dismiss & window-class contract
- Dismiss callback = `pkill -x otter-launcher` (exact comm: kills only the
  launcher; server survives). Bail = `--bail-comm otter-launcher` (exact
  `pgrep -x`, never self-matches, never matches the terminal server/client).
- `hyprctl dispatch closewindow` is NOT config-agnostic (Lua `hl.dispatch`
  hook rejects plain syntax) — do not reintroduce it.
- Window class flag is terminal-dependent: foot uses `--app-id`, ghostty uses
  `--class`. The terminal abstraction (`execClass`) handles the branching.
  Otter, showoff, and all other consumers use `terminal.execClass` instead of
  hardcoded `--class`. (Currently via `_lib/terminal.nix`; will migrate to
  `config.terminal.execClass` in Phase 4.)
- Theme paths consumed via `config.theme.{dir,generated}` (set by
  `homeManager.themePaths`); browser command via `config.browser.command` (set
  by `homeManager.browser`).
- Window classes (keep in sync between hyprland rules and config.toml):

  | Class | Hyprland rule | config.toml consumers |
  |---|---|---|
  | `com.otter.launcher` | float, 550x350 centered | launcher itself |
  | `com.special.window` | magic workspace 1 | `ned`, `nrb` (root terminals) |
  | `showoff.dash` / `showoff.sec` | magic workspace 1 | showoff dashboard/secondary |
  | default (foot/ghostty) | normal | `pro`, `ssh` (tmux sessions) |

### C6. Rule 4 Hybrid for otter (module-owned CLIs)
- config.toml menu modules shell out via `sh -c`; every binary must be either
  declared in `homeManager.otterLauncher` `home.packages`/runtimeInputs, or
  listed in `otter-diagnose`.
- Module-owned CLIs (`theme`, `otter-apps`) cannot be re-declared as
  `home.packages` here → audited by `otter-diagnose` (18 checks, exit 1 on
  missing) + `home.activation.otterDiagnose` warning hook (never fails build).
- Cross-module dependencies: `config.utils.interactionWatch` (pointer dismiss),
  `config.utils.notifySend` (notification wrapper), `config.terminal.*`
  (terminal abstraction), `config.theme.*` (theme paths), `config.browser.*`
  (browser command).
- System-scope binaries (hyprctl, sudo, systemctl, loginctl, nixos-rebuild,
  xdg-settings) stay PATH-based.

### C7. `config.toml` token protocol
- `config.toml` is a template; injectable lines use `@TOKEN@` placeholders.
  `mkOtterConfig` substitutes them; each menu variant (app/pow) is an attrset
  override. Adding a token = edit both `config.toml` and `otter.nix`.
- Current tokens: `DEFAULT_MODULE`, `DEFAULT_MODULE_MESSAGE`, `OVERLAY_IMAGE`
  (→ repo asset `modules/_assets/aesthetics/nixos-image.png`), `THEME_DIR` (→
  `config.theme.dir`), `THEME_SWATCHES` (→ `config.theme.generated` +
  `/previews`), `TERMINAL` (→ `config.terminal.term`), `CLASS_FLAG` (→
  terminal-dependent `--app-id=` or `--class=`), `NOTIFY_CMD` (→
  `config.utils.notifySend`).

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
- Theme paths: `config.theme.dir` and `config.theme.generated` (set by
  `homeManager.themePaths`).
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

### C10. Wallpaper daemon + restore launch (hyprland autostart) — experimental stack only
- `awww-daemon` and `waypaper --restore` are launched via
  `hl.exec_cmd` in the hyprland autostart block (absolute store paths,
  restore deferred 0.5s after the daemon — mirrors the old unit chain).
- Both binaries are declared in `home.packages` (Rule 4) in
  `homeManager.hyprland`; the daemon must start before the restore fires.
- **Stable stack (workstation)**: wallpaper management handled by Noctalia
  shell (`programs.noctalia.enable`); no awww or waypaper needed.

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

### C14. `_lib/` eliminated — options module pattern (Option A)
- **`_lib/` has been eliminated.** All cross-module shared values use the Option A
  pattern (decision #53): options files declare `options.*` with `mkDefault`
  values that auto-resolve. Hosts set config overrides. Feature modules create
  derivations and add to `home.packages` but NEVER set config values.
- **Suffixed files:** `options/<name>Opt.nix` — suffix enables mini.pick file
  searching when options share names with feature modules.
- **Terminal abstraction** (`config.terminal.*`): `options/terminalOpt.nix`
  declares all 6 options with `mkDefault` values derived from `terminal.name`.
  Hosts set `terminal.name = "ghostty"`; all derived values cascade.
- **Theme abstraction** (`config.theme.*`): `options/themeOpt.nix` declares
  palette + variant options. Night/noon derivations computed lazily via
  `theme.variant.default = if config.theme.isLight then "noon" else "night"`.
- **Browser abstraction** (`config.browser.*`): `options/browserOpt.nix`
  declares `browser.name` (default `"firefox"`) + lazy computed `browser.command`.
- **Utility options** (`config.utils.*`): combined in `options/utilsOpt.nix`
  (explains why options are needed: bridge between flake-level derivations and
  HM config). Set by `utils/{notifySend,interactionWatch}.nix`.

### C15. interaction-watch interface
- Definition: `modules/utils/interactionWatch.nix` (flake-parts module)
- Cross-module access: `self.utils.interactionWatch pkgs` (returns derivation)
- Group membership: `homeManager.utils` (adds to `home.packages`)
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
- `nixos.desktop` = display, hyprland, mime (NixOS side, shared).
- `nixos.desktopExp` = display, hyprland, mime (same as desktop — NixOS side shared).
- `homeManager.options` = cross-module option declarations (`options/*Opt.nix`):
  browser, terminal, theme, notifySend, interactionWatch.
- `homeManager.desktop` = hyprland, foot, tui, noctalia, otterLauncher, showoff, mimeDefaults (stable).
- `homeManager.desktopExp` = hyprland, ghostty, tui, otterLauncher, showoff,
  awww, waypaper, waybar, theme, mimeDefaults (experimental).
- `homeManager.toolbox` = cmdLine, git, tmux, nvim, yazi, opencode.
- `homeManager.utils` = initProject, interactionWatch, notifySend.
- `homeManager.researchGroup` = research, obsidian, zotero.
- Individual keys remain importable alongside groups.

### C17. hardwareConfig wrap requirement
- Machine/NixOS-only config must be wrapped as `flake.modules.nixos.*` — a
  bare NixOS module under `modules/` recurses the flake-parts eval. Port
  regenerated hardware config into `system/hardware-t480.nix`, never as a
  raw file.

### C18. Showoff dependency surface (Rule 4)
- Dashboard deps: tty-clock, gping, cava, cmatrix, cbonsai,
  asciiquarium-transparent, sl, lolcat, cowsay (term-rotator/layout panes),
  weathr (waybar weather on-click), terminal (via `_lib/terminal.nix` abstraction;
  will migrate to `config.terminal.*` in Phase 4), fastfetch + btop (tmux panes),
  interaction-watch (pointer dismiss).

### C20. Research vault path
- Vault: `~/Documents/me/vault`
- `obsidian.nvim` workspace points at the vault root (full vault, not just `research/`).
- `blink-cmp-bibtex` discovers `.bib` files via `global_files` function — walks
  up from buffer directory to vault root (`.obsidian/`), collecting `*.bib` at
  each level. Per-buffer scoping: each buffer only sees `.bib` files in its
  directory chain up to the vault root.
- Canonical bib naming: `references.bib` (not `.references.bib`).
- Better BibTeX auto-export: manual Zotero setup (install plugin, configure
  auto-export to `references.bib` files in Better BibTeX format).
- Templates: `vault/.templates/` (7 archetypes), inserted via `<leader>nt`.

### C21. Adaptive nvim plugin framework
- Base nvim config (`homeManager.nvim`) deploys via `xdg.configFile."nvim"`
  = `{ source = derivation; recursive = true; }` — a store symlink.
- Feature modules cannot add files alongside a store symlink via
  `xdg.configFile` (HM can't write inside store paths).
- Solution: feature modules use `home.activation` hooks to resolve the
  symlink, copy the directory, and layer feature files on top.
- Base `init.lua` loads features via `pcall(require, "lean.<feature>")`.
  Each feature returns `{ plugins, lsp }`. Missing features degrade silently.
- Base `lsp.lua` merges feature LSP servers via pcall after the base loop.
- Feature plugin specs for shared plugins (e.g. blink.cmp) use lazy.nvim's
  deep-merge: multiple specs for the same plugin merge their `opts`.
  Sources are listed via `per_filetype` (the `default = function(list)`
  pattern conflicts with obsidian.nvim's config iterator).
- Pattern: `modules/<aspect>/` generates `lua/lean/<feature>/init.lua`
  via `pkgs.runCommand` → merged by activation hook. LSP servers are
  returned in the same `init.lua` (no separate `lsp.lua` needed).
- Currently active features: `research` (obsidian.nvim, blink-cmp-bibtex,
  obsidian_ls).

### C22. Terminal abstraction (`config.terminal.*`)
- Terminal abstraction provides a terminal-agnostic interface consumed by
  hyprland, waybar, showoff, otter, and tui modules.
- **Declarations:** `modules/options/terminalOpt.nix` declares all 6 options
  with `mkDefault` values derived from `terminal.name`. No config-setting
  feature module — values cascade from host identity choice.
- **Exports:** `config.terminal.{name,term,package,packages,exec,execClass}`.
- Hosts select their terminal via `terminal.name = "foot" | "ghostty"` in
  `hosts/<hostname>.nix`; all derived values cascade automatically.
- Consumer modules MUST use `config.terminal.term`/`config.terminal.exec`/
  `config.terminal.execClass` — never hardcode `foot` or `ghostty` strings.

### C23. Noctalia Shell config contract
- `homeManager.noctalia` uses `programs.noctalia.enable = true` (HM native
  module). Config keys are documented in
  `~config/noctalia/README.md` — ONLY documented keys are valid.
- Validated with `noctalia config validate` (zero warnings expected).
- Settings: `[theme]` (mode, source, builtin), `[bar.default]` (position,
  start/end widgets), `[dock]` (enabled), `[wallpaper]` (enabled, fill_mode),
  `[shell]` (clipboard_enabled, clipboard_history_max_entries, setup_wizard_enabled),
  `[accessibility]` (ui_scale), `[idle.behavior.*]` (enabled), `[notification]`
  (enable_daemon), `[battery]` (warning_threshold), `[theme.templates]`
  (enable_builtin_templates, builtin_ids, enable_community_templates,
  community_ids).
- Hooks: `[hooks]` section fires shell commands on Noctalia events.
  `colors_changed` fires after theme palette resolution and template updates
  (startup + live GUI theme changes). Our hook patches `alpha` and `blur`
  into `~/.config/foot/themes/noctalia` after Noctalia regenerates it
  (idempotent via `grep -q '^alpha='` guard). Available events: `started`,
  `colors_changed`, `theme_mode_changed`, `wallpaper_changed`,
  `session_locked/unlocked`, `battery_*`, `power_profile_changed`.
- Templates: built-in template IDs (`foot`, `hyprland`, `btop`, `gtk3`,
  `gtk4`, `qt`, `kcolorscheme`, `emacs`, `helix`, `cava`, `starship`, etc.)
  are opt-in via `builtin_ids`. Foot integration: `foot.nix` conditionally
  `include`s `~/.config/foot/themes/noctalia` when `programs.noctalia.enable`
  is true; hardcoded Catppuccin colors serve as fallback when Noctalia is
  absent. Hyprland integration: `hyprland` template generates
  `~/.config/hypr/noctalia.lua` with color vars + `apply_theme()`.
- Autostart: noctalia launches via `hl.on("hyprland.start", ...)` using full
  store path (`inputs.noctalia.packages.x86_64-linux.default`).
- Battery widget requires UPower D-Bus service (see C27).
- Palette sync: `noctalia-theme-sync` script (see C24) fans out colors to
  tmux, foot, nvim, and opencode on every `colors_changed` hook event. Theme
  paths consumed via `config.theme.*` (set by `homeManager.themePaths`).
- User guide: `modules/_assets/documentation/user/noctalia-guide.md` — full
  reference for bar customization, plugins, theming, keybindings, and Home
  Manager Nix syntax.

### C24. Noctalia-theme-sync: central palette sync hub
- `noctalia-theme-sync` (defined in `noctalia.nix` as `writeShellApplication`)
  is the single script that fans out palette changes to all dev tools.
- Triggered by noctalia's `colors_changed` hook (startup + live GUI theme changes).
- Parses `~/.config/foot/themes/noctalia` once, then syncs:
  - **tmux**: writes `~/.config/tmux/colors.tmux` (no conditional, always writes)
  - **foot**: pushes OSC 4/10/11 escape sequences to all running foot instances
  - **nvim**: clears palette cache + re-applies colorscheme via `--remote-expr`
  - **opencode**: sends SIGUSR2 to force palette re-detection (NOT SIGWINCH)
- Dependencies: `gnused`, `gnugrep`, `procps`, `neovim` (runtimeInputs)
- Theme paths: `config.theme.generated` (set by `homeManager.themePaths`).
- The hook string in `noctalia.nix` also patches alpha/blur into the foot theme
  and calls `hyprctl reload` + `tmux source-file` after the sync script.

### C25. Tmux integration (Approach A contract)
- `homeManager.tmux` has **zero noctalia awareness** — no `config` arg, no
  `noctaliaColorsScript`, no conditional logic.
- Tmux unconditionally sources `~/.config/tmux/colors.tmux` via `if-shell`
  (file may not exist on first boot — graceful fallback to defaults).
- `noctalia-theme-sync` writes `colors.tmux` on every `colors_changed` event.
- Same file, different sources possible: noctalia (production) or experimental
  theme.nix (if both are active).
- This is the canonical "Approach A" contract: Noctalia writes the file,
  tmux consumes it agnostically. Theme paths: `config.theme.generated` (set by
  `homeManager.themePaths`).

### C26. Opencode palette refresh via SIGUSR2
- Opencode's "system" theme reads terminal palette (ANSI colors 0-15) via OSC
  queries and generates its UI theme from them.
- Opencode does NOT auto-detect palette changes — SIGWINCH only triggers resize,
  NOT palette re-detection.
- `noctalia-theme-sync` sends `pkill -SIGUSR2 opencode` after pushing OSC
  sequences to foot. SIGUSR2 explicitly clears the palette cache and re-applies
  the theme.
- Verified: SIGUSR2 handler in opencode source calls `clearPaletteCache()` +
  theme re-apply. SIGWINCH handler only calls `handleResize()`.
- Theme paths: `config.theme.*` (set by `homeManager.themePaths`).

### C27. UPower battery status contract
- `services.upower.enable = true` in `system/battery.nix` provides battery
  status via D-Bus (`org.freedesktop.UPower`).
- Consumed by: Noctalia battery widget (Control Center + bar widget).
- Does NOT conflict with TLP: TLP manages power policies (CPU governor,
  charge thresholds, PCIe ASPM); UPower provides read-only battery status.
- Without UPower enabled: Noctalia battery widget and Control Center battery
  settings are empty.

### C28. Host option scaffold (`config.host.*`)
- **Owner**: `modules/options/hostOpt.nix` — ONE file, dual export
  (`flake.modules.nixos.optionsHost` + `flake.modules.homeManager.optionsHost`
  as sibling attrs; nesting one inside the other breaks HM evals with
  "option does not exist"). Registered via both classes' `options` groups in
  `groups/options.nix`.
- **Tree**: `host.{isNixos, isWsl, displayProtocol (x11|wayland), shell
  (bash|zsh|fish), identity.{username, email, gitUsername, gitEmail}}`.
- **Purpose**: scaffolds the *possibility space* of a host so future hosts are
  thin templates (clone repo → set a few overrides → build). Defaults encode
  the user's standard practice; options may exist ahead of consumers (each
  description names its consumer).
- **Cross-scope default sharing**: the scopes are separate module-system
  evaluations — an HM default can never read nixos-scope config, and
  standalone-HM hosts have no nixos eval at all. Shared literal defaults live
  in a file-level `stdPractice` let consumed by BOTH declarations. Semantic
  inheritance (`gitUsername ← username`) uses same-scope
  `config.host.identity.*` references.
- **Precedence ladder**: option `default` < `mkDefault` < explicit assignment
  < `mkForce`. Override at whichever scope owns the concern. Host files carry
  NO cross-scope bridges (deliberate: cascade machinery deferred until a real
  nixos-side override need appears).
- **Consumers**: `homeManager.git` reads `identity.gitUsername/gitEmail`;
  `homeManager.clipboard` branches on `displayProtocol` + `isWsl`; the inline
  base blocks of standalone hosts derive `home.username` from
  `identity.username`. Planned: cmdLine on `shell`;
  `targets.genericLinux.enable` already set manually on standalone hosts.
- **Import order**: hosts import `<class>.options` BEFORE feature aspects —
  git aspect hard-depends on the declarations.
- **Gotchas**: new files must be `git add`ed before flake evals see them
  (import-tree reads tracked files only); `--raw` eval output cannot print
  booleans (use `--json`).

---

## 3. Wrapper / PATH status table

| Wrapper | Module | Currently | Lands |
|---|---|---|---|
| `otter-open` / `otter-power` / `otter-apps` | otterLauncher | PATH-based | — (module-owned, stays) |
| `showoff` (+ layout/term-rotator) | showoff | PATH-based via HM profile | — |
| `otter-launch` | otterLauncher | `terminal.execClass` abstraction (foot: `--app-id`, ghostty: `--class`) | — |
| hyprland keybinds/autostart | hyprland | `config.terminal.exec`/`config.terminal.term` abstraction for user-scope; absolute paths for system-scope; `config.browser.command` for browser launch | — |
| noctalia autostart | hyprland | `inputs.noctalia.packages.*.default` (store path) | — |

---

## 4. Do-not-touch registers

- `homeManager.cmdLine` `bashrcExtra` hm-session-vars sourcing — user-reported
  issues; frozen (TODO stretch).
- `services.state.items` bluetooth — REACH, as-is (`../plans/deferred/state-implementation.md`).
- Ghostty window rules/classes (incl. dead `com.center.focus`) — kept as legacy
  (phase-3 decision, void). Experimental stack only (laptop).
- `dk`/`obs` config.toml stubs — left as-is.
- `_lib/` naming — **ELIMINATED** (decision #53, superseded by Option A revision).
  All cross-module shared values use the options module pattern with auto-wiring
  defaults. Feature modules NEVER set config values. New modules MUST use
  `config.*` for sharing.
- **Noctalia config**: only documented settings are valid; validated with
  `noctalia config validate`. Non-existent keys silently accepted but produce no
  effect.
