# ==========================================================================
# HYPRLAND DESKTOP ENVIRONMENT
# ==========================================================================
# System-scale (NixOS): compositor + portal wiring. User-scale (Home
# Manager): session tooling (hypridle daemon, keybind-invoked brightness /
# screenshot tools). The full hyprland user config is Phase 3.
#
# PATH CAVEAT (Phase 3): keybind/autostart commands are PATH lookups run by
# the graphical-session process, which does not reliably carry the Home
# Manager user profile on PATH. Reference these binaries by absolute store
# path in the hyprland config (same technique the awww/waypaper units use),
# or run hyprland as an HM user service where the profile PATH is available.
{ inputs, ... }: {
  flake.modules.nixos.hyprland = { pkgs, ... }: {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      withUWSM = false;
    };
  };

  flake.modules.homeManager.hyprland = { pkgs, ... }: {
    home.packages = with pkgs; [
      hypridle
      grimblast
      brightnessctl
    ];
  };
}
