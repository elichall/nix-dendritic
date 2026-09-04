# ==========================================================================
# Linux Host Configuration (standalone Home Manager — non-NixOS, headless)
# ==========================================================================
# Template host: clone the repo onto a foreign-distro machine and activate.
# Toolbox-parity userland (shell/git/tmux/nvim/yazi/opencode) + opencode; no
# theming, no display stack. Cross-platform plan:
# modules/_assets/plans/wsl-linux-hosts.md (D2/D7/D9).
{ inputs, self, ... }: {
  flake.homeConfigurations.linux = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;

    modules = [
      # cross-module option declarations (host scaffold + shared options)
      self.modules.homeManager.options

      # aspect groups (dev toolchain + utilities)
      self.modules.homeManager.toolbox

      # remaining aspects (not grouped)
      self.modules.homeManager.clipboard
      self.modules.homeManager.mimeDefaults
      self.modules.homeManager.initProject

      # standalone base identity — inline (plan D9): homeManager.main
      # assumes a graphical NixOS session
      ({ pkgs, config, ... }: {
        # identity flows from the host scaffold (C28 consumer)
        home.username = config.host.identity.username;
        home.homeDirectory = "/home/${config.host.identity.username}";
        home.stateVersion = "26.05";

          host.isNixos = false; # foreign distro → genericLinux behavior below

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
