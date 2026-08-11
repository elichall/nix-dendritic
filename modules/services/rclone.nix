# ==========================================================================
# RCLONE (cloud storage sync/mount)
# ==========================================================================
# System-scale (NixOS): binary + FUSE user-space mounting. User-scale
# (Home Manager): the rclone-box systemd mount unit.
{ inputs, ... }: {
  flake.modules.nixos.rclone = { pkgs, ... }: {
    programs.fuse.userAllowOther = true;
    environment.systemPackages = [ pkgs.rclone ];
  };

  flake.modules.homeManager.rclone = { config, pkgs, ... }: {
    systemd.user.services.rclone-box = {
      Unit = {
        Description = "Rclone Box Drive Mount Service";
        AssertPathExists = "${config.home.homeDirectory}/.config/rclone/rclone.conf";
      };
      Service = {
        Type = "notify";
        ExecStartPre = "-${pkgs.coreutils}/bin/mkdir -p ${config.home.homeDirectory}/Box";

        ExecStart = "${pkgs.rclone}/bin/rclone mount boxdrive: ${config.home.homeDirectory}/Box --config=${config.home.homeDirectory}/.config/rclone/rclone.conf --vfs-cache-mode full --vfs-cache-max-age 1h --vfs-cache-max-size 10G --dir-cache-time 1m --poll-interval 1m --allow-other --umask 0022 --buffer-size 32M";

        ExecStop = "/run/wrappers/bin/fusermount3 -u ${config.home.homeDirectory}/Box";

        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
