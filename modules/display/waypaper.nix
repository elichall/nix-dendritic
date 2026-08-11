# ==========================================================================
# WAYPAPER (wallpaper manager)
# ==========================================================================
# Display aspect: wallpaper restoration, chained after the awww daemon.
# User-scale (Home Manager) only: binary on the user profile plus the
# post-initialization wallpaper restore unit (absolute store path).
{ inputs, ... }: {
  flake.modules.homeManager.waypaper = { pkgs, ... }: {
    home.packages = [ pkgs.waypaper ];

    systemd.user.services.waypaper-restore = {
      Unit = {
        Description = "Waypaper Post-Initialization Wallpaper Restoration";
        Requires = [ "awww-daemon.service" ];
        After = [
          "awww-daemon.service"
          "graphical-session.target"
        ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 0.5";
        ExecStart = "${pkgs.waypaper}/bin/waypaper --restore";
        RemainAfterExit = true;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
