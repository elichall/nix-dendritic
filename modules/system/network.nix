# nixos.network — Networking, firewall & remote access (system scale).
#
# Leaned out of modules/configuration.nix (nixos.main).
# Wired into workstation.nix via `self.modules.nixos.network`.
{ inputs, ... }: {
  flake.modules.nixos.network = { config, lib, ... }: {
    networking.hostName = config.host.hostName;
    networking.networkmanager.enable = true;

    # ssh friendly settings for a laptop
    networking.networkmanager.wifi.powersave = false;
    services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";

    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        # Key-based trust (host.trustedSshKeys) is verified working fleet-wide
        # (t480 <-> work desktop, iPhone -> t480) — password auth is no longer
        # the only path in, so it's off. If a non-fleet-device fallback is
        # ever needed, see modules/_assets/plans/outside-fleet-totp-auth.md —
        # that reintroduces access via keyboard-interactive/PAM (password +
        # TOTP), not by flipping this back to true.
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        MaxAuthTries = 3;
        # Scaffolding for host.require2fa (modules/options/hostOpt.nix): once
        # true, a key alone is no longer sufficient — pubkey must succeed
        # *and* keyboard-interactive (Google Authenticator, wired in
        # security.nix) both succeed. lib.mkIf so this key is simply absent
        # (not merely off) when require2fa is false, matching upstream's
        # default AuthenticationMethods behavior (any configured method).
        AuthenticationMethods = lib.mkIf config.host.require2fa "publickey,keyboard-interactive";
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
