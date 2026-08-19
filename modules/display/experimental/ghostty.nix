# ==========================================================================
# GHOSTTY TERMINAL EMULATOR
# ==========================================================================
# Static terminal config, no theme baseline (runtime-resolved via config-file
# path indirection). Interface contract (SOLE owner of
# xdg.configFile."ghostty/config"): modules/_assets/documentation/module-contracts.md (C1).
# Transparency values are the user's preferred options; the generated GTK CSS
# must stay palette-only (ghostty-transparency.md).
# ==========================================================================
{ inputs, ... }: {
  flake.modules.homeManager.ghostty =
    { config, pkgs, ... }:
    let
      theme = import ../../_lib/theme.nix { home = config.home.homeDirectory; };
    in
    {
      home.packages = [ pkgs.ghostty ];

      xdg.configFile."ghostty/config" = {
        force = true;
        text = ''
          font-family = JetBrainsMono Nerd Font
          font-family = Noto Sans Mono CJK JP
          font-size = 13
          window-decoration = false
          cursor-style = block
          background-opacity = 0.80
          background-blur = 30
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
