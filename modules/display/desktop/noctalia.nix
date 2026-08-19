{ inputs, ... }: {
  flake.modules.homeManager.noctalia = { pkgs, ... }: {
    programs.noctalia = {
      enable = true;
      settings = {
        theme = {
          mode = "dark";
          source = "builtin";
          builtin = "Catppuccin";
        };
        bar.default = {
          position = "top";
        };
        dock = {
          enabled = false;
        };
        wallpaper = {
          directory = "/home/elichall/.nix/modules/_assets/aesthetics/wallpapers";
          enabled = true;
          fill_mode = "crop";
          fill_color = "#111111";
        };
        shell = {
          clipboard_enabled = true;
          clipboard_history_max_entries = 20;
          clipboard_auto_paste = "auto";
          setup_wizard_enabled = false;
        };
        accessibility = {
          ui_scale = 1.0;
          high_contrast = false;
        };
      };
    };
  };
}
