# Browser abstraction — provides appId, command, desktop.
# Consumed by mime, hyprland via config.browser.*
{ self, ... }: {
  flake.modules.homeManager.optionsBrowser = { lib, ... }: {
    options.browser = {
      appId = lib.mkOption {
        type = lib.types.str;
      };
      command = lib.mkOption {
        type = lib.types.str;
      };
      desktop = lib.mkOption {
        type = lib.types.str;
      };
    };
  };
}
