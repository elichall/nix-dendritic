# ==========================================================================
# YAZI FILE MANAGER
# ==========================================================================
# Yank/cut state is persistent and synchronized across yazi instances via the
# built-in session plugin (see init.lua below): a yank survives quitting yazi
# and cut stays move-aware in every running instance. Restart all yazi
# instances to pick up changes.
{ inputs, ... }: {
  flake.modules.homeManager.yazi = { ... }: {
    home.sessionVariables = {
      FILEMANAGER = "yazi";
      TERM_FILE_CHOOSER = "yazi";
    };

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
