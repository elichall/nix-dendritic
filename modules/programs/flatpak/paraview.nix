# ==========================================================================
# PARAVIEW (flatpak org.paraview.ParaView — installed by hand)
# ==========================================================================
# Registry entry (modules/options/flatpakOpt.nix). The flatpak ships X11-only
# (blurry under fractional scaling): force native Wayland. Contract/decision:
# modules/_assets/documentation/decisions.md #64.
{ ... }: {
  flake.modules.homeManager.flatpakParaview = { ... }: {
    flatpak.apps."org.paraview.ParaView" = {
      overrides = ''
        [Context]
        sockets=wayland;!x11;!fallback-x11;

        [Environment]
        QT_QPA_PLATFORM=wayland
      '';

      mimeTypes = [
        "application/x-vtk"
        "application/x-gmsh-msh"
        "application/x-paraview-vtu"
        "application/x-paraview-vtm"
      ];

      windowRules = [
        {
          name = "paraview_file_dialog";
          match = {
            class = "^paraview$";
            title = "^Open File.*";
          };
          center = true;
        }
      ];
    };
  };
}
