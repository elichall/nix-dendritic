{ inputs, ... }: {
  flake.modules.homeManager.noctalia = { pkgs, ... }: {
    programs.noctalia = {
      enable = true;
      settings = {
        theme = {
          mode = "dark";
          source = "builtin";
          builtin = "Gruvbox";
          pure_black_dark = true;
        };
        bar.default = {
          start = [
            "os"
            "group:utility"
          ];
          center = [
            "group:display"
          ];
          end = [
            "group:sys_mon"
            "group:basic_control"
          ];
          capsule_group = [
            {
              id = "utility";
              members = [
                "workspaces"
                "clipboard"
                "notifications"
              ];
            }
            {
              id = "display";
              members = [
                "audio_visualizer"
                "clock"
                "weather"
              ];
            }
            {
              id = "sys_mon";
              members = [
                "cpu"
                "ram"
              ];
            }
            {
              id = "basic_control";
              members = [
                "bluetooth"
                "network"
                "battery"
                "control-center"
              ];
            }
          ];
          position = "top";
          reserve_space = true;
          layer = "top";
          auto_hide = false;
          smart_auto_hide = false;

          thickness = 34;
          border = "outline";
          border_width = 0.0;
          background_opacity = 0.4;
          shadow = true;
          margin_ends = 100;
          margin_edge = 0;

          scale = 1.0;
          font_weight = 700;

          padding = 14;
          widget_spacing = 10;

          capsule = true;
          capsule_fill = "surface_variant";
          capsule_thickness = 0.80;
          capsule_opacity = 1.0;

          # outside of widget areas
          dead_zone.actions = {
            left = "none";
            right = "none";
            middle = "none";
            scroll_up = "none";
            scroll_left = "none";
            scroll_right = "none";
            scroll_down = "none";
            back = "none";
            forward = "none";
          };
        };
        widget = {
          os = {
            type = "custom_button";
            custom_image = "/home/elichall/.nix/modules/_assets/aesthetics/nixos-image.png";
            actions.left = "exec otter-open";
            scale = 1.6;
            capsule = false;
          };
          clock.format = "{:%A %-I:%M %p}\n{:%y-%m-%d}";
          clock.anchor = true;
          cpu = {
            type = "sysmon";
            stat = "cpu_usage";
            # visualization = "graph";
            show_value = true;
          };
          ram = {
            type = "sysmon";
            stat = "ram_used";
          };
          network = {
            show_label = false;
            vpn_status = "both";
          };
          battery.show_label = false;
          weather.show_condition = false;
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
          panel = {
            launcher_placement = "attached";
            clipboard_placement = "attached";
            control_center_placement = "attached";
            wallpaper_placement = "attached";
            session_placement = "attached";
            polkit_placement = "attached";
            open_near_click_control_center = true;
            open_near_click_launcher = true;
            open_near_click_clipboard = true;
            open_near_click_wallpaper = true;
            open_near_click_session = true;
          };
          clipboard_enabled = true;
          clipboard_history_max_entries = 20;
          clipboard_auto_paste = "auto";
          setup_wizard_enabled = false;
          settings_window_translucent = true;
        };
        accessibility = {
          ui_scale = 1.0;
          high_contrast = false;
        };
        location.auto_locate = true;
        weather.unit = "imperial";
        idle = {
          behavior = {
            lock = {
              enabled = false;
            };
            screen-off = {
              enabled = false;
            };
          };
        };
        notification = {
          enable_daemon = true;
        };
        theme.templates = {
          enable_builtin_templates = true;
          builtin_ids = [
            "foot"
            "hyprland"
          ];
          enable_community_templates = true;
          community_ids = [ "yazi" ];
        };
        hooks.colors_changed =
          let
            themeSyncScript = pkgs.writeShellApplication {
              name = "noctalia-theme-sync";
              runtimeInputs = with pkgs; [
                gnused
                gnugrep
                procps
                neovim
              ];
              text = ''
                set -euo pipefail

                FOOT_THEME="$HOME/.config/foot/themes/noctalia"
                [ -f "$FOOT_THEME" ] || exit 0

                # Parse palette from foot theme
                while IFS='=' read -r key val; do
                  case "$key" in
                    background)  BG="$val" ;;
                    foreground)  FG="$val" ;;
                    regular0)    C0="$val" ;;
                    regular1)    C1="$val" ;;
                    regular2)    C2="$val" ;;
                    regular3)    C3="$val" ;;
                    regular4)    C4="$val" ;;
                    regular5)    C5="$val" ;;
                    regular6)    C6="$val" ;;
                    regular7)    C7="$val" ;;
                    bright0)     C8="$val" ;;
                    bright1)     C9="$val" ;;
                    bright2)     CA="$val" ;;
                    bright3)     CB="$val" ;;
                    bright4)     CC="$val" ;;
                    bright5)     CD="$val" ;;
                    bright6)     CE="$val" ;;
                    bright7)     CF="$val" ;;
                  esac
                done < <(grep -E '^(background|foreground|regular[0-7]|bright[0-7])=' "$FOOT_THEME")
                [ -z "$BG" ] && exit 1

                # Write tmux colors
                rm -f "$HOME/.config/tmux/colors.tmux"
                cat > "$HOME/.config/tmux/colors.tmux" <<TMUX
                set -g status-style "bg=#$BG,fg=#$FG"
                set -g status-left "#[fg=#$BG,bg=#$C2,bold] 󰨖 #S #[bg=default,fg=default] "
                set -g window-status-format "#[fg=#$C8,bg=default] #I:#W "
                set -g window-status-current-format "#[fg=#000000,bg=#$C8,bold] #I:#W "
                set -g window-status-separator ""
                set -g pane-border-style "fg=#$C8"
                set -g pane-active-border-style "fg=#$C2"
                set -g message-style "bg=#$C8,fg=#$C2,bold"
                TMUX

                # Push palette to all running foot instances via OSC escape sequences
                # OSC sequences must be written to the shell's stdout (PTY slave),
                # not foot's stdin. The PTY slave -> PTY master -> foot interprets.
                ESC=$'\033'
                for foot_pid in $(pgrep -x foot 2>/dev/null); do
                  shell_pid=$(pgrep -P "$foot_pid" 2>/dev/null | head -1)
                  [ -z "$shell_pid" ] && continue
                  {
                    printf "''${ESC}]11;#%s''${ESC}\\" "$BG"
                    printf "''${ESC}]10;#%s''${ESC}\\" "$FG"
                    printf "''${ESC}]4;0;#%s''${ESC}\\" "$C0"
                    printf "''${ESC}]4;1;#%s''${ESC}\\" "$C1"
                    printf "''${ESC}]4;2;#%s''${ESC}\\" "$C2"
                    printf "''${ESC}]4;3;#%s''${ESC}\\" "$C3"
                    printf "''${ESC}]4;4;#%s''${ESC}\\" "$C4"
                    printf "''${ESC}]4;5;#%s''${ESC}\\" "$C5"
                    printf "''${ESC}]4;6;#%s''${ESC}\\" "$C6"
                    printf "''${ESC}]4;7;#%s''${ESC}\\" "$C7"
                    printf "''${ESC}]4;8;#%s''${ESC}\\" "$C8"
                    printf "''${ESC}]4;9;#%s''${ESC}\\" "$C9"
                    printf "''${ESC}]4;10;#%s''${ESC}\\" "$CA"
                    printf "''${ESC}]4;11;#%s''${ESC}\\" "$CB"
                    printf "''${ESC}]4;12;#%s''${ESC}\\" "$CC"
                    printf "''${ESC}]4;13;#%s''${ESC}\\" "$CD"
                    printf "''${ESC}]4;14;#%s''${ESC}\\" "$CE"
                    printf "''${ESC}]4;15;#%s''${ESC}\\" "$CF"
                  } > "/proc/$shell_pid/fd/1" 2>/dev/null &
                done

                # Reload palette in all running neovim instances
                if [ -d "''${XDG_RUNTIME_DIR:-/tmp}" ]; then
                  find "''${XDG_RUNTIME_DIR:-/tmp}" -type s 2>/dev/null | grep "nvim" | while read -r server; do
                    nvim --server "$server" --remote-expr "execute('lua package.loaded[\"lean.core.palette_sync\"] = nil; vim.cmd(\"colorscheme lean_sync\")')" >/dev/null 2>&1 &
                  done || true
                fi

                # Reload opencode's system theme palette
                pkill -SIGUSR2 opencode 2>/dev/null || true
              '';
            };
          in
          "T=\"$HOME/.config/foot/themes/noctalia\"; [ -f \"$T\" ] && ! grep -q '^alpha=' \"$T\" && sed -i '/^\\[colors-dark\\]/a alpha = 0.7\\nblur = true' \"$T\"; hyprctl reload; ${themeSyncScript}/bin/noctalia-theme-sync; tmux source-file \"$HOME/.config/tmux/colors.tmux\" 2>/dev/null";
      };
    };
  };
}
