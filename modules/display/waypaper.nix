# ==========================================================================
# WAYPAPER (wallpaper manager)
# ==========================================================================
# Display aspect: wallpaper restoration, chained after the awww daemon.
# System-scale (NixOS): binary exposure. User-scale (Home Manager): the
# post-initialization wallpaper restore unit.
{ inputs, ... }: {
  flake.modules.nixos.waypaper = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.waypaper ];
  };

  flake.modules.homeManager.waypaper = { pkgs, ... }: {
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
