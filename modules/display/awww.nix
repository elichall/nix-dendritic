# ==========================================================================
# AWWW (awwwww - native notification daemon)
# ==========================================================================
# Display aspect: the wallpaper daemon engine, started by the graphical
# session. User-scale (Home Manager) only: binary on the user profile plus
# the systemd user unit (absolute store path — no system-scope dependency).
{ inputs, ... }: {
  flake.modules.homeManager.awww = { pkgs, ... }: {
    home.packages = [ pkgs.awww ];

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
