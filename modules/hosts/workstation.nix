# ==========================================================================
# NixOS Workstation Host Configuration
# ==========================================================================
# Host wiring map + aspect groups: modules/_assets/documentation/module-contracts.md (§1).
{ inputs, self, ... }: {
  flake.nixosConfigurations.workstation = inputs.nixpkgs.lib.nixosSystem {
    # Central flake pkg definition (unfree predicate for claude-code) — see flake.nix.
    pkgs = self.pkgs.x86_64-linux;
    specialArgs = { inherit inputs; };

    services.logind.lidSwitchExternalPower = "ignore";

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
      self.modules.nixos.sandbox

      # cross-module option declarations (host scaffold + shared options)
      self.modules.nixos.options

      # pass home-manager as a module to the nixos system configuration
      inputs.home-manager.nixosModules.home-manager

      ({ pkgs, ... }: {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          sharedModules = [
            inputs.noctalia.homeModules.default
          ];

          users.elichall = {
            imports = [
              # user base
              self.modules.homeManager.main

              # cross-module option declarations (must come before feature modules)
              self.modules.homeManager.options

              # aspect groups (dev toolchain + display/wallpaper preset + research)
              self.modules.homeManager.toolbox
              self.modules.homeManager.desktop
              self.modules.homeManager.researchGroup
              self.modules.homeManager.utils

              # remaining user-level aspects (not grouped)
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
