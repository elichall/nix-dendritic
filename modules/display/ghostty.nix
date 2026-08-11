# ==========================================================================
# GHOSTTY TERMINAL EMULATOR
# ==========================================================================
# Static terminal config. There is NO theme baseline here: the active theme
# is resolved exclusively at runtime through the stable config-file path
# below (see INTERFACE CONTRACT). The theme module's sync script rewrites
# that file and signals ghostty to reload — the deployed config never
# changes, so a home-manager switch can never reset the theme.
#
# Transparency values are the user's preferred options (window-decoration =
# false, background-opacity = 0.90). The generated GTK CSS (theme module)
# must stay palette-only per the ghostty-transparency.md postmortem — an
# element rule on the window would kill ghostty's transparency/blur.
#
# INTERFACE CONTRACT (theme module):
# - ghostty.nix is the SOLE owner of xdg.configFile."ghostty/config".
# - The theme module must NOT declare xdg.configFile."ghostty/config"
#   (conflicting definition). It only rewrites theme.conf (below) at runtime
#   via sync/switch scripts, then signals ghostty to reload.
# - config-file path is shared via ../_lib/theme.nix — keep in sync with the
#   theme module's generated/ghostty/theme.conf.
{ inputs, ... }: {
  flake.modules.homeManager.ghostty = { config, pkgs, ... }:
  let
    theme = import ../_lib/theme.nix { home = config.home.homeDirectory; };
  in {
    home.packages = [ pkgs.ghostty ];

    xdg.configFile."ghostty/config" = {
      force = true;
      text = ''
        font-family = JetBrainsMono Nerd Font
        font-family = Noto Sans Mono CJK JP
        font-size = 13
        window-decoration = false
        cursor-style = block
        background-opacity = 0.90
        background-blur = 20
        confirm-close-surface = false
        font-feature = -calt
        font-feature = -liga
        font-feature = -dlig
        command = ${pkgs.bash}/bin/bash
        config-file = ${theme.ghosttyThemeConf}
      '';
    };
  };
}
