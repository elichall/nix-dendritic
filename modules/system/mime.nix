# ==========================================================================
# MIME TYPES & DEFAULT APPLICATIONS
# ==========================================================================
# Registry map + yazi.desktop contract: modules/_assets/documentation/module-contracts.md
# (C4). Lives in system/ because it is system-scale XDG integration.
# ==========================================================================
{ inputs, ... }: {
  flake.modules.nixos.mime = { pkgs, lib, ... }:
  let
    browserDesktop = (import ../_lib/browser.nix).desktop;

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

    # CONTRACT: the yazi.desktop target is defined in homeManager.tui
    # (modules/display/tui.nix) with mimeType = [ "inode/directory" ].
    # Keep the desktop ID below in sync with that entry.
    xdg.mime.defaultApplications = {
      "text/html" = browserDesktop;
      "model/step" = "org.freecad.FreeCAD.desktop";
      "application/x-vtk" = "org.paraview.ParaView.desktop";
      "application/x-gmsh-msh" = "org.paraview.ParaView.desktop";
      "application/x-paraview-vtu" = "org.paraview.ParaView.desktop";
      "application/x-paraview-vtm" = "org.paraview.ParaView.desktop";
      "x-scheme-handler/http" = browserDesktop;
      "x-scheme-handler/https" = browserDesktop;
      "x-scheme-handler/about" = browserDesktop;
      "x-scheme-handler/unknown" = browserDesktop;
      "inode/directory" = "yazi.desktop";
    };
  };
}
