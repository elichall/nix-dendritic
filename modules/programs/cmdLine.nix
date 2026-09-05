{ config, lib, ... }: {
  flake.modules = {
    nixos.cmdLine = { pkgs, config, ... }: {
      # enables hosts prefered shell at root level
      programs.${config.host.shell}.enable = true;
    };

    homeManager.cmdLine =
      {
        pkgs,
        lib,
        config,
        ...
      }:
      let
        hostShell = config.host.shell;
        allShells = [
          "bash"
          "zsh"
          "fish"
          "nushell"
        ];
        capitalizeFunc =
          str:
          let
            firstLetter = lib.toUpper (lib.substring 0 1 str);
            leftOver = lib.substring 1 (-1) str;
          in
          "${firstLetter}${leftOver}";

        mkIntegrations =
          supportedShells:
          lib.genAttrs (map (shell: "enable${capitalizeFunc shell}Integration") supportedShells) (
            optName: optName == "enable${capitalizeFunc hostShell}Integration"
          );
      in
      {
        # ==========================================================================
        # SHELL INTEGRATION MATRIX
        # ==========================================================================
        # HM 26.05 defaults every shell integration to "on", which trips programs
        # whose integrations we don't want (e.g. fzf's readline binds under
        # ble.sh). mkIntegrations flips every switch OFF except the one matching
        # host.shell. Each consumer receives only the shells it actually supports
        # in this pin (fzf lacks nushell/ion; direnv/zoxide lack ion) — passing an
        # unsupported name would reference a nonexistent option.
        #
        # SCAFFOLD-ONLY: zsh/fish/nushell are enum-valid (host.shell) but only
        # bash ships a configured body below today; selecting another shell
        # yields no interactive-shell config at all.
        home.shell = mkIntegrations allShells;

        # ==========================================================================
        # INTERACTIVE BASH MANAGEMENT
        # ==========================================================================
        # User-scale shell tooling (previously in nixos.main systemPackages)
        home.packages = with pkgs; [
          ripgrep
          tree
        ];

        # ==========================================================================
        # ENV VARS
        # ==========================================================================
        # HISTFILE keeps <shell>_history out of $HOME (per-shell subdir under
        # XDG cache) — shell-agnostic, valid for zsh/fish/nushell too. blesh 0.4
        # needs no relocation vars: it is XDG-native (runtime state under
        # $XDG_STATE_HOME/$XDG_CACHE_HOME) and reads its init file natively from
        # ${XDG_CONFIG_HOME}/blesh/init.sh — so we simply drop blerc there
        # (see home.file."config/blesh/init.sh") and source no BLE_* env vars.
        home.sessionVariables = {
          HISTFILE = "${config.home.homeDirectory}/.cache/${hostShell}/history";
        };

        programs.bash = {
          enable = hostShell == "bash";
          historyControl = [ "ignoreboth" ];
          historySize = 1000;
          historyFileSize = 2000;

          shellAliases = {
            ll = "ls -alF --color=auto";
            la = "ls -A --color=auto";
            l = "ls -CF --color=auto";
            grep = "grep --color=auto";
            snorbs = "sudo nixos-rebuild switch --flake ~/.nix#workstation";
            gdu = "gdu --no-cross";
          }
          // lib.optionalAttrs config.host.isWsl {
            # WSL win32yank autopaste workaround (toolbox T3): drain the stale
            # input buffer before nvim opens, or it replays as a paste.
            nvim = "win32yank -i < /dev/null && command nvim";
          };

          bashrcExtra = ''
            # Force the CURRENT generation's session variables into every new
            # shell. hm-session-vars.sh early-returns when __HM_SESS_VARS_SOURCED
            # is present — a value inherited from the boot-time graphical session
            # (older generation) — which silently skips new/changed
            # home.sessionVariables (HISTFILE, CLAUDE_CONFIG_DIR, ...) until a
            # full re-login. Clearing the guard makes each terminal self-healing.
            unset __HM_SESS_VARS_SOURCED
            . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
          '';

          initExtra = ''
            shopt -s histappend
            shopt -s checkwinsize
            # Initialize blesh first
            if [[ $- == *i* ]]; then
              source ${pkgs.blesh}/share/blesh/ble.sh --noattach
            fi
            # Initialize zoxide
            eval "$(${lib.getExe pkgs.zoxide} init bash)"
            # Initialize direnv (defines the _direnv_hook function)
            eval "$(${lib.getExe pkgs.direnv} hook bash)"
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
              eval "$(${lib.getExe pkgs.starship} init bash --print-full-init)"
            fi
            # Attach blesh
            [[ ''${BLE_VERSION-} ]] && ble-attach
          '';
        };

        programs.starship = {
          enable = true;

          settings = {
            format = "$os$directory$container$nix_shell$python$git_branch$git_status$character";
            add_newline = false;
            line_break.disabled = true;
            cmd_duration.disabled = true;

            os = {
              disabled = false;
              format = "[$symbol]($style) ";
              symbols.NixOS = "[](bold #74c7ec)";
              symbols.Ubuntu = "[󰕈](bold #e95420)";
              symbols.Arch = "[󰣇](bold #1793d1)";
              symbols.Macos = "[](bold #ffffff)";
              symbols.Fedora = "[](bold #3c6eb4)";
            };
            container = {
              symbol = "";
              format = "[$symbol$name]($style) ";
              style = "bold red";
            };
            nix_shell = {
              symbol = "❄️";
              format = "[$symbol$state]($style) ";
              pure_msg = "pure";
              impure_msg = "";
              unknown_msg = "";
              heuristic = false;
            };
            python = {
              symbol = "";
              format = "[$symbol$virtualenv]($style) ";
              style = "bold yellow";
              detect_files = [ ];
              detect_extensions = [ ];
            };
          };
        }
        # enableBashIntegration stays hard-OFF for every host: bash wiring is
        # injected manually in programs.bash.initExtra above (ble.sh conflicts).
        // (mkIntegrations allShells // { enableBashIntegration = false; });

        programs.zoxide = {
          enable = true;
        }
        // (mkIntegrations allShells // { enableBashIntegration = false; });

        programs.fzf = {
          enable = true;
        }
        // (
          mkIntegrations [
            "bash"
            "zsh"
            "fish"
          ]
          // {
            enableBashIntegration = false;
          }
        );

        programs.direnv = {
          enable = true;
          nix-direnv.enable = true;
          silent = true;
          config.global = {
            hide_env_diff = true; # no export +N -M dump
            log_filter = "^$"; # suppress loading/using-flake status lines
          };
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
        }
        // (
          mkIntegrations [
            "bash"
            "zsh"
            "fish"
            "nushell"
          ]
          // {
            enableBashIntegration = false;
          }
        );

        # ==========================================================================
        # DECLARATIVE DOTFILE GENERATION
        # ==========================================================================
        # blesh 0.4 reads its init file natively from
        # ${XDG_CONFIG_HOME}/blesh/init.sh (falls back to ~/.blerc) — no BLERC
        # env var in this version. bash-gated: blesh is bash-only.
        home.file.".config/blesh/init.sh".text = lib.mkIf (hostShell == "bash") ''
          ble-face -s filename_directory 'fg=blue'
          ble-face -s filename_other fg=white,nounderline

          function blerc/emacs-load-hook {
            ble-bind -f 'C-a' accept-line
            return 0
          }
          blehook/eval-after-load keymap_emacs blerc/emacs-load-hook
        '';
      };
  };
}
