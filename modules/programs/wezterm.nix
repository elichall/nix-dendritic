# ==========================================================================
# WEZTERM (Flatpak) — work host only
# ==========================================================================
# Ubuntu 22.04 apt ships kitty 0.21.2, too old for yazi's image/PDF preview
# needs; nixpkgs' kitty can't be used here either — it links nix-store
# Mesa/GLX, which can't bind this host's real NVIDIA driver (no nixGL in
# this repo). WezTerm's Flatpak build sidesteps both: Flatpak's runtime
# handles NVIDIA driver-extension matching properly, and it gets regular
# upstream updates unlike frozen apt packages. Deliberately NOT nix-packaged
# here — this module only manages config + local desktop wiring; the binary
# comes from `flatpak install flathub org.wezfurlong.wezterm` (manual,
# one-time — see modules/_assets/plans, work-host troubleshooting).
{ ... }: {
  flake.modules.homeManager.wezterm = { lib, pkgs, ... }: {
    xdg.configFile."wezterm/wezterm.lua" = {
      force = true;
      text = ''
        local wezterm = require 'wezterm'
        local config = wezterm.config_builder()

        config.font = wezterm.font_with_fallback({
          'JetBrainsMono Nerd Font',
          'Noto Sans Mono CJK JP',
        })
        config.font_size = 13.0

        config.window_decorations = 'NONE'
        config.window_background_opacity = 0.70
        -- No blur-behind on Linux/X11 in WezTerm (unlike kitty's
        -- background_blur / ghostty's background-blur) — opacity alone is
        -- the closest available parity.

        config.default_cursor_style = 'SteadyBlock'
        config.audible_bell = 'Disabled'

        config.initial_cols = 120
        config.initial_rows = 34

        config.keys = {
          { key = 'c', mods = 'CTRL|SHIFT', action = wezterm.action.CopyTo 'Clipboard' },
          { key = 'v', mods = 'CTRL|SHIFT', action = wezterm.action.PasteFrom 'Clipboard' },
          { key = 'Enter', mods = 'ALT', action = wezterm.action.SendString '\x1b[13;3u' },
        }

        return config
      '';
    };

    # GNOME custom keybindings (Super+Return, Super+t) and the dock/favorites
    # pin are local desktop-session state, not files — dconf/gsettings is the
    # only way to manage them declaratively. Flatpak install itself is a
    # manual one-time step (outside nix's reproducibility tier by design).
    home.activation.wireWeztermDesktop = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      DCONF=${lib.getExe pkgs.dconf}
      GSETTINGS=${lib.getExe' pkgs.glib "gsettings"}

      $DCONF write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/command \
        "'flatpak run org.wezfurlong.wezterm'"
      $DCONF write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/command \
        "'flatpak run org.wezfurlong.wezterm start -- tmux new-session -A -s main'"

      CURRENT_FAVS=$($GSETTINGS get org.gnome.shell favorite-apps)
      case "$CURRENT_FAVS" in
        *"'kitty.desktop'"*)
          NEW_FAVS=$(printf '%s' "$CURRENT_FAVS" | ${lib.getExe' pkgs.gnused "sed"} \
            "s/'kitty\\.desktop'/'org.wezfurlong.wezterm.desktop'/")
          $GSETTINGS set org.gnome.shell favorite-apps "$NEW_FAVS"
          ;;
      esac
    '';
  };
}
