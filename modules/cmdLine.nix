{ inputs, ... }: {
  flake.modules.nixos.cmdLine = { pkgs, ... }: {
    # enables
    programs.bash.enable = true;

    # enables system-wide direnv sandbox store path integration
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };

  flake.modules.homeManager.cmdLine = { pkgs, ... }: {
    # ==========================================================================
    # SHELL INTEGRATION SWITCHES
    # ==========================================================================
    # Home Manager 26.05 defaults every shell integration to "on". Bash is the
    # only interactive shell here, so explicitly disable the rest. Without this,
    # programs like fzf enable their nushell integration and trip assertions
    # (fzf requires >= 0.73.0 for it).
    home.shell = {
      enableFishIntegration = false;
      enableIonIntegration = false;
      enableNushellIntegration = false;
      enableZshIntegration = false;
    };

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

    programs.starship = {
      enable = true;
      # manuel bash injection cause of blesh complications
      enableBashIntegration = false;

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
      enableBashIntegration = false;
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
  };
}
