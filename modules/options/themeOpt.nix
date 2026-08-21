# Theme path declarations — consumed by ghostty, theme, otter via config.theme.*
# Set by display/experimental/theme.nix (which creates the switch CLI + derivations).
{ lib, ... }: {
  flake.modules.homeManager.optionsTheme = { config, ... }: {
    options.theme = {
      dir = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/.local/share/theme";
      };
      active = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/.local/share/theme/active.json";
      };
      generated = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/.local/share/theme/generated";
      };
      ghosttyThemeConf = lib.mkOption {
        type = lib.types.str;
        default = "${config.theme.generated}/ghostty/theme.conf";
      };
    };
  };
}
