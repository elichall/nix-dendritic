# ==========================================================================
# NIXOS SYSTEM LEVEL MAIN MODULE
# ==========================================================================
# System-wide essentials ported from the legacy /etc/nixos/configuration.nix.
# Feature-specific system bits already extracted to their own modules:
#   shell              -> nixos.cmdLine      (programs.bash)
#   editor             -> nixos.nvim         (neovim)
#   ai                 -> nixos.opencode     (opencode)
#   display            -> nixos.display       (ly, portal, WLR env)
#   display/hyprland   -> nixos.hyprland      (compositor + hypridle)
#   display/awww       -> nixos.awww          (awww)
#   display/waypaper   -> nixos.waypaper      (waypaper)
#   programs/rclone    -> nixos.rclone        (rclone + fuse)
# Remaining cohesive splits (network, hardware, audio, security) are a
# stretch goal; they live here for now.
{ inputs, ... }: {
  flake.modules.nixos.main = { config, pkgs, ... }: {
    system.stateVersion = "26.05";

    # ======================================================================
    # BOOTLOADER & SWAP
    # ======================================================================
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.systemd-boot.configurationLimit = 3;

    zramSwap.enable = true;

    # ======================================================================
    # TIME, LOCALE & LANGUAGE
    # ======================================================================
    time.timeZone = "America/Chicago";

    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };

    # ======================================================================
    # USER ACCOUNT
    # ======================================================================
    users.users.elichall = {
      isNormalUser = true;
      description = "elijah";
      extraGroups = [
        "networkmanager"
        "wheel"
        "video"
        "audio"
      ];
    };

    # ======================================================================
    # SHELL & RUNTIME TOOLING
    # ======================================================================
    # nix-ld: allows pre-compiled binaries to find system libraries
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      stdenv.cc.cc.lib
      icu
    ];

    # ======================================================================
    # NETWORKING, FIREWALL & REMOTE ACCESS
    # ======================================================================
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

    # ======================================================================
    # BLUETOOTH
    # ======================================================================
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
        };
      };
    };

    # ======================================================================
    # AUDIO
    # ======================================================================
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # ======================================================================
    # PACKAGES AND FONTS
    # ======================================================================
    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
    ];
    fonts.fontDir.enable = true;

    # System-only packages that are not pure dependancies for a program
    environment.systemPackages = with pkgs; [
      # Base utilities (root/system-script scope)
      unzip
      wl-clipboard
      xdg-utils
      docker
    ];

    # Flatpak
    services.flatpak.enable = true;

    # ======================================================================
    # SYSTEMD TMPFILES & MAINTENANCE
    # ======================================================================
    systemd.tmpfiles.rules = [
      "D /tmp/nixos-patch-* 1777 root root 7d" # auto-delete patch dirs after 7 days
      "d /tmp 1777 root root 30d" # clean any /tmp file older than 30d
    ];

    # Solid State Drive TRIM
    # Maintains NVMe flash cell degradation and write speeds
    services.fstrim.enable = true;
    # Firmware Update Daemon
    # Allows updating BIOS, UEFI, and peripheral firmware directly via `fwupdmgr`
    services.fwupd.enable = true;
    # AMD CPU Microcode
    # Ensures the kernel loads the latest security and stability patches for the CPU
    hardware.cpu.intel.updateMicrocode = true;
    # Out-Of-Memory (OOM) Protection
    # Prevents hard system lockups during heavy RAM compilation workloads by killing
    # memory-hogging processes before the kernel freezes
    services.earlyoom.enable = true;

    # ======================================================================
    # NIX SETTINGS & SECURITY
    # ======================================================================
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      sandbox = true;
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    # Kernel sysctl hardening
    boot.kernel.sysctl = {
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;
      "kernel.kptr_restrict" = 2;
      "net.core.bpf_jit_harden" = 2;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.default.accept_source_route" = 0;
      "net.ipv6.conf.all.accept_source_route" = 0;
      "net.ipv6.conf.default.accept_source_route" = 0;
    };
  };
}
