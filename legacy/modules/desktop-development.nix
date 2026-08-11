{ config, pkgs, ... }:

{
  # 1. Daemon to orchestrate Quickshell execution
  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell Experimental UI Component Engine";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "on-failure";
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
  };

  # 2. Dynamically pass your development QML script target definitions
  # xdg.configFile."quickshell/main.qml".source = ../dotfiles/quickshell/main.qml;
}
