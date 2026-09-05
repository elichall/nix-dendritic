# ==========================================================================
# YAZI FILE MANAGER
# ==========================================================================
# Yank/cut state is persistent and synchronized across yazi instances via the
# built-in session plugin (see init.lua below): a yank survives quitting yazi
# and cut stays move-aware in every running instance. Restart all yazi
# instances to pick up changes.
{ inputs, ... }: {
  flake.modules.homeManager.yazi = { pkgs, ... }: {
    home.sessionVariables = {
      FILEMANAGER = "yazi";
      TERM_FILE_CHOOSER = "yazi";
    };

    # ripdrag: Wayland drag-and-drop daemon invoked by the <C-d> keymap below
    home.packages = [ pkgs.ripdrag ];

    programs.yazi = {
      enable = true;
      enableBashIntegration = true;

      settings = {
        manager = {
          show_hidden = true;
          sort_by = "natural";
        };

        open = {
          prepend_rules = [
            {
              url = "*.{step,stp,iges,igs,stl,obj,scad,geo,dxf,ifc,vtk,msh,vtu,vtm,vts,vtr,vtp,bdf,inp,k,key,plt,unv,xdmf,xf,sch,kicad_pcb}";
              use = "open";
            }
          ];
        };
      };

      theme = {
        icon = {
          # yazi >= 26.x icon schema: prepend_dirs / prepend_files keyed by
          # exact name (no trailing slash); prepend_rules was removed silently.
          prepend_dirs = [
            {
              name = "Projects";
              text = "";
            }
            {
              name = "foot";
              text = "󰽒";
            }
            {
              name = "git";
              text = "";
              fg = "#F05033";
            }
            {
              name = "gtk-3.0";
              text = "";
              fg = "#3584E4";
            }
            {
              name = "gtk-4.0";
              text = "";
              fg = "#3584E4";
            }
            {
              name = ".cache";
              text = "";
              fg = "#D08770";
            }
            {
              name = ".ssh";
              text = "";
              fg = "#DCA561";
            }
            {
              name = ".local";
              text = "󱂵";
              fg = "#6DB9F7";
            }
            {
              name = "noctalia";
              text = "󰏒";
            }
            {
              name = "Box";
              text = "󰍲";
              fg = "#F25022";
            }
            {
              name = ".nix";
              text = "";
              fg = "#7ebae4";
            }
            {
              name = ".nix-defexpr";
              text = "";
              fg = "#7ebae4";
            }
            {
              name = ".nix-profile";
              text = "";
              fg = "#7ebae4";
            }
            {
              name = "nix";
              text = "";
              fg = "#7ebae4";
            }
            {
              name = "home-manager";
              text = "";
              fg = "#7ebae4";
            }
            {
              name = "wallpapers";
              text = "󰸉";
            }
            {
              name = ".var";
              text = "";
              fg = "#4A86CF";
            }
            {
              name = "vault";
              text = "";
              fg = "#A882FF";
            }
            {
              name = "hypr";
              text = "";
              fg = "#BD2426";
            }
            {
              name = "pulse";
              text = "";
              fg = "#F07C5B";
            }
            {
              name = "ghostty";
              text = "󰊠";
              fg = "#A78BFA";
            }
            {
              name = "otter-launcher";
              text = "";
            }
            {
              name = "nvim";
              text = "";
              fg = "#57A143";
            }
            {
              name = "tmux";
              text = "";
              fg = "#1BB91F";
            }
            {
              name = "yazi";
              text = "󰇥";
              fg = "#E5C07B";
            }
            {
              name = "claude";
              text = "";
              fg = "#D97757";
            }
            {
              name = "systemd";
              text = "";
              fg = "#30D475";
            }
            {
              name = "opencode";
              text = "";
              fg = "#D99C57";
            }
          ];
          prepend_files = [
            {
              name = "hyprland.conf";
              text = "";
              fg = "#BD2426";
            }
            {
              name = "hyprland.lua";
              text = "";
              fg = "#BD2426";
            }
            {
              name = "foot.ini";
              text = "󰽒";
            }
            {
              name = "noctalia*";
              text = "󰏒";
            }
            {
              name = "flake.nix";
              text = "";
              fg = "#7ebae4";
            }
          ];
        };
      };
    };

    xdg.configFile."yazi/keymap.toml" = {
      force = true;
      text = ''
        [[mgr.prepend_keymap]]
        on = "<C-d>"
        run = "shell 'ripdrag %s -A -x -i -W 200 -H 60 2>/dev/null &' --confirm"
        desc = "Drag and drop"

        [[mgr.prepend_keymap]]
        on = "y"
        run = [ "yank", "copy path" ]
        desc = "Yank and copy path to system clipboard"

        [[mgr.prepend_keymap]]
        on = "x"
        run = [ "yank --cut", "copy path" ]
        desc = "Cut and copy path to system clipboard"

        [[mgr.prepend_keymap]]
        on = "p"
        run = "paste"
        desc = "Paste the yanked files"

        [[mgr.prepend_keymap]]
        on = [ "c", "y" ]
        run = [ "yank", "shell 'for path in %s; do echo file://$path; done | wl-copy -t text/uri-list'" ]
        desc = "Yank and copy URI list to system clipboard (GUI paste)"

        [[mgr.prepend_keymap]]
        on = [ "c", "x" ]
        run = [ "yank --cut", "shell 'for path in %s; do echo file://$path; done | wl-copy -t text/uri-list'" ]
        desc = "Cut and copy URI list to system clipboard (GUI paste)"
      '';
    };

    xdg.configFile."yazi/init.lua" = {
      force = true;
      text = ''
        require("session"):setup {
          sync_yanked = true,
        }
      '';
    };
  };
}
