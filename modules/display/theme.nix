# ==========================================================================
# THEME ENGINE (profiles, sync, switch CLI) — zero-baseline, path-indirected
# ==========================================================================
# User-scale (Home Manager): the theme profile registry (12 profiles) plus
# the sync/switch machinery. Ported from live /etc/nixos/modules/theme.nix
# (NOT the legacy/ snapshot — that copy still carries the gtk.css
# transparency bug, fixed live and documented in /etc/nixos/assets/
# ghostty-transparency.md).
#
# ARCHITECTURE (no baseline):
# - active.json (~/.local/share/theme/active.json) is the SINGLE source of
#   truth for the active theme. It persists across rebuilds and reboots —
#   the theme is inherently persistent state, not a config value.
# - ghostty's config (owned by ghostty.nix) has no theme line at all; it
#   pulls one in via `config-file = <stable path to generated/ghostty/
#   theme.conf>`. sync-ghostty rewrites that file (`theme = <name>`) and
#   signals ghostty to reload — the deployed config never changes, so a
#   home-manager switch can never reset the theme.
# - home.activation.initTheme re-runs the sync after every home-manager
#   switch (bootstrap on first run, consistency re-link afterwards).
#
# GTK CSS TRANSPARENCY FIX (postmortem): the generated GTK CSS must NOT
# paint an opaque background-color on the bare `window` type selector —
# ghostty implements `background-opacity < 1` by dropping its `.background`
# class, and an opaque `window` rule forces a full-surface opaque region so
# the compositor skips blur/alpha. Scope the background to windows that
# self-declare `.background`:
#   window { color: @theme_fg_color; }
#   window.background, .background { background-color: @theme_bg_color; ... }
#
# INTERFACE CONTRACT (ghostty): ghostty.nix is the SOLE owner of
# xdg.configFile."ghostty/config". This module does NOT declare it — it only
# drives the theme at runtime via the shared config-file path (../_lib/
# theme.nix). The ghosttyThemeConf path must stay in sync with ghostty.nix.
#
# RUNTIME SYMLINK TARGETS (written + linked by the sync script):
#   hypr/palette.lua, waybar/colors.css, tmux/colors.tmux,
#   nvim/lua/lean/core/palette.lua, cava/themes/nixos-generated,
#   gtk-{3,4}.0/gtk.css + settings.ini
# Wallpaper paths referenced by profiles are provisioned by homeManager.wallpapers.
{ inputs, ... }: {
  flake.modules.homeManager.theme = { config, pkgs, lib, ... }: let
    themeLib = import ../_lib/theme.nix { home = config.home.homeDirectory; };
    THEME_DIR = themeLib.dir;
    THEME_PROFILES = {
      coffee = {
        ghostty_theme = "Monokai Pro Ristretto";
        wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/sunset-elk.jpg";
      };
      outer = {
        ghostty_theme = "Sleepy Hollow";
        wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/outer-wilds.jpg";
      };
      botw = {
        ghostty_theme = "Desert";
        wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/zelda-botw.jpg";
      };
      wane = {
        ghostty_theme = "Miasma";
        wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/lake-mountain.jpg";
      };
      crisp = {
        ghostty_theme = "Earthsong";
        wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/boat-mountain.jpg";
      };
      journal = {
        ghostty_theme = "Melange Dark";
        wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/sunset-hills.jpg";
      };
      pastel = {
        ghostty_theme = "Chalk";
        wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/mountain-birds.png";
      };
      rain = {
        ghostty_theme = "Rose Pine Moon";
        wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/rain-lake.jpg";
      };
      snow = {
        ghostty_theme = "owl";
        wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/snow-peak.jpg";
      };
      space = {
        ghostty_theme = "Spacedust";
        wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/space-purple.jpg";
      };
      swamp = {
        ghostty_theme = "IC Green PPL";
        wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/mountain-green.jpg";
      };
      beach = {
        ghostty_theme = "Arthur";
        wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/beach.jpg";
      };
    };
    DEFAULT_THEME = "journal";

    writeProfilesScript = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: profile: "write_profile ${name} '${builtins.toJSON ({ theme_name = name; } // profile)}'"
      ) THEME_PROFILES
    );

    syncScript = pkgs.writeShellScript "sync-ghostty" ''
      set -euo pipefail

      THEME_DIR="${THEME_DIR}"
      GENERATED="$THEME_DIR/generated"
      GHOSTTY_CONF="${themeLib.ghosttyThemeConf}"
      GHOSTTY=${pkgs.ghostty}/bin/ghostty
      JQ=${pkgs.jq}/bin/jq

      mkdir -p "$GENERATED/hypr" "$GENERATED/waybar" "$GENERATED/tmux" \
               "$GENERATED/nvim" "$GENERATED/cava" "$GENERATED/gtk" \
               "$GENERATED/ghostty" \
               "${config.home.homeDirectory}/.config/hypr" \
               "${config.home.homeDirectory}/.config/waybar" \
               "${config.home.homeDirectory}/.config/tmux" \
               "${config.home.homeDirectory}/.config/nvim/lua/lean/core" \
               "${config.home.homeDirectory}/.config/cava/themes"

      # The theme is resolved exclusively from active.json: write the
      # ghostty config-file at a stable path (never sed the deployed config).
      if [ ! -f "$THEME_DIR/active.json" ]; then
        echo "Error: no active theme ($THEME_DIR/active.json). Run 'theme switch <name>' first."
        exit 1
      fi
      G_THEME=$($JQ -r '.ghostty_theme' "$THEME_DIR/active.json")
      printf 'theme = %s\n' "$G_THEME" > "$GHOSTTY_CONF"

      # Resolve the palette from ghostty's CURRENT resolved config — which now
      # includes the freshly written theme.conf — then regenerate consumers.
      G_CONFIG=$("$GHOSTTY" +show-config 2>/dev/null || echo "")

      get_hex_base() {
        local val
        val=$(echo "$G_CONFIG" | grep -E "^$1[[:space:]]*=" | head -n1 | cut -d'=' -f2 | tr -d '[:space:]#')
        echo "''${val//[\"\']}"
      }

      get_palette_hex() {
        local idx="$1"
        echo "$G_CONFIG" | grep -E "^palette[[:space:]]*=[[:space:]]*''${idx}=" | head -n1 | cut -d'#' -f2 | tr -d '[:space:]'
      }

      BG=$(get_hex_base "background")
      FG=$(get_hex_base "foreground")
      C0_BLACK=$(get_palette_hex "0")
      C1_RED=$(get_palette_hex "1")
      C2_GREEN=$(get_palette_hex "2")
      C3_YELLOW=$(get_palette_hex "3")
      C4_BLUE=$(get_palette_hex "4")
      C5_MAGENTA=$(get_palette_hex "5")
      C6_CYAN=$(get_palette_hex "6")
      C7_WHITE=$(get_palette_hex "7")
      C8_GRAY=$(get_palette_hex "8")

      BG=''${BG:-"000000"}
      FG=''${FG:-"cdd6f4"}
      C0_BLACK=''${C0_BLACK:-"1e1e2e"}
      C1_RED=''${C1_RED:-"f38ba8"}
      C2_GREEN=''${C2_GREEN:-"a6e3a1"}
      C3_YELLOW=''${C3_YELLOW:-"f9e2af"}
      C4_BLUE=''${C4_BLUE:-"89b4fa"}
      C5_MAGENTA=''${C5_MAGENTA:-"cba6f7"}
      C6_CYAN=''${C6_CYAN:-"89dceb"}
      C7_WHITE=''${C7_WHITE:-"cdd6f4"}
      C8_GRAY=''${C8_GRAY:-"585b70"}

      cat > "$GENERATED/hypr/palette.lua" <<PAL
      local M = {}
      M.bg = "rgb($BG)"
      M.fg = "rgb($FG)"
      M.accent = "rgb($C2_GREEN)"
      M.muted = "rgb($C8_GRAY)"
      M.bg_hex = "0x$BG"
      M.fg_hex = "0x$FG"
      M.accent_hex = "0x$C2_GREEN"
      M.muted_hex = "0x$C8_GRAY"
      return M
      PAL

      cat > "$GENERATED/waybar/colors.css" <<CSS
      @define-color theme_bg #$BG;
      @define-color theme_fg #$FG;
      @define-color theme_accent #$C2_GREEN;
      @define-color theme_muted #$C8_GRAY;
      CSS

      cat > "$GENERATED/tmux/colors.tmux" <<TMUX
      set -g status-style "bg=#$BG,fg=#$FG"
      set -g status-left "#[fg=#$BG,bg=#$C2_GREEN,bold] 󰨖 #S #[bg=default,fg=default] "
      # status-right intentionally omitted — continuum prepends its save
      # interpolation there; overwriting it breaks auto-save.
      set -g window-status-format "#[fg=#$C8_GRAY,bg=default] #I:#W "
      set -g window-status-current-format "#[fg=#$C2_GREEN,bg=#$C8_GRAY,bold] #I:#W "
      set -g window-status-separator ""
      set -g pane-border-style "fg=#$C8_GRAY"
      set -g pane-active-border-style "fg=#$C2_GREEN"
      set -g message-style "bg=#$C8_GRAY,fg=#$C2_GREEN,bold"
      TMUX

      cat > "$GENERATED/nvim/palette.lua" <<NVIM
      return {
        bg       = "#$BG",
        fg       = "#$FG",
        black    = "#$C0_BLACK",
        red      = "#$C1_RED",
        green    = "#$C2_GREEN",
        yellow   = "#$C3_YELLOW",
        blue     = "#$C4_BLUE",
        magenta  = "#$C5_MAGENTA",
        cyan     = "#$C6_CYAN",
        white    = "#$C7_WHITE",
        gray     = "#$C8_GRAY",
      }
      NVIM

      # Cava vertical gradient: map theme palette to 8-step gradient (bottom → top)
      cat > "$GENERATED/cava/nixos-generated" <<CAVA
      [color]
      background = 'default'
      foreground = '#$FG'

      gradient = 1
      gradient_color_1 = '#$C6_CYAN'
      gradient_color_2 = '#$C5_MAGENTA'
      gradient_color_3 = '#$C1_RED'
      gradient_color_4 = '#$C3_YELLOW'
      gradient_color_5 = '#$C2_GREEN'
      CAVA

      # GTK theme: remap the palette every plain GTK3/GTK4 app reads via the
      # named colors the default theme references (theme_bg_color etc.), plus a
      # few base rules. Linked into ~/.config/gtk-{3,4}.0/gtk.css so ALL GTK
      # apps (including ripdrag) follow the system theme.
      #
      # TRANSPARENCY CONTRACT (ghostty-transparency.md postmortem): the
      # background-color must be scoped to `.background`-carrying windows, never
      # the bare `window` type selector. Ghostty removes `.background` when
      # `background-opacity < 1`; an opaque `window` rule would force a
      # full-surface opaque region (no blur, no alpha).
      cat > "$GENERATED/gtk/colors.css" <<CSS
      @define-color theme_bg_color #$BG;
      @define-color theme_fg_color #$FG;
      @define-color theme_base_color #$BG;
      @define-color theme_text_color #$FG;
      @define-color theme_selected_bg_color #$C2_GREEN;
      @define-color theme_selected_fg_color #$BG;
      @define-color theme_unfocused_bg_color #$BG;
      @define-color theme_unfocused_fg_color #$C8_GRAY;
      @define-color accent_color #$C2_GREEN;
      @define-color bg_color #$BG;
      @define-color fg_color #$FG;
      @define-color base_color #$BG;
      @define-color text_color #$FG;
      @define-color selected_bg_color #$C2_GREEN;
      @define-color selected_fg_color #$BG;
      @define-color border_color #$C8_GRAY;
      @define-color insensitive_fg_color #$C8_GRAY;
      @define-color theme_muted_color #$C8_GRAY;

      window {
        color: @theme_fg_color;
      }
      window.background, .background {
        background-color: @theme_bg_color;
        color: @theme_fg_color;
      }
      headerbar, .titlebar {
        background-color: @theme_bg_color;
        color: @theme_fg_color;
      }
      label { color: @theme_fg_color; }
      selection {
        background-color: @theme_selected_bg_color;
        color: @theme_selected_fg_color;
      }
      scrollbar { background-color: @theme_bg_color; }

      .drag, .drag label {
        background-color: @theme_muted_color;
        color: @theme_bg_color;
        border-radius: 12px;
      }
      CSS

      cat > "$GENERATED/gtk/settings.ini" <<INI
      [Settings]
      gtk-application-prefer-dark-theme=1
      INI

      link() {
        local src="$1" dst="$2"
        mkdir -p "$(dirname "$dst")"
        if [ -L "$dst" ]; then
          rm "$dst"
        elif [ -e "$dst" ]; then
          rm "$dst"
        fi
        ln -s "$src" "$dst"
      }

      link "$GENERATED/hypr/palette.lua"     "${config.home.homeDirectory}/.config/hypr/palette.lua"
      link "$GENERATED/waybar/colors.css"    "${config.home.homeDirectory}/.config/waybar/colors.css"
      link "$GENERATED/tmux/colors.tmux"     "${config.home.homeDirectory}/.config/tmux/colors.tmux"
      link "$GENERATED/nvim/palette.lua"     "${config.home.homeDirectory}/.config/nvim/lua/lean/core/palette.lua"
      link "$GENERATED/cava/nixos-generated" "${config.home.homeDirectory}/.config/cava/themes/nixos-generated"
      link "$GENERATED/gtk/colors.css"       "${config.home.homeDirectory}/.config/gtk-3.0/gtk.css"
      link "$GENERATED/gtk/colors.css"       "${config.home.homeDirectory}/.config/gtk-4.0/gtk.css"
      link "$GENERATED/gtk/settings.ini"     "${config.home.homeDirectory}/.config/gtk-3.0/settings.ini"
      link "$GENERATED/gtk/settings.ini"     "${config.home.homeDirectory}/.config/gtk-4.0/settings.ini"

      if [ -n "''${TMUX:-}" ]; then
        tmux source-file "$HOME/.config/tmux/tmux.conf"
      fi

      command -v pkill >/dev/null 2>&1 && {
        pkill -USR2 waybar 2>/dev/null || true
        pkill -SIGUSR2 ghostty 2>/dev/null || true
      }
      command -v hyprctl >/dev/null 2>&1 && hyprctl reload 2>/dev/null || true

      if [ -d "''${XDG_RUNTIME_DIR:-/tmp}" ]; then
        find "''${XDG_RUNTIME_DIR:-/tmp}" -type s 2>/dev/null | grep "nvim" | while read -r server; do
          nvim --server "$server" --remote-expr "execute('lua package.loaded[\"lean.core.palette\"] = nil; vim.cmd(\"colorscheme lean_sync\")')" >/dev/null 2>&1 &
        done || true
      fi
    '';

    switchScript = pkgs.writeShellScript "theme-switch" ''
      set -euo pipefail

      THEME_DIR="${THEME_DIR}"
      SYNC_SCRIPT="${syncScript}"
      JQ=${pkgs.jq}/bin/jq

      PROFILE_NAME="''${1:-}"

      if [ -z "$PROFILE_NAME" ]; then
        echo "Usage: theme switch <name>"
        echo "Available themes:"
        ls -1 "$THEME_DIR/profiles/" 2>/dev/null | sed 's/\.json//' || echo "  (no profiles installed)"
        exit 1
      fi

      PROFILE="$THEME_DIR/profiles/$PROFILE_NAME.json"
      if [ ! -f "$PROFILE" ]; then
        echo "Error: Profile '$PROFILE_NAME' not found."
        echo "Available themes:"
        ls -1 "$THEME_DIR/profiles/" | sed 's/\.json//'
        exit 1
      fi

      echo "Switching to theme: $PROFILE_NAME"
      $JQ -r '. + {theme_name: "'$PROFILE_NAME'"}' "$PROFILE" > "$THEME_DIR/active.json"

      WALLPAPER=$($JQ -r '.wallpaper' "$THEME_DIR/active.json")
      if [ -f "$WALLPAPER" ]; then
        if command -v waypaper >/dev/null 2>&1; then
          waypaper --wallpaper "$WALLPAPER"
        elif command -v swaybg >/dev/null 2>&1; then
          pkill swaybg 2>/dev/null || true
          swaybg -i "$WALLPAPER" -m fill -f &
        fi
      fi

      exec "$SYNC_SCRIPT"
    '';

    themeCli = pkgs.writeShellScriptBin "theme" ''
      THEME_DIR="${THEME_DIR}"

      case "''${1:-}" in
        switch)
          exec "${switchScript}" "''${2:-}"
          ;;
        list)
          if [ "''${2:-}" = "--pure" ]; then
            ls -1 "$THEME_DIR/profiles/" 2>/dev/null | sed 's/\.json//'
          else
            echo "Available themes:"
            ls -1 "$THEME_DIR/profiles/" 2>/dev/null | sed 's/\.json//' || echo "  (none)"
            echo ""
            ACTIVE=$(cat "$THEME_DIR/active.json" 2>/dev/null | ${pkgs.jq}/bin/jq -r '.theme_name' 2>/dev/null || echo "unknown")
            echo "Active: $ACTIVE"
          fi
          ;;
        current)
          if [ -f "$THEME_DIR/active.json" ]; then
            ${pkgs.jq}/bin/jq -r '"\(.theme_name) [\(.ghostty_theme)]"' "$THEME_DIR/active.json"
          else
            echo "No active theme"
            exit 1
          fi
          ;;
        reload)
          exec "${syncScript}"
          ;;
        *)
          echo "Usage: theme <command>"
          echo ""
          echo "Commands:"
          echo "  switch <name>  Switch to a theme profile"
          echo "  list           List available themes and show active"
          echo "  current        Show the active theme"
          echo "  reload         Re-sync colors without switching"
          ;;
      esac
    '';
  in {
    home.packages = [
      themeCli
      pkgs.jq
    ];

    home.activation.initTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.coreutils}/bin/mkdir -p ${THEME_DIR}/profiles

      write_profile() {
        local name="$1" json="$2"
        ${pkgs.coreutils}/bin/printf '%s\n' "$json" > "${THEME_DIR}/profiles/$name.json"
      }

      ${writeProfilesScript}

      if [ ! -f "${THEME_DIR}/active.json" ]; then
        ${pkgs.coreutils}/bin/printf '%s\n' '${
          builtins.toJSON {
            theme_name = DEFAULT_THEME;
            ghostty_theme = THEME_PROFILES.${DEFAULT_THEME}.ghostty_theme;
            wallpaper = THEME_PROFILES.${DEFAULT_THEME}.wallpaper;
          }
        }' > "${THEME_DIR}/active.json"
      fi

      # Bootstrap (first run) / re-apply (every switch): write theme.conf from
      # active.json, regenerate palettes + links. Headless-safe — the reload
      # commands inside sync are guarded with || true.
      "${syncScript}"
    '';

    # These three paths are runtime symlinks created by the sync script; never
    # let Home Manager manage them (guards against future conflicting configs).
    xdg.configFile."hypr/palette.lua".enable = false;
    xdg.configFile."waybar/colors.css".enable = false;
    xdg.configFile."tmux/colors.tmux".enable = false;

    # Cava config: reference the dynamically generated theme file
    xdg.configFile."cava/config" = {
      force = true;
      text = ''
        [color]
        theme = nixos-generated
      '';
    };

    # NOTE: xdg.configFile."ghostty/config" is intentionally NOT declared here.
    # ghostty.nix is the sole owner; this module rewrites it at runtime only.
  };
}
