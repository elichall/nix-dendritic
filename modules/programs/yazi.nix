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
          prepend_rules = [
            { name = "Projects/";   text = "  "; fg = "#E5C07B"; }
            { name = "Box/";        text = "  󰍲"; fg = "#61AFEF"; }
            { name = ".nix/";       text = "  󱄅"; fg = "#7CA982"; }
            { name = "wallpapers/"; text = "  󰸉"; fg = "#C678DD"; }
            { name = ".var/";       text = "  "; fg = "#98C379"; }
            { name = "vault/";      text = "  "; fg = "#56B6C2"; }
            { name = "hyprland/";       text = "  "; }
            { name = "hyprland.conf";   text = "  "; }
            { name = "hyprland.lua";    text = "  "; }
            { name = "ghostty/";        text = "  󰊠"; }
            { name = "otter-launcher/"; text = "  "; }
            { name = "nvim/";           text = "  "; }
            { name = "tmux/";           text = "  "; }
            { name = "yazi/";           text = "  󰇥"; }
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
