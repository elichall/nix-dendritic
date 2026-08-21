# ==========================================================================
# MIME TYPES & DEFAULT APPLICATIONS
# ==========================================================================
# Registry map + yazi.desktop contract: modules/_assets/documentation/module-contracts.md
# (C4). System-scale XDG MIME registration (NixOS) + user default applications (HM).
# ==========================================================================
{ ... }: {
  flake.modules.nixos.mime = { pkgs, lib, ... }:
  let
    engineeringMimes = {
      "model/step" = { comment = "STEP 3D model"; globs = [ "*.step" "*.stp" ]; };
      "application/x-vtk" = { comment = "VTK data file"; globs = [ "*.vtk" ]; };
      "application/x-gmsh-msh" = { comment = "Gmsh mesh file"; globs = [ "*.msh" ]; };
      "application/x-paraview-vtu" = { comment = "ParaView VTU file"; globs = [ "*.vtu" ]; };
      "application/x-paraview-vtm" = { comment = "ParaView VTM file"; globs = [ "*.vtm" ]; };
    };

    mimeXml = pkgs.writeText "custom-mime.xml" (
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
      + "<mime-info xmlns=\"http://www.freedesktop.org/standards/shared-mime-info\">\n"
      + lib.concatStringsSep "\n" (lib.mapAttrsToList (mime: { comment, globs }:
        "<mime-type type=\"${mime}\">\n"
        + "<comment>${comment}</comment>\n"
        + lib.concatMapStrings (g: "<glob pattern=\"${g}\"/>\n") globs
        + "</mime-type>"
      ) engineeringMimes)
      + "</mime-info>\n"
    );

    customMime = pkgs.runCommandLocal "custom-mime" { } ''
      mkdir -p $out/share/mime/packages
      cp ${mimeXml} $out/share/mime/packages/custom-mime.xml
    '';
  in
  {
    environment.systemPackages = [ customMime ];
  };

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
