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
      # think configuration.nix
      self.modules.nixos.main
      self.modules.nixos.battery
      self.modules.nixos.network
      self.modules.nixos.hardware
      self.modules.nixos.audio
      self.modules.nixos.security

      # hardware-specific (t480): fileSystems, kernel modules, microcode
      self.modules.nixos.hardwareConfig

      # ==========================================================================
      # IMPORT SYSTEM LVL ASPECT MODULES
      # ==========================================================================
      self.modules.nixos.cmdLine
      self.modules.nixos.mime
      self.modules.nixos.nvim
      self.modules.nixos.opencode
      self.modules.nixos.hyprland
      self.modules.nixos.display
      self.modules.nixos.awww
      self.modules.nixos.waypaper
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

              # ==================================================================
              # IMPORT HOME LVL ASPECT MODULES
              # ==================================================================
              self.modules.homeManager.cmdLine
              self.modules.homeManager.nvim
              self.modules.homeManager.git
              self.modules.homeManager.tmux
              self.modules.homeManager.yazi
              self.modules.homeManager.ghostty
              self.modules.homeManager.tui
              self.modules.homeManager.zotero
              self.modules.homeManager.showoff
              self.modules.homeManager.awww
              self.modules.homeManager.waypaper
              self.modules.homeManager.rclone
              self.modules.homeManager.fastfetch
            ];
          };
        };
      })
    ];
  };
}
