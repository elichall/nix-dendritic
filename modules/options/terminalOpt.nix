# Terminal abstraction — provides term path, package, exec helpers.
# Consumed by hyprland, otter, showoff, tui, waybar via config.terminal.*
# Hosts override terminal.name; all derived values cascade automatically.
{ lib, ... }: {
  flake.modules.homeManager.terminal = { config, pkgs, ... }: {
    options.terminal = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "foot";
      };
      term = lib.mkOption {
        type = lib.types.str;
        default = lib.getExe pkgs.${config.terminal.name};
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.${config.terminal.name};
      };
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ pkgs.${config.terminal.name} ];
      };
      exec = lib.mkOption {
        type = lib.types.functionTo lib.types.str;
        default = cmd: "${config.terminal.term} -e ${cmd}";
      };
      execClass = lib.mkOption {
        type = lib.types.functionTo (lib.types.functionTo lib.types.str);
        default =
          class: cmd:
          if config.terminal.name == "foot" then
            "${config.terminal.term} --app-id=${class} -e ${cmd}"
          else
            "${config.terminal.term} --class=${class} -e ${cmd}";
      };
    };
  };
}
