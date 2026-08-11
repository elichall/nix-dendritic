{ config, pkgs, ... }:
let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-26.05.tar.gz";
in
{
  imports = [
    ./hardware-configuration.nix
    (import "${home-manager}/nixos")
    ./modules/mime.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.elichall = import ./home.nix;
  };

  # ==========================================================================
  # SYSTEM LEVEL CONFIGURATION
  # ==========================================================================

  system.stateVersion = "26.05";

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 3;

  # Swap
  zramSwap.enable = true;

  # Time management
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

  # User account
  users.users.elichall = {
    isNormalUser = true;
    description = "Elijah";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "audio"
    ];
  };

  # Enable bash
  programs.bash.enable = true;

  # nix-ld: allows pre-compiled binaries to find system libraries
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    icu
  ];

  # Wayland/wlroots environment
  environment.sessionVariables = {
    WLR_RENDER_ALLOW_SOFTWARE = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1";
  };

  # Networking
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

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
  };

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Fuse (for rclone)
  programs.fuse.userAllowOther = true;

  # XDG portal
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
    ];
    config = {
      common = {
        default = [ "gtk" ];
      };
      Hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
      };
    };
  };

  # ==========================================================================
  # GRAPHICAL AND DISPLAY
  # ==========================================================================

  services.displayManager.ly = {
    enable = true;
    settings = {
      animation = "matrix";
      bigclock = true;
      session_log = ".local/state/ly-session.log";
    };
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = false;
  };

  # ==========================================================================
  # PACKAGES AND FONTS
  # ==========================================================================

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  # System-only packages (HM-managed programs removed from here)
  environment.systemPackages = with pkgs; [
    ripgrep
    ripdrag
    unzip
    wl-clipboard
    grimblast
    waypaper
    awww
    tailscale
    hypridle
    rclone
    brightnessctl
    xdg-utils
    tree
    # quickshell
    # way-edges

    # CLI tools (not managed by HM)
    tree-sitter
    fastfetch
    docker

    # TUI apps (not managed by HM)
    neovim
    opencode
    btop
    gdu
  ];

  # Flatpak
  services.flatpak.enable = true;
  fonts.fontDir.enable = true;
  # --- Flatpak Apps ---
  # Browser # chose later
  # Flatseal # manages permissions for flatpak apps
  # moonlight-qt # remote desktop app
  # obsidian # notes app
  # obs-studio # recording app
  # zotero # research paper app
  # steam # games
  # FreeCAD # cad
  # zoom # meetings
  # prism # minecraft launcher

  # ==========================================================================
  # SERVICES
  # ==========================================================================
  systemd.tmpfiles.rules = [
    "D /tmp/nixos-patch-* 1777 root root 7d" # auto-delete patch dirs after 7 days
    "d /tmp 1777 root root 30d" # clean any /tmp file older than 30d
  ];

  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;

      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      PCIE_ASPM_ON_AC = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";
    };
  };

  # ==========================================================================
  # NIX SETTINGS & SECURITY
  # ==========================================================================

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

  # ==========================================================================
  # SYSTEM MAINTENANCE & HARDWARE RELIABILITY
  # ==========================================================================

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
}
