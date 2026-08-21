# Terminal abstraction — provides term path, package, exec helpers.
# Consumed by hyprland, otter, showoff, tui, waybar via config.terminal.*
{ self, ... }: {
  flake.modules.homeManager.optionsTerminal = { lib, ... }: {
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
  };
}
