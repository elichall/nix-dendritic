# ==========================================================================
# TUI APP LAUNCHER (desktop entries + icons + binaries)
# ==========================================================================
# wlctl provisioning (flake input): package-provisioning skill. Assets path
# resolution: modules/_assets/documentation/module-contracts.md (C13). Isolated here rather
# than main because TUI apps are launcher targets, not core system programs.
# ==========================================================================
{ inputs, ... }: {
  flake.modules.homeManager.tui =
    { config, pkgs, terminalName, ... }:
    let
      wlctl = inputs.wlctl.packages.${pkgs.stdenv.hostPlatform.system}.default;
      terminal = import ../_lib/terminal.nix { inherit pkgs terminalName; };
      isNoctalia = config.programs.noctalia.enable;

      # Core TUI apps (always included)
      coreTuiApps = [
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
      ];

      # TUI apps replaced by Noctalia widgets (excluded when noctalia is active)
      noctaliaReplacedApps = [
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

      tuiApps = coreTuiApps ++ (if isNoctalia then [ ] else noctaliaReplacedApps);

      mkTuiOpen = app: pkgs.writeShellScriptBin "${app.name}-open" (terminal.exec "bash -ci ${app.name}");

      tuiOpenWrappers = map mkTuiOpen tuiApps;

      # Auto-discover icon files in ../_assets/aesthetics/icons/
      availableIcons = builtins.readDir ../_assets/aesthetics/icons;
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
          cp ${../_assets/aesthetics/icons + "/${file}"} $out/share/icons/hicolor/${dir}/apps/${file}
        '';

      tuiIconPackages = map mkTuiIcon iconFiles;

      # Noctalia-specific desktop entries (only when noctalia is active)
      noctaliaDesktopEntries = if isNoctalia then {
        noctalia-settings = {
          name = "Noctalia Settings";
          exec = "noctalia msg settings-toggle";
          terminal = false;
          categories = [
            "Settings"
            "System"
          ];
          icon = "noctalia-settings";
        };
        noctalia-control-center = {
          name = "Noctalia Control Center";
          exec = "noctalia msg panel-toggle control-center";
          terminal = false;
          categories = [
            "Settings"
            "System"
          ];
          icon = "noctalia-control-center";
        };
      } else { };
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
        }
        // noctaliaDesktopEntries;

      home.packages =
        terminal.packages
        ++ (with pkgs; [
          # TUI app binaries (previously in nixos.main systemPackages / main)
          btop
          gdu

          # Launcher deps for the *-open wrappers (AGENTS.md Rule 4)
          yazi

          # commandline alias for terminal file manager
          (writeShellScriptBin "yazi-open" ''${terminal.term} -e bash -ci "yazi ''${1:-.}"'')
        ])
        ++ (if isNoctalia then [ ] else (with pkgs; [
          bluetui
          jolt-tui
          wlctl
        ]))
        ++ tuiOpenWrappers
        ++ tuiIconPackages;
    };
}
