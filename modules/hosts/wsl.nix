# ==========================================================================
# WSL Host Configuration (standalone Home Manager — toolbox style)
# ==========================================================================
# Template host for a foreign-distro WSL instance (Ubuntu/Debian under WSL).
# Toolbox-parity userland + Windows interop shims; no theming, no display
# stack. A full NixOS-in-WSL flavor (nixosConfigurations + nixos-wsl input)
# remains a future addition — isWsl × isNixos distinguish the flavors (C28).
# Cross-platform plan: modules/_assets/plans/wsl-linux-hosts.md.
{ inputs, self, ... }: {
  flake.homeConfigurations.wsl = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;

    modules = [
      # cross-module option declarations (host scaffold + shared options)
      self.modules.homeManager.options

      # aspect groups (dev toolchain + utilities)
      self.modules.homeManager.toolbox
      self.modules.homeManager.utils

      # remaining aspects (not grouped): platform-aware clipboard +
      # win32yank/wslview interop shims
      self.modules.homeManager.clipboard

      # standalone base identity — inline (plan D9): homeManager.main
      # assumes a graphical NixOS session
      ({ pkgs, config, ... }: {
        # identity flows from the host scaffold (C28 consumer)
        home.username = config.host.identity.username;
        home.homeDirectory = "/home/${config.host.identity.username}";
        home.stateVersion = "26.05";

        host.isNixos = false;
        host.isWsl = true;
        # WSLg exposes a real wayland compositor — default fits; explicit
        # for template clarity. clipboard.nix still adds xclip: tools may
        # pick either protocol (both are present under WSLg).
        host.displayProtocol = "wayland";

        targets.genericLinux.enable = true;
        fonts.fontconfig.enable = true;
        # HM has no fonts.packages — user-scale fonts live in
        # home.packages; fontconfig picks them up from there.
        home.packages = with pkgs; [
          nerd-fonts.jetbrains-mono
          noto-fonts
        ];
        programs.home-manager.enable = true;
      })
    ];
  };
}
