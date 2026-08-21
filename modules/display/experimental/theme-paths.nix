# ==========================================================================
# THEME PATHS — single source of truth for theme-engine directories
# ==========================================================================
# Path indirection architecture: modules/_assets/documentation/module-contracts.md (C2).
# These paths are consumed by ghostty, theme, and otter via config.theme.*.
{ lib, ... }: {
  flake.modules.homeManager.themePaths = { config, ... }: {
    options.theme = {
      dir = lib.mkOption {
        type = lib.types.str;
      };
      active = lib.mkOption {
        type = lib.types.str;
      };
      generated = lib.mkOption {
        type = lib.types.str;
      };
      ghosttyThemeConf = lib.mkOption {
        type = lib.types.str;
      };
    };

    config.theme = {
      dir = "${config.home.homeDirectory}/.local/share/theme";
      active = "${config.home.homeDirectory}/.local/share/theme/active.json";
      generated = "${config.home.homeDirectory}/.local/share/theme/generated";
      ghosttyThemeConf = "${config.home.homeDirectory}/.local/share/theme/generated/ghostty/theme.conf";
    };
  };
}
