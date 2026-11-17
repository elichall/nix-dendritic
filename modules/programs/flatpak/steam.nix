# ==========================================================================
# STEAM (flatpak com.valvesoftware.Steam — installed by hand)
# ==========================================================================
# Registry entry (modules/options/flatpakOpt.nix). The Steam client is X11-only
# (CEF): scale its UI with the host display scale, only when != 1.0
# (hyprland sets xwayland.force_zero_scaling). Decision: decisions.md #64.
{ ... }: {
  flake.modules.homeManager.flatpakSteam = { osConfig ? { }, lib, ... }:
    let
      # nixos-scope host option; absent on standalone-HM -> 1.0 (same as hyprland.nix)
      scale = osConfig.host.display.scale or 1.0;
    in
    {
      flatpak.apps."com.valvesoftware.Steam".overrides = lib.mkIf (scale != 1.0) ''
        [Environment]
        STEAM_FORCE_DESKTOPUI_SCALING=${builtins.toJSON scale}
      '';
    };
}
