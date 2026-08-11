# ==========================================================================
# NixOS Workstation Host Configuration
# ==========================================================================
{ inputs, self, ... }: {
  flake.nixosConfigurations.workstation = inputs.nixpkgs.lib.nixosSystem {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    specialArgs = { inherit inputs; };

    # ======================================================================
    # PER HOST CONFIGURATION
    # ======================================================================
    modules = [
      # think configuration.nix (base identity: boot, locale, users, nix-ld, fonts)
      self.modules.nixos.main

      # hardware-specific (t480): fileSystems, kernel modules, microcode
      self.modules.nixos.hardwareConfig

      # ==================================================================
      # ASPECT GROUPS
      # ==================================================================
      # system-level base services (battery, network, hardware, audio, security)
      self.modules.nixos.base
      # display/wallpaper preset (display, hyprland, awww, waypaper, mime)
      self.modules.nixos.desktop

      # ==================================================================
      # REMAINING SYSTEM LVL ASPECT MODULES (not grouped)
      # ==================================================================
      self.modules.nixos.cmdLine
      self.modules.nixos.nvim
      self.modules.nixos.opencode
      self.modules.nixos.rclone
      self.modules.nixos.fastfetch

      # ======================================================================
      # PER USER CONFIGURATION
      # ======================================================================
      # pass home-manager as a module to the nixos system configuration
      inputs.home-manager.nixosModules.home-manager

      ({ pkgs, ... }: {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;

          users.elichall = {
            imports = [
              # think home.nix
              self.modules.homeManager.main

              # ==============================================================
              # ASPECT GROUPS
              # ==============================================================
              # developer toolchain (cmdLine, git, tmux, nvim, yazi)
              self.modules.homeManager.toolbox
              # display/wallpaper preset (ghostty, tui, zotero, showoff, awww, waypaper)
              self.modules.homeManager.desktop

              # ==============================================================
              # REMAINING HOME LVL ASPECT MODULES (not grouped)
              # ==============================================================
              self.modules.homeManager.rclone
              self.modules.homeManager.fastfetch
            ];
          };
        };
      })
    ];
  };
}
