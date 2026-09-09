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
      self.modules.homeManager.wezterm

      # standalone base identity — inline (plan D9): homeManager.main
      # assumes a graphical NixOS session
      ({ pkgs, lib, config, ... }: {
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

        # GNOME Shell/Settings-Daemon wiring for the WezTerm Flatpak this
        # host uses as its local terminal — modules/programs/wezterm.nix
        # owns the DE-agnostic config/font mechanics; this is Ubuntu+GNOME-
        # specific glue (org.gnome.settings-daemon custom keybindings,
        # org.gnome.shell dock favorites) that belongs at the host level,
        # not in a system-agnostic aspect. dconf/gsettings state isn't a
        # dotfile home-manager can otherwise manage.
        home.activation.pinWeztermToGnomeDock = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          DCONF=${lib.getExe pkgs.dconf}
          GSETTINGS=${lib.getExe' pkgs.glib "gsettings"}

          $DCONF write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/command \
            "'flatpak run org.wezfurlong.wezterm'"
          $DCONF write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/command \
            "'flatpak run org.wezfurlong.wezterm start -- tmux new-session -A -s main'"

          CURRENT_FAVS=$($GSETTINGS get org.gnome.shell favorite-apps)
          case "$CURRENT_FAVS" in
            *"'kitty.desktop'"*)
              NEW_FAVS=$(printf '%s' "$CURRENT_FAVS" | ${lib.getExe' pkgs.gnused "sed"} \
                "s/'kitty\\.desktop'/'org.wezfurlong.wezterm.desktop'/")
              $GSETTINGS set org.gnome.shell favorite-apps "$NEW_FAVS"
              ;;
          esac
        '';
      })
    ];
  };
}
