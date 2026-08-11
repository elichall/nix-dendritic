{ config, pkgs, ... }:

let
  # use ootter-launcher's flake once I change to flake dendritic confiuration
  otter-launcher-src = builtins.fetchTarball {
    url = "https://github.com/kuokuo123/otter-launcher/archive/refs/tags/v0.7.6.tar.gz";
    sha256 = "0h9ywf40h0g8isd8b1g2gbkbwl9z5q2cd8hpp75dacs4fg6rdvb4";
  };

  otter-launcher = pkgs.rustPlatform.buildRustPackage {
    pname = "otter-launcher";
    version = "0.7.6";
    src = otter-launcher-src;
    cargoLock.lockFile = "${otter-launcher-src}/Cargo.lock";
    meta = with pkgs.lib; {
      description = "Minimal terminal-native launcher";
      homepage = "https://github.com/kuokuo123/otter-launcher";
      license = licenses.gpl3Only;
      mainProgram = "otter-launcher";
      platforms = platforms.linux;
    };
  };

  # config.toml is a template: the injectable lines use @TOKEN@ placeholders.
  # mkOtterConfig substitutes them, so each menu variant (app, pow, ...) is
  # just an attrset of values. Add a token in config.toml + a field here.
  mkOtterConfig =
    overrides:
    let
      tokens = builtins.attrNames overrides;
    in
    pkgs.writeText "otter-launcher.toml" (
      builtins.replaceStrings (builtins.map (token: "@${token}@") tokens) (builtins.map (
        token: overrides.${token}
      ) tokens) (builtins.readFile ./config.toml)
    );

  appConfig = mkOtterConfig {
    DEFAULT_MODULE = "app";
    EMPTY_MODULE = "app";
    DEFAULT_MODULE_MESSAGE = "  └ \\u001B[34m  \\u001B[33mapp \\u001B[0m launch apps";
    EMPTY_MODULE_MESSAGE = "  └ \\u001B[34m  \\u001B[33mapp \\u001B[0m launch apps";
  };

  powConfig = mkOtterConfig {
    DEFAULT_MODULE = "pow";
    EMPTY_MODULE = "pow";
    DEFAULT_MODULE_MESSAGE = "  └ \\u001B[34m  \\u001B[33mpow \\u001B[0m power menu";
    EMPTY_MODULE_MESSAGE = "  └ \\u001B[34m  \\u001B[33mpow \\u001B[0m power menu";
  };

  otter-launch-inner = pkgs.writeShellApplication {
    name = "otter-launch-inner";
    runtimeInputs = [
      otter-launcher
      pkgs.coreutils
    ];
    text = ''
      if [ -n "''${1:-}" ]; then
        exec otter-launcher -c "$1"
      else
        exec otter-launcher
      fi
    '';
  };

  otter-launch = pkgs.writeShellApplication {
    name = "otter-launch";
    runtimeInputs = [
      pkgs.procps
      pkgs.coreutils
    ];
    text = ''
      CONFIG="''${1:-}"
      if pgrep -f "/bin/otter-launcher" >/dev/null 2>&1; then
        # Toggle-close: kill the launcher process. Its window closes naturally;
        # the cold-fallback ghostty instance quits, the server (if running) stays.
        pkill -f "/bin/otter-launcher" >/dev/null 2>&1 || true
      else
        # Fast path: hand off to the persistent com.otter.launcher instance
        # (ghostty --gtk-single-instance server started at login). Falls back
        # to a cold spawn if the server is not running.
        if ghostty +new-window --class=com.otter.launcher -e ${otter-launch-inner}/bin/otter-launch-inner ''${CONFIG:+"$CONFIG"} >/dev/null 2>&1; then
          :
        else
          ghostty --class=com.otter.launcher -e ${otter-launch-inner}/bin/otter-launch-inner ''${CONFIG:+"$CONFIG"} &
        fi
        dismiss-on-pointer
      fi
    '';
  };

  otter-open = pkgs.writeShellScriptBin "otter-open" ''
    exec otter-launch
  '';

  otter-power = pkgs.writeShellScriptBin "otter-power" ''
    exec otter-launch ${powConfig}
  '';

  dismiss-on-pointer = pkgs.writeShellApplication {
    name = "dismiss-on-pointer";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.procps
      pkgs.coreutils
    ];
    text = builtins.readFile ./dismiss-on-pointer.sh;
  };

  app-launcher = pkgs.writeShellScriptBin "otter-apps" (builtins.readFile ./app-launcher.sh);
in
{
  home.packages = [
    otter-launcher
    otter-open
    otter-power
    otter-launch
    otter-launch-inner
    dismiss-on-pointer
    app-launcher
  ];

  xdg.configFile."otter-launcher/config.toml" = {
    force = true;
    source = appConfig;
  };
}
