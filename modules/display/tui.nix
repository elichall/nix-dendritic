# ==========================================================================
# TUI APP LAUNCHER (desktop entries + icons + binaries)
# ==========================================================================
# Isolated here rather than in nixos.main/homeManager.main because the TUI
# apps are launcher targets surfaced by the desktop (waybar/app launcher),
# not core system programs. Everything is user-scale (Home Manager).
#
# wlctl is provisioned as a flake input (see flake.nix) per the order of
# package operations (skill: package-provisioning): not in nixpkgs, but the
# upstream repo ships a flake exposing packages.<system>.default.
#
# Note on assets paths: path literals resolve relative to THIS file's
# directory, so the tracked icons live at ../_assets/icons (from modules/display/).
{ inputs, ... }: {
  flake.modules.homeManager.tui =
    { pkgs, ... }:
    let
      wlctl = inputs.wlctl.packages.${pkgs.stdenv.hostPlatform.system}.default;

      tuiApps = [
        {
          name = "btop";
          description = "System Monitor";
          categories = [
            "System"
            "Monitor"
          ];
        }
        {
          name = "gdu";
          description = "Disk Analyzer";
          categories = [
            "System"
            "FileTools"
          ];
        }
        {
          name = "wlctl";
          description = "Wi-Fi Manager";
          categories = [
            "Network"
            "Utility"
          ];
        }
        {
          name = "bluetui";
          description = "Bluetooth Manager";
          categories = [
            "Network"
            "Utility"
          ];
        }
        {
          name = "jolt";
          description = "Battery Monitor";
          categories = [
            "System"
            "Utility"
          ];
        }
      ];

      mkTuiOpen = app: pkgs.writeShellScriptBin "${app.name}-open" "ghostty -e bash -ci ${app.name}";

      tuiOpenWrappers = map mkTuiOpen tuiApps;

      # Auto-discover icon files in ../_assets/icons/
      availableIcons = builtins.readDir ../_assets/icons;
      iconFiles = builtins.filter (f: availableIcons.${f} == "regular") (
        builtins.attrNames availableIcons
      );

      mkTuiIcon =
        file:
        let
          isSvg = builtins.match ".*\\.svg" file != null;
          dir = if isSvg then "scalable" else "48x48";
        in
        pkgs.runCommandLocal "icon-${file}" { } ''
          mkdir -p $out/share/icons/hicolor/${dir}/apps
          cp ${../_assets/icons + "/${file}"} $out/share/icons/hicolor/${dir}/apps/${file}
        '';

      tuiIconPackages = map mkTuiIcon iconFiles;
    in
    {
      xdg.desktopEntries =
        builtins.listToAttrs (
          map (app: {
            name = app.name;
            value = {
              name = app.description;
              exec = "${app.name}-open";
              terminal = false;
              categories = app.categories or [ "Utility" ];
              icon = app.name;
            };
          }) tuiApps
        )
        // {
          yazi = {
            name = "Yazi";
            exec = "yazi-open %f";
            terminal = false;
            mimeType = [ "inode/directory" ];
            icon = "yazi";
          };
        };

      home.packages =
        with pkgs;
        [
          # TUI app binaries (previously in nixos.main systemPackages / main)
          btop
          gdu
          bluetui
          jolt-tui

          # Launcher deps for the *-open wrappers (AGENTS.md Rule 4)
          ghostty
          yazi

          # Non-nixpkgs packages (flake imported)
          wlctl

          # commandline alias for terminal file manager
          (writeShellScriptBin "yazi-open" ''ghostty -e bash -ci "yazi ''${1:-.}"'')
        ]
        ++ tuiOpenWrappers
        ++ tuiIconPackages;
    };
}
