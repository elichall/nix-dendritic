# nixos.network — Networking, firewall & remote access (system scale).
#
# Template for leaning out modules/configuration.nix (nixos.main).
# Planned content (currently in nixos.main, lines ~74-102):
#   - networking.hostName / networkmanager
#   - services.openssh (PermitRootLogin, PasswordAuthentication, MaxAuthTries)
#   - services.tailscale + TS_DEBUG_FIREWALL_MODE env
#   - networking.nftables / firewall (trustedInterfaces, tailscale port, allowPing)
#   - systemd.network.wait-online disable (initrd + main)
#
# NOT wired into any host until populated.
{ inputs, ... }: {
  flake.modules.nixos.network = { ... }: { };
}
