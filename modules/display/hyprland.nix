# ==========================================================================
# HYPRLAND DESKTOP ENVIRONMENT
# ==========================================================================
# System-scale (NixOS): compositor + idle daemon. Generic display concerns
# (Wayland env, portal, display manager) live in ./display.nix.
# User-scale (Home Manager) hyprland config is Phase 2.
{ inputs, ... }: {
  flake.modules.nixos.hyprland = { pkgs, ... }: {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      withUWSM = false;
    };

    environment.systemPackages = [ pkgs.hypridle ];
  };
}
