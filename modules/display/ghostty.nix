# ==========================================================================
# GHOSTTY TERMINAL EMULATOR
# ==========================================================================
# Static terminal config. The `theme =` line is the baseline (journal
# default); the Phase 3 theme module drives runtime switching via its
# sync/switch scripts (which sed this file on `theme switch`).
#
# Transparency values match the live /etc/nixos config (window-decoration =
# true, background-opacity = 0.70) — see /etc/nixos/assets/
# ghostty-transparency.md for the gtk.css scoping fix that makes this work.
#
# INTERFACE CONTRACT (Phase 3 theme module):
# - ghostty.nix is the SOLE owner of xdg.configFile."ghostty/config".
# - The theme module must NOT also declare xdg.configFile."ghostty/config"
#   (that would be a conflicting option definition). It only performs
#   runtime `theme switch` via scripts that rewrite the deployed file.
# - If the theme module needs to know the baseline theme, reference the
#   `theme = Melange Dark` value here as the single source of truth.
{ inputs, ... }: {
  flake.modules.homeManager.ghostty = { pkgs, ... }: {
    home.packages = [ pkgs.ghostty ];

    xdg.configFile."ghostty/config" = {
      force = true;
      text = ''
        font-family = JetBrainsMono Nerd Font
        font-family = Noto Sans Mono CJK JP
        font-size = 13
        theme = Melange Dark
        window-decoration = false
        cursor-style = block
        background-opacity = 0.90
        background-blur = 20
        confirm-close-surface = false
        font-feature = -calt
        font-feature = -liga
        font-feature = -dlig
        command = ${pkgs.bash}/bin/bash
      '';
    };
  };
}
