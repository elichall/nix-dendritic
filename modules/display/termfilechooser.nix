# ==========================================================================
# TERMINAL FILE CHOOSER PORTAL (yazi as the GUI open/save dialog)
# ==========================================================================
# xdg-desktop-portal-termfilechooser answers the FileChooser portal by
# launching a terminal file manager, so GUI apps (the Firefox flatpak, which
# always asks the portal) get yazi for uploads/saves. System scale registers
# the backend + routes Hyprland's FileChooser to it; user scale supplies its
# config. The dialog runs under app-id `termfilechooser` (see the float rule
# in hyprland.nix). Choosing nothing / quitting yazi cancels the dialog.
{ ... }: {
  flake.modules.nixos.termfilechooser = { pkgs, ... }: {
    xdg.portal = {
      extraPortals = [ pkgs.xdg-desktop-portal-termfilechooser ];
      config.Hyprland."org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
    };
  };

  flake.modules.homeManager.termfilechooser =
    { config, pkgs, lib, ... }:
    let
      portal = pkgs.xdg-desktop-portal-termfilechooser;
      # The portal is dbus-activated (no login-shell PATH), so pin yazi and the
      # terminal command here, then defer to the packaged wrapper.
      wrapper = pkgs.writeShellScript "termfilechooser-yazi" ''
        export PATH=${lib.makeBinPath [ pkgs.yazi ]}:$PATH
        export TERMCMD=${lib.escapeShellArg (config.terminal.execClass "termfilechooser" "")}
        exec ${portal}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh "$@"
      '';
    in
    {
      home.packages = [
        pkgs.yazi # wrapper dependency (Rule 4)
        portal
      ];

      xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
        [filechooser]
        cmd=${wrapper}
        default_dir=$HOME
        open_mode=suggested
        save_mode=suggested
      '';
    };
}
