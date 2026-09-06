# nixos.network — Networking, firewall & remote access (system scale).
#
# Leaned out of modules/configuration.nix (nixos.main).
# Wired into workstation.nix via `self.modules.nixos.network`.
{ inputs, ... }: {
  flake.modules.nixos.network = { config, ... }: {
    networking.hostName = config.host.hostName;
    networking.networkmanager.enable = true;

    # ssh friendly settings for a laptop
    networking.networkmanager.wifi.powersave = false;
    services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";

    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = true;
        MaxAuthTries = 3;
      };
    };
    users.users.${config.host.identity.username}.openssh.authorizedKeys.keys = config.host.trustedSshKeys;

    services.tailscale.enable = true;
    systemd.services.tailscaled.serviceConfig.Environment = [
      "TS_DEBUG_FIREWALL_MODE=nftables"
    ];

    networking.nftables.enable = true;
    networking.firewall = {
      enable = true;
      trustedInterfaces = [ config.services.tailscale.interfaceName ];
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ config.services.tailscale.port ]; # Tailscale WireGuard
      allowPing = false;
    };

    # network optimizations
    systemd.network.wait-online.enable = false;
    boot.initrd.systemd.network.wait-online.enable = false;
  };

  # Standalone-HM hosts (foreign distro, not NixOS) have no services.openssh
  # of their own, and no /etc/ssh/authorized_keys.d split to fall back on
  # (that requires editing the system's sshd_config, outside standalone-HM's
  # scope) — so ~/.ssh/authorized_keys is the only file available, and other
  # things legitimately write to it too (e.g. Claude Code's own SSH access
  # for live sessions). Appending idempotently rather than declaring
  # home.file ownership of the whole file means Nix guarantees its own keys
  # are present without ever clobbering keys anything else added — the
  # trade-off is Nix can't prune a key it once added if removed from
  # host.trustedSshKeys later; that's the correct trade for a shared file.
  flake.modules.homeManager.network = { config, lib, ... }: {
    home.activation.trustedSshKeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ~/.ssh
      run chmod 700 ~/.ssh
      run touch ~/.ssh/authorized_keys
      run chmod 600 ~/.ssh/authorized_keys
      ${lib.concatMapStrings (key: ''
        grep -qxF ${lib.escapeShellArg key} ~/.ssh/authorized_keys || echo ${lib.escapeShellArg key} >> ~/.ssh/authorized_keys
      '') config.host.trustedSshKeys}
    '';
  };
}
