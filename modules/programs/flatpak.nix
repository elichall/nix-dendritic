# ==========================================================================
# FLATPAK — user-level override files for apps without their own module
# ==========================================================================
# Convention follows modules/research/zotero.nix: the flatpak apps themselves
# are installed by hand (flathub); overrides live in
# ~/.local/share/flatpak/overrides/<app-id> (the file Flatseal writes). HM owns
# them as read-only symlinks — change permissions/env HERE, not in Flatseal.
# Apps with a module of their own (Zotero) keep their override there.
# Rationale: modules/_assets/documentation/decisions.md #64.
{ ... }: {
  flake.modules.homeManager.flatpak = { osConfig ? { }, lib, ... }:
    let
      # nixos-scope host option; absent on standalone-HM -> 1.0 (same as hyprland.nix)
      scale = osConfig.host.display.scale or 1.0;

      # Qt apps: native Wayland (sharp fractional scaling), universal.
      qtWayland = ''
        [Context]
        sockets=wayland;!x11;!fallback-x11;

        [Environment]
        QT_QPA_PLATFORM=wayland
      '';

      overrides = {
        "org.paraview.ParaView" = qtWayland;
        "org.freecad.FreeCAD" = qtWayland;
      }
      # Steam (CEF) is X11-only: apply the host display scale when not 1.0.
      // lib.optionalAttrs (scale != 1.0) {
        "com.valvesoftware.Steam" = ''
          [Environment]
          STEAM_FORCE_DESKTOPUI_SCALING=${builtins.toJSON scale}
        '';
      };
    in
    {
      xdg.dataFile = lib.mapAttrs' (
        id: text: lib.nameValuePair "flatpak/overrides/${id}" { inherit text; }
      ) overrides;
    };
}
