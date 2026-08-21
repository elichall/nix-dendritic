# Terminal abstraction — provides term path, package, exec helpers.
# Consumed by hyprland, otter, showoff, tui, waybar via config.terminal.*
# Merged pattern: declares options AND sets config values (like theme-paths.nix).
{ self, ... }: {
  flake.modules.homeManager.terminal = { config, pkgs, lib, terminalName, ... }: {
    options.terminal = {
      name = lib.mkOption {
        type = lib.types.str;
      };
      term = lib.mkOption {
        type = lib.types.str;
      };
      package = lib.mkOption {
        type = lib.types.package;
      };
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
      };
      exec = lib.mkOption {
        type = lib.types.functionTo lib.types.str;
      };
      execClass = lib.mkOption {
        type = lib.types.functionTo (lib.types.functionTo lib.types.str);
      };
    };

    config.terminal = {
      name = terminalName;
      term = "${pkgs.${terminalName}}/bin/${terminalName}";
      package = pkgs.${terminalName};
      packages = [ pkgs.${terminalName} ];
      exec = cmd: "${config.terminal.term} -e ${cmd}";
      execClass =
        class: cmd:
        if terminalName == "foot" then
          "${config.terminal.term} --app-id=${class} -e ${cmd}"
        else
          "${config.terminal.term} --class=${class} -e ${cmd}";
    };
  };
}
