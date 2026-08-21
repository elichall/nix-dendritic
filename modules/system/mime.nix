# ==========================================================================
# MIME TYPES & DEFAULT APPLICATIONS
# ==========================================================================
# Registry map + yazi.desktop contract: modules/_assets/documentation/module-contracts.md
# (C4). Lives in system/ because it is system-scale XDG integration.
# Default application associations moved to HM (modules/programs/mimeDefaults.nix).
# ==========================================================================
{ inputs, ... }: {
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
}
