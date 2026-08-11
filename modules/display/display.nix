# ==========================================================================
# DISPLAY (generic, compositor-agnostic)
# ==========================================================================
# System-scale (NixOS): Wayland/wlroots env, XDG portal, display manager.
# Hyprland-specific bits live in ./hyprland.nix.
{ inputs, ... }: {
  flake.modules.nixos.display = { pkgs, ... }: {
    # Wayland/wlroots environment
    environment.sessionVariables = {
      WLR_RENDER_ALLOW_SOFTWARE = "1";
      WLR_NO_HARDWARE_CURSORS = "1";
      NIXOS_OZONE_WL = "1";
    };

    # XDG portal
    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-hyprland
      ];
      config = {
        common = {
          default = [ "gtk" ];
        };
        Hyprland = {
          default = [
            "hyprland"
            "gtk"
          ];
        };
      };
    };

    # Display manager (launches the desktop session)
    services.displayManager.ly = {
      enable = true;
      settings = {
        animation = "matrix";
        bigclock = true;
        session_log = ".local/state/ly-session.log";
      };
    };
  };
}
