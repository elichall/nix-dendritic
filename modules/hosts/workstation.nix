# ==========================================================================
# NixOS Workstation Host Configuration
# ==========================================================================
# Host wiring map + aspect groups: modules/_assets/module-contracts.md (§1).
{ inputs, self, ... }: {
  flake.nixosConfigurations.workstation = inputs.nixpkgs.lib.nixosSystem {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    specialArgs = { inherit inputs; };

    modules = [
      # base identity + machine-specific hardware
      self.modules.nixos.main
      self.modules.nixos.hardwareConfig

      # aspect groups (base services + display/wallpaper preset)
      self.modules.nixos.base
      self.modules.nixos.desktop

      # remaining system-level aspects (not grouped)
      self.modules.nixos.cmdLine
      self.modules.nixos.nvim
      self.modules.nixos.rclone

      # pass home-manager as a module to the nixos system configuration
      inputs.home-manager.nixosModules.home-manager

      ({ pkgs, ... }: {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;

          users.elichall = {
            imports = [
              # user base
              self.modules.homeManager.main

              # aspect groups (dev toolchain + display/wallpaper preset)
              self.modules.homeManager.toolbox
              self.modules.homeManager.desktop

              # remaining user-level aspects (not grouped)
              self.modules.homeManager.opencode
              self.modules.homeManager.clipboard
              self.modules.homeManager.rclone
              self.modules.homeManager.fastfetch
            ];
          };
        };
      })
    ];
  };
}
