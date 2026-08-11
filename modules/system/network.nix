# nixos.network — Networking, firewall & remote access (system scale).
#
# Leaned out of modules/configuration.nix (nixos.main).
# Wired into workstation.nix via `self.modules.nixos.network`.
{ inputs, ... }: {
  flake.modules.nixos.network = { config, ... }: {
    networking.hostName = "t480-nixos";
    networking.networkmanager.enable = true;

    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = true;
        MaxAuthTries = 3;
      };
    };

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
}
