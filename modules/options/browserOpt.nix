# Browser abstraction — provides appId, command, desktop.
# Consumed by hyprland (keybind), mime (defaultApplications), otter (tokens).
# Hosts override browser.appId/desktop when divergent from defaults.
{ lib, ... }: {
  flake.modules.homeManager.browser = { lib, ... }: {
    options.browser = {
      appId = lib.mkOption {
        type = lib.types.str;
        default = "org.mozilla.firefox";
      };
      command = lib.mkOption {
        type = lib.types.str;
        default = "flatpak run org.mozilla.firefox";
      };
      desktop = lib.mkOption {
        type = lib.types.str;
        default = "org.mozilla.firefox.desktop";
      };
    };
  };
}
