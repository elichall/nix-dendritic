{ ... }: {
  flake.modules.homeManager.foot = {
    programs.foot = {
      enable = true;
      settings = {
        main = {
          term = "xterm-256color";
          font = "JetBrainsMono Nerd Font:size=7.5";
          dpi-aware = "yes";
          pad = "8x8";
        };
        cursor = {
          blink = "yes";
        };
        mouse = {
          "hide-when-typing" = "yes";
        };
        colors-dark = {
          alpha = 0.7;
          blur = true;
          background = "1E1E2E";
          foreground = "CDD6F4";
          cursor = "1E1E2E CDD6F4";
          regular0 = "45475A";
          regular1 = "F38BA8";
          regular2 = "A6E3A1";
          regular3 = "F9E2AF";
          regular4 = "89B4FA";
          regular5 = "F5C2E7";
          regular6 = "94E2D5";
          regular7 = "BAC2DE";
          bright0 = "585B70";
          bright1 = "F38BA8";
          bright2 = "A6E3A1";
          bright3 = "F9E2AF";
          bright4 = "89B4FA";
          bright5 = "F5C2E7";
          bright6 = "94E2D5";
          bright7 = "A6ADC8";
        };
        scrollback = {
          lines = "10000";
        };
      };
    };
  };
}
