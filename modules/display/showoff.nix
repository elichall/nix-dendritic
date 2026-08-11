# ==========================================================================
# SHOWOFF DASHBOARD
# ==========================================================================
# User-scale (Home Manager): dashboard helper binaries that the Phase 3
# homeManager.showoff port will consume (term-rotator, showoff-layout,
# showoff-idle scripts + hypridle/tmux configs). Until then the packages
# live here so they stay off the system profile.
#
# Consumers:
#   tty-clock, gping, cava, cmatrix, cbonsai, asciiquarium-transparent,
#   sl, lolcat, cowsay  -> showoff term-rotator / showoff-layout panes
#   weathr              -> waybar weather on-click (Phase 3 desktop-stable)
{ inputs, ... }: {
  flake.modules.homeManager.showoff = { pkgs, ... }: {
    home.packages = with pkgs; [
      tty-clock
      gping
      cava
      cmatrix
      cbonsai
      asciiquarium-transparent
      sl
      lolcat
      cowsay
      weathr
    ];
  };
}
