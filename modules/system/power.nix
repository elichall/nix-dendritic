# ==========================================================================
# POWER POLICY — idle ladder + lid suspend (battery vs AC)
# ==========================================================================
# nixos.power: logind lid policy. homeManager.power: hypridle ladder driven by
# `idle-action`. Panel refresh/lid handling lives in display/hyprland.nix
# (panelScript). Rationale + ladder table: modules/_assets/documentation/decisions.md #66.
#   AC:      showoff idle screen (5 min) (no screen-off, no lock, no suspend)
#   Battery: screen off (10 min) -> suspend (30 min); no lock; remote
#            (SSH) sessions block idle suspend.
{ ... }: {
  flake.modules.nixos.power = { ... }: {
    # Battery + no external monitor: lid close suspends. AC or docked/external
    # monitor: ignored, so SSH sessions survive (Hyprland handles the panel).
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };
  };

  flake.modules.homeManager.power =
    { lib, pkgs, ... }:
    let
      idleAction = pkgs.writeShellApplication {
        name = "idle-action";
        runtimeInputs = with pkgs; [
          brightnessctl
          hyprland
          systemd
          jq
          coreutils
        ];
        text = ''
          state="''${XDG_RUNTIME_DIR:-/tmp}/idle-action-dimmed"

          on_ac() {
            local t d
            for t in /sys/class/power_supply/*/type; do
              d=$(dirname "$t")
              if [ "$(cat "$t")" = Mains ] && [ "$(cat "$d/online" 2>/dev/null)" = 1 ]; then
                return 0
              fi
            done
            return 1
          }

          case "''${1:-}" in
            dim)
              cur=$(brightnessctl -m | cut -d, -f4 | tr -d '%')
              if [ "$cur" -gt 10 ]; then
                brightnessctl -s set 10% >/dev/null
                touch "$state"
              fi
              ;;
            undim)
              if [ -e "$state" ]; then
                brightnessctl -r >/dev/null
                rm -f "$state"
              fi
              ;;
            showoff)
              # AC only: the animated idle screen keeps the panel at full rate.
              if on_ac; then showoff --idle; fi
              ;;
            screen-off)
              if ! on_ac; then hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'; fi
              ;;
            screen-on)
              hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'
              ;;
            suspend)
              if on_ac; then exit 0; fi
              # Never kill a remote (SSH) login with an idle suspend.
              for s in $(loginctl list-sessions -j | jq -r '.[].session'); do
                if [ "$(loginctl show-session "$s" -p Remote --value)" = yes ]; then
                  exit 0
                fi
              done
              systemctl suspend
              ;;
            *)
              echo "usage: idle-action dim|undim|showoff|screen-off|screen-on|suspend" >&2
              exit 2
              ;;
          esac
        '';
      };
      act = "${lib.getExe idleAction}";
    in
    {
      home.packages = [ idleAction ];

      xdg.configFile."hypr/hypridle.conf".text = ''
        general {
            after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'
        }

        # showoff idle screen (AC only; no-op on battery)
        listener {
            timeout = 300
            on-timeout = ${act} showoff
        }

        # screen off (battery only)
        listener {
            timeout = 600
            on-timeout = ${act} screen-off
            on-resume = ${act} screen-on
        }

        # suspend (battery only, never over an active remote session)
        listener {
            timeout = 1800
            on-timeout = ${act} suspend
        }
      '';
    };
}
