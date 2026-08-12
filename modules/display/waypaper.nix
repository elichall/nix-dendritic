# ==========================================================================
# WAYPAPER (wallpaper manager)
# ==========================================================================
# Display aspect: wallpaper restoration. User-scale (Home Manager) only:
# binary on the user profile. Restoration runs via hyprland exec-once on
# hyprland.start (modules/display/hyprland.nix) — NOT a systemd unit, because
# graphical-session.target never activates in the UWSM session (C10).
{ inputs, ... }: {
  flake.modules.homeManager.waypaper = { pkgs, ... }: {
    home.packages = [ pkgs.waypaper ];
  };
}
