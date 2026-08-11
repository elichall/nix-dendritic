# ==========================================================================
# NIXOS SYSTEM LEVEL MAIN MODULE
# ==========================================================================
# System-wide essentials ported from the legacy /etc/nixos/configuration.nix.
# Base identity config only — feature-specific system bits live in their own
# modules:
#   shell              -> nixos.cmdLine      (programs.bash)
#   editor             -> nixos.nvim         (neovim)
#   ai                 -> nixos.opencode     (opencode)
#   display            -> nixos.display       (ly, portal, WLR env)
#   display/hyprland   -> nixos.hyprland      (compositor + hypridle)
#   display/awww       -> nixos.awww          (awww)
#   display/waypaper   -> nixos.waypaper      (waypaper)
#   programs/rclone    -> nixos.rclone        (rclone + fuse)
#   system/network     -> nixos.network       (networking, ssh, tailscale, firewall)
#   system/hardware    -> nixos.hardware      (bluetooth, fstrim, fwupd, microcode, earlyoom)
#   system/audio       -> nixos.audio         (rtkit, pipewire)
#   system/security    -> nixos.security      (kernel sysctl hardening)
#   system/battery     -> nixos.battery       (TLP power management)
# nix.settings / nix.gc intentionally stay here (user choice).
{ inputs, ... }: {
  flake.modules.nixos.main = { pkgs, ... }: {
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
    ];

    # Flatpak
    services.flatpak.enable = true;

    # ======================================================================
    # SYSTEMD TMPFILES
    # ======================================================================
    systemd.tmpfiles.rules = [
      "D /tmp/nixos-patch-* 1777 root root 7d" # auto-delete patch dirs after 7 days
      "d /tmp 1777 root root 30d" # clean any /tmp file older than 30d
    ];

    # ======================================================================
    # NIX SETTINGS & GC
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
  };
}
