# ==========================================================================
# AWWW (awwwww - native notification daemon)
# ==========================================================================
# Display aspect: the wallpaper daemon engine, started by the graphical
# session. System-scale (NixOS): binary exposure. User-scale (Home Manager):
# the systemd user unit.
{ inputs, ... }: {
  flake.modules.nixos.awww = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.awww ];
  };

  flake.modules.homeManager.awww = { pkgs, ... }: {
    systemd.user.services.awww-daemon = {
      Unit = {
        Description = "Awww Wallpaper Management Daemon Engine";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.awww}/bin/awww-daemon";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
