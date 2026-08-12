# ==========================================================================
# AWWW (awwwww - native notification daemon)
# ==========================================================================
# Display aspect: the wallpaper daemon engine. User-scale (Home Manager)
# only: binary on the user profile. Launched via hyprland exec-once on
# hyprland.start (modules/display/hyprland.nix) — NOT a systemd unit, because
# graphical-session.target never activates in the UWSM session (C10).
{ inputs, ... }: {
  flake.modules.homeManager.awww = { pkgs, ... }: {
    home.packages = [ pkgs.awww ];
  };
}
