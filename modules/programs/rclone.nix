# ==========================================================================
# RCLONE (cloud storage sync/mount)
# ==========================================================================
# Program aspect: cloud sync/mount tooling. System-scale (NixOS): the FUSE
# allow-other kernel config. User-scale (Home Manager): the rclone binary on
# the user profile plus the rclone-box systemd mount unit (absolute store
# path).
{ inputs, ... }: {
  flake.modules.nixos.rclone = { pkgs, ... }: {
    programs.fuse.userAllowOther = true;
  };

  flake.modules.homeManager.rclone =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      fusermount =
        if config.host.isNixos then "/run/wrappers/bin/fusermount3" else "/usr/bin/fusermount3";
    in
    {
      home.packages = [ pkgs.rclone ];

      systemd.user.services.rclone-box = {
        Unit = {
          Description = "Rclone Box Drive Mount Service";
          AssertPathExists = "${config.home.homeDirectory}/.config/rclone/rclone.conf";
        };
        Service = {
          Type = "notify";
          ExecStartPre = "-${lib.getExe' pkgs.coreutils "mkdir"} -p ${config.home.homeDirectory}/Box";

          ExecStart = "${lib.getExe pkgs.rclone} mount boxdrive: ${config.home.homeDirectory}/Box --config=${config.home.homeDirectory}/.config/rclone/rclone.conf --vfs-cache-mode full --vfs-cache-max-age 1h --vfs-cache-max-size 10G --dir-cache-time 1m --poll-interval 1m --allow-other --umask 0022 --buffer-size 32M";

          ExecStop = "${fusermount} -u ${config.home.homeDirectory}/Box";

          Restart = "on-failure";
          RestartSec = "5s";
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    };
}
