{ config, pkgs, ... }:
let
  wlctl-src = builtins.fetchTarball {
    url = "https://github.com/aashish-thapa/wlctl/archive/refs/tags/v0.1.9.tar.gz";
    sha256 = "1lmc3r32qmsf85bhhhf9lqhqajkj02k9468q5bxandsnrkqjwd2z";
  };

  wlctl = pkgs.rustPlatform.buildRustPackage {
    pname = "wlctl";
    version = "0.1.9";
    src = wlctl-src;
    cargoLock.lockFile = "${wlctl-src}/Cargo.lock";
    meta = with pkgs.lib; {
      description = "TUI for managing WiFi via NetworkManager";
      homepage = "https://github.com/aashish-thapa/wlctl";
      license = licenses.gpl3Only;
      mainProgram = "wlctl";
      platforms = platforms.linux;
    };
  };

  tuiApps = [
    {
      name = "btop";
      description = "System Monitor";
      categories = [
        "System"
        "Monitor"
      ];
    }
    {
      name = "gdu";
      description = "Disk Analyzer";
      categories = [
        "System"
        "FileTools"
      ];
    }
    {
      name = "wlctl";
      description = "Wi-Fi Manager";
      categories = [
        "Network"
        "Utility"
      ];
    }
    {
      name = "bluetui";
      description = "Bluetooth Manager";
      categories = [
        "Network"
        "Utility"
      ];
    }
    {
      name = "jolt";
      description = "Battery Monitor";
      categories = [
        "System"
        "Utility"
      ];
    }
  ];

  mkTuiOpen = app: pkgs.writeShellScriptBin "${app.name}-open" "ghostty -e bash -ci ${app.name}";

  tuiOpenWrappers = map mkTuiOpen tuiApps;

  # Auto-discover icon files in assets/icons/
  availableIcons = builtins.readDir ./assets/icons;
  iconFiles = builtins.filter (f: availableIcons.${f} == "regular") (
    builtins.attrNames availableIcons
  );

  mkTuiIcon =
    file:
    let
      isSvg = builtins.match ".*\\.svg" file != null;
      dir = if isSvg then "scalable" else "48x48";
    in
    pkgs.runCommandLocal "icon-${file}" { } ''
      mkdir -p $out/share/icons/hicolor/${dir}/apps
      cp ${./assets/icons + "/${file}"} $out/share/icons/hicolor/${dir}/apps/${file}
    '';

  tuiIconPackages = map mkTuiIcon iconFiles;
in
{
  imports = [
    ./modules/hyprland.nix
    ./modules/desktop-stable.nix
    ./modules/theme.nix
    ./modules/showoff.nix
    ./modules/otter-launcher/otter.nix
  ];

  home.stateVersion = "26.05";

  home.username = "elichall";
  home.homeDirectory = "/home/elichall";

  # ==========================================================================
  # GLOBAL ENVIRONMENT CONFIGURATION
  # ==========================================================================
  home.sessionVariables = {
    EDITOR = "nvim";
    FILEMANAGER = "yazi";
    TERM_FILE_CHOOSER = "yazi";
    VISUAL = "nvim";
    SUDO_EDITOR = "nvim";
    XCOMPOSECACHE = "${config.home.homeDirectory}/.cache/compose-cache";
  };

  programs.git = {
    enable = true;
    settings.user.name = "elichall";
    settings.user.email = "1elijah.hall@gmail.com";
  };

  home.pointerCursor = {
    enable = true;
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
    dotIcons.enable = false; # disable legacy ~/.icons mirror; XDG ~/.local/share/icons suffices
  };

  # XDG portal + MIME defaults (defaultApplications now in modules/mime.nix)
  xdg = {
    enable = true;
    desktopEntries =
      builtins.listToAttrs (
        map (app: {
          name = app.name;
          value = {
            name = app.description;
            exec = "${app.name}-open";
            terminal = false;
            categories = app.categories or [ "Utility" ];
            icon = app.name;
          };
        }) tuiApps
      )
      // {
        yazi = {
          name = "Yazi";
          exec = "yazi-open %f";
          terminal = false;
          mimeType = [ "inode/directory" ];
          icon = "yazi";
        };
      };
    dataFile."applications/org.zotero.Zotero.desktop".text = ''
      [Desktop Entry]
      Name=Zotero
      Exec=flatpak run --branch=stable --arch=x86_64 --command=zotero --file-forwarding org.zotero.Zotero -profile /home/elichall/.var/app/org.zotero.Zotero/profile -url @@u %U @@
      Icon=org.zotero.Zotero
      Type=Application
      Terminal=false
      Categories=Office;Science
      MimeType=text/plain;x-scheme-handler/zotero;application/x-research-info-systems;text/x-research-info-systems;text/ris;application/x-endnote-refer;application/x-inst-for-Scientific-info;application/mods+xml;application/rdf+xml;application/x-bibtex;text/x-bibtex;application/marc;application/vnd.citationstyles.style+xml
      X-GNOME-SingleWindow=true
      Keywords=bibliography;biblatex;bibtex;citing;literature
    '';
  };

  # Packages managed by home-manager not by root
  home.packages =
    with pkgs;
    [
      # gtk.portal must live in the user profile so the daemon finds it
      xdg-desktop-portal-gtk
      ghostty
      bluetui
      jolt-tui
      libqalculate
      chafa

      # Global LSPs (always on PATH)
      nil # nix
      marksman # markdown
      lua-language-server # lua
      texlab # latex
      bash-language-server # bash

      # Showoff dashboard dependencies
      tty-clock
      gping
      cava
      cmatrix
      cbonsai
      asciiquarium-transparent
      sl
      lolcat
      cowsay
      weathr

      # Non-nixpkgs packages (built from source)
      wlctl

      # commandline aliases for terminal apps
      (writeShellScriptBin "yazi-open" ''ghostty -e bash -ci "yazi ''${1:-.}"'')
    ]
    ++ tuiOpenWrappers
    ++ tuiIconPackages;

  # ==========================================================================
  # PERSISTENT SYSTEM PLUGINS & UTILITIES
  # ==========================================================================
  programs.starship = {
    enable = true;
    enableBashIntegration = false; # ble.sh must load first

    settings = {
      format = "$os$directory$nix_shell$git_branch$git_status$character";
      add_newline = false;
      line_break.disabled = true;
      cmd_duration.disabled = true;

      os = {
        disabled = false;
        format = "[$symbol]($style) ";
        style = "bold #74c7ec";
        symbols.NixOS = "";
      };

      nix_shell = {
        symbol = "󰜗 ";
        format = "via [$symbol$state](bold blue) ";
        pure_msg = "pure";
        impure_msg = "";
        unknown_msg = "";
        heuristic = false;
        disabled = false;
      };
    };
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = false; # handled manually in programs.bash.initExtra
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = false; # readline binds are inert under ble.sh
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = false;
    nix-direnv.enable = true;
    silent = true;
    stdlib = ''
      # Load nix-direnv stdlib (provides use_nix, use flake)
      source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
      # Load user lib/*.sh (direnv does not auto-load these)
      direnv_config_dir_home="''${DIRENV_CONFIG_HOME:-''${XDG_CONFIG_HOME:-$HOME/.config}/direnv}"
      for lib in "$direnv_config_dir_home/lib/"*.sh; do
        source "$lib"
      done
      unset direnv_config_dir_home
    '';
  };

  # ==========================================================================
  # DECLARATIVE DOTFILE GENERATION
  # ==========================================================================
  home.file.".blerc".text = ''
    ble-face -s filename_directory 'fg=blue'
    ble-face -s filename_other fg=white,nounderline

    function blerc/emacs-load-hook {
      ble-bind -f 'C-a' accept-line
      return 0
    }
    blehook/eval-after-load keymap_emacs blerc/emacs-load-hook
  '';

  # ==========================================================================
  # INTERACTIVE BASH MANAGEMENT
  # ==========================================================================
  programs.bash = {
    enable = true;

    historyControl = [ "ignoreboth" ];
    historySize = 1000;
    historyFileSize = 2000;

    shellAliases = {
      ll = "ls -alF --color=auto";
      la = "ls -A --color=auto";
      l = "ls -CF --color=auto";
      grep = "grep --color=auto";
      snorbs = "sudo nixos-rebuild switch";
      gdu = "gdu --no-cross";
    };

    bashrcExtra = ''
      if [ -f ~/.nix-profile/etc/profile.d/hm-session-vars.sh ]; then
        . ~/.nix-profile/etc/profile.d/hm-session-vars.sh
      fi
    '';

    initExtra = ''
      shopt -s histappend
      shopt -s checkwinsize
      # Initialize blesh first
      if [[ $- == *i* ]]; then
        source ${pkgs.blesh}/share/blesh/ble.sh --noattach
      fi
      # Initialize zoxide
      eval "$(${pkgs.zoxide}/bin/zoxide init bash)"
      # Initialize direnv (defines the _direnv_hook function)
      eval "$(${pkgs.direnv}/bin/direnv hook bash)"
      # ble.sh runs PRECMD hooks before PROMPT_COMMAND on every prompt, so we
      # register direnv via blehook PRECMD to ensure it updates the environment
      # before starship draws its prompt. Strip the redundant PROMPT_COMMAND
      # registration so direnv is not evaluated twice per prompt.
      if [[ ''${BLE_VERSION-} && -t 0 ]]; then
        PROMPT_COMMAND="''${PROMPT_COMMAND//_direnv_hook;}"
        PROMPT_COMMAND="''${PROMPT_COMMAND#_direnv_hook}"
        blehook PRECMD!='_direnv_hook'
      fi
      # Initialize starship (auto-detects ble.sh and hooks into blehook PRECMD)
      if [[ $- == *i* ]]; then
        eval "$(${pkgs.starship}/bin/starship init bash --print-full-init)"
      fi
      # Attach blesh
      [[ ''${BLE_VERSION-} ]] && ble-attach
    '';
  };

  # ==========================================================================
  # TMUX HOME MANAGEMENT
  # ==========================================================================
  programs.tmux = {
    enable = true;
    shortcut = "Space";
    baseIndex = 1;
    keyMode = "vi";
    escapeTime = 0;
    mouse = true;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      vim-tmux-navigator
      {
        plugin = extrakto;
        extraConfig = ''
          set -g @extrakto_key "f"
          set -g @extrakto_filter_order "line word all"
        '';
      }
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-processes "opencode"
          set -g @resurrect-dir '~/.local/share/tmux/resurrect'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval 10
        '';
      }
      {
        plugin = tmux-fzf;
        extraConfig = ''
          TMUX_FZF_LAUNCH_KEY="tab"
        '';
      }
      {
        plugin = yank;
      }
    ];

    extraConfig = ''
      set -g default-terminal "tmux-256color"
      set -ag terminal-overrides ",xterm-256color:RGB"
      set-option -g detach-on-destroy off

      set -g pane-base-index 1
      set-window-option -g pane-base-index 1
      set-option -g renumber-windows on

      if-shell '[ -f ~/.config/tmux/colors.tmux ]' 'source-file ~/.config/tmux/colors.tmux'

      unbind [
      bind v copy-mode
      set-window-option -g mode-keys vi
      bind-key -T copy-mode-vi v send-key -X begin-selection
      bind-key -T copy-mode-vi C-v send-key -X rectangle-toggle
      bind-key -T copy-mode-vi y send-key -X copy-selection-and-cancel
      bind-key -T copy-mode-vi Escape send-key -X cancel

      bind p run "wl-paste -n | tmux load-buffer - ; tmux paste-buffer"

      # Pane management
      unbind '"'
      unbind %
      bind | split-window -h -c "#{pane_current_path}"
      bind _ split-window -v -c "#{pane_current_path}"
      bind b break-pane -d

      bind -r Left resize-pane -L 10
      bind -r Down resize-pane -D 10
      bind -r Up resize-pane -U 10
      bind -r Right resize-pane -R 10

      bind C-x confirm-before -p "Kill all other panes in window? (y/n)" "kill-pane -a"

      # Window management
      bind n new-window -c "#{pane_current_path}"
      bind -n M-h previous-window
      bind -n M-l next-window
      bind X confirm-before -p "Kill current window? (y/n)" kill-window

      # Session management
      bind N run-shell -b "${pkgs.tmuxPlugins.tmux-fzf}/share/tmux-plugins/tmux-fzf/scripts/session.sh new"
      bind S run-shell "${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/scripts/save.sh"
      bind s run-shell "${pkgs.tmuxPlugins.tmux-fzf}/share/tmux-plugins/tmux-fzf/scripts/session.sh"

      bind -n M-C-h switch-client -p
      bind -n M-C-l switch-client -n

      bind C-X confirm-before -p "Kill current session? (y/n)" "run-shell 'tmux has-session -t main 2>/dev/null || tmux new-session -d -s main; tmux switch-client -t main && tmux kill-session -t \"#{session_name}\"'"
      bind M-C-X confirm-before -p "Clear all sessions except main? (y/n)" "run-shell 'tmux has-session -t main 2>/dev/null || tmux new-session -d -s main; tmux list-sessions -F \"##S\" | grep -v \"^main$\" | xargs -I {} tmux kill-session -t {}'"
    '';
  };

  # ==========================================================================
  # YAZI FILE MANAGER CONFIGURATION
  # ==========================================================================
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

  # Yank/cut state is persistent and synchronized across yazi instances via the
  # built-in session plugin (see init.lua below): a yank survives quitting yazi
  # and cut stays move-aware in every running instance. Restart all yazi
  # instances to pick up changes.
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

  # ==========================================================================
  # SYSTEMD USER SERVICES
  # ==========================================================================
  systemd.user.services.awww-daemon = {
    Unit = {
      Description = "Awww Wallpaper Management Daemon Engine";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.awww}/bin/awww-daemon";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.waypaper-restore = {
    Unit = {
      Description = "Waypaper Post-Initialization Wallpaper Restoration";
      Requires = [ "awww-daemon.service" ];
      After = [
        "awww-daemon.service"
        "graphical-session.target"
      ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 0.5";
      ExecStart = "${pkgs.waypaper}/bin/waypaper --restore";
      RemainAfterExit = true;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.rclone-box = {
    Unit = {
      Description = "Rclone Box Drive Mount Service";
      AssertPathExists = "${config.home.homeDirectory}/.config/rclone/rclone.conf";
    };
    Service = {
      Type = "notify";
      ExecStartPre = "-${pkgs.coreutils}/bin/mkdir -p ${config.home.homeDirectory}/Box";

      ExecStart = "${pkgs.rclone}/bin/rclone mount boxdrive: ${config.home.homeDirectory}/Box --config=${config.home.homeDirectory}/.config/rclone/rclone.conf --vfs-cache-mode full --vfs-cache-max-age 1h --vfs-cache-max-size 10G --dir-cache-time 1m --poll-interval 1m --allow-other --umask 0022 --buffer-size 32M";

      ExecStop = "/run/wrappers/bin/fusermount3 -u ${config.home.homeDirectory}/Box";

      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # ==========================================================================
  # RUNTIME ENVIRONMENT SPLIT (Experimental Variant Engine)
  # ==========================================================================
  specialisation."quickshell-wip".configuration = {
    disabledModules = [ ./modules/desktop-stable.nix ];
    imports = [ ./modules/desktop-development.nix ];
  };
}
