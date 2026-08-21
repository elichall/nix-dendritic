# ==========================================================================
# DEFAULT MIME APPLICATIONS (HM scope)
# ==========================================================================
# User-level MIME associations. Browser references come from config.browser.desktop.
# Engineering MIME types registered at NixOS scale in mime.nix.
{ ... }: {
  flake.modules.homeManager.mimeDefaults = { config, ... }: {
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = [ config.browser.desktop ];
        "x-scheme-handler/http" = [ config.browser.desktop ];
        "x-scheme-handler/https" = [ config.browser.desktop ];
        "x-scheme-handler/about" = [ config.browser.desktop ];
        "x-scheme-handler/unknown" = [ config.browser.desktop ];
        "inode/directory" = [ "yazi.desktop" ];
        "model/step" = [ "org.freecad.FreeCAD.desktop" ];
        "application/x-vtk" = [ "org.paraview.ParaView.desktop" ];
        "application/x-gmsh-msh" = [ "org.paraview.ParaView.desktop" ];
        "application/x-paraview-vtu" = [ "org.paraview.ParaView.desktop" ];
        "application/x-paraview-vtm" = [ "org.paraview.ParaView.desktop" ];
      };
    };
  };
}
