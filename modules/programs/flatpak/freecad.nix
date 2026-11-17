# ==========================================================================
# FREECAD (flatpak org.freecad.FreeCAD — installed by hand)
# ==========================================================================
# Registry entry (modules/options/flatpakOpt.nix). The flatpak pins
# QT_QPA_PLATFORM=xcb (blurry under fractional scaling): override to native
# Wayland. If the 3D viewport misbehaves, fall back to Xwayland +
# QT_SCALE_FACTOR (decisions.md #64).
{ ... }: {
  flake.modules.homeManager.flatpakFreecad = { ... }: {
    flatpak.apps."org.freecad.FreeCAD" = {
      overrides = ''
        [Context]
        sockets=wayland;!x11;!fallback-x11;

        [Environment]
        QT_QPA_PLATFORM=wayland
      '';

      mimeTypes = [ "model/step" ];
    };
  };
}
