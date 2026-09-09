# ==========================================================================
# Linux Host Configuration (standalone Home Manager — non-NixOS, headless)
# ==========================================================================
# Template host: clone the repo onto a foreign-distro machine and activate.
# Toolbox-parity userland (shell/git/tmux/nvim/yazi/opencode) + opencode; no
# theming, no display stack. Cross-platform plan:
# modules/_assets/plans/wsl-linux-hosts.md (D2/D7/D9).
{ inputs, self, ... }: {
  flake.homeConfigurations.work = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = self.pkgs.x86_64-linux;

    modules = [
      # cross-module option declarations (host scaffold + shared options)
      self.modules.homeManager.options

      # aspect groups (dev toolchain + utilities)
      self.modules.homeManager.toolbox
      self.modules.homeManager.research

      # remaining aspects (not grouped)
      self.modules.homeManager.clipboard
      self.modules.homeManager.mimeDefaults
      self.modules.homeManager.rclone
      self.modules.homeManager.fastfetch
      self.modules.homeManager.initProject
      self.modules.homeManager.network

      # standalone base identity — inline (plan D9): homeManager.main
      # assumes a graphical NixOS session
      ({ pkgs, config, ... }: {
        # identity flows from the host scaffold (C28 consumer)
        host.identity.username = "eli";

        home.username = config.host.identity.username;
        home.homeDirectory = "/home/${config.host.identity.username}";
        home.stateVersion = "26.05";

        host.isNixos = false; # foreign distro → genericLinux behavior below
        host.trustedSshKeys = [
          # t480
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP7m3i3KyhA2ySpQf9L0i7VqVxCil2np9blYy1ggV69v 1elijah.hall@gmail.com"
          # iPhone (Termius)
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBSE6LTjQ7T6YAAmdwKZMTAy97ZBiGCli6yvwDtv73vO"
        ];

        targets.genericLinux.enable = true;
        fonts.fontconfig.enable = true;
        # HM has no fonts.packages — user-scale fonts live in
        # home.packages; fontconfig picks them up from there.
        home.packages = with pkgs; [
          nerd-fonts.jetbrains-mono
          noto-fonts
        ];
      })
    ];
  };
}
