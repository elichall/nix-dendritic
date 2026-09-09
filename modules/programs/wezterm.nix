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
  flake.modules.homeManager.wezterm =
    { lib, pkgs, ... }:
    let
      weztermConfig = pkgs.writeText "wezterm.lua" ''
        local wezterm = require 'wezterm'
        local config = wezterm.config_builder()

        config.font = wezterm.font_with_fallback({
          'JetBrainsMono Nerd Font',
          'Noto Sans Mono CJK JP',
        })
        config.font_size = 13.0

        config.window_decorations = 'NONE'
        config.enable_tab_bar = false
        config.window_background_opacity = 0.70
        -- No blur-behind on Linux/X11 in WezTerm (unlike kitty's
        -- background_blur / ghostty's background-blur) — opacity alone is
        -- the closest available parity.

        config.default_cursor_style = 'SteadyBlock'
        config.audible_bell = 'Disabled'
        config.window_close_confirmation = 'NeverPrompt'

        config.initial_cols = 120
        config.initial_rows = 34

        config.keys = {
          { key = 'c', mods = 'CTRL|SHIFT', action = wezterm.action.CopyTo 'Clipboard' },
          { key = 'v', mods = 'CTRL|SHIFT', action = wezterm.action.PasteFrom 'Clipboard' },
          { key = 'Enter', mods = 'ALT', action = wezterm.action.SendString '\x1b[13;3u' },
        }

        return config
      '';
    in
    {
      # Config is written here via activation rather than xdg.configFile:
      # WezTerm's Flatpak manifest bind-mounts the REAL ~/.config/wezterm
      # into its sandbox (shadowing the app's own isolated config dir) — but
      # that bind-mount only works if what's there is a real file.
      # xdg.configFile writes a symlink into /nix/store, and /nix/store
      # isn't visible inside the sandbox at all, so the symlink would
      # resolve to nothing in there. Writing a real (non-symlink) copy at
      # the real path is what the sandbox actually needs to see.
      #
      # DE-agnostic on purpose — no GNOME/desktop-session assumptions here.
      # Wiring this into any given host's actual desktop shell (keybinds,
      # dock pins, etc.) is that host's job, not this aspect's — see e.g.
      # modules/hosts/derivations/work.nix for the GNOME-specific glue.
      home.activation.weztermConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "$HOME/.config/wezterm"
        cp ${weztermConfig} "$HOME/.config/wezterm/wezterm.lua"
        chmod 644 "$HOME/.config/wezterm/wezterm.lua"

        # Same /nix/store-invisibility problem as the config, but for fonts:
        # JetBrainsMono Nerd Font lives in the nix profile (a store symlink
        # farm), which Flatpak's automatic font-sharing doesn't see — only
        # standard paths like ~/.local/share/fonts are auto-shared. (Noto
        # Sans Mono CJK JP is an apt package under /usr/share/fonts, which
        # IS auto-shared, so it needs no help.) Copy real font files in.
        mkdir -p "$HOME/.local/share/fonts"
        cp -f ${pkgs.nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/*.ttf \
          "$HOME/.local/share/fonts/" 2>/dev/null || true
        ${lib.getExe' pkgs.fontconfig "fc-cache"} -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
      '';
    };
}
