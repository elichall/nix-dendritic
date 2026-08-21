# ==========================================================================
# NOTIFY-SEND (hybrid notification wrapper)
# ==========================================================================
# Routes notifications to Noctalia (notify-send via D-Bus) or Hyprland
# (hyprctl notify, compositor-internal) based on programs.noctalia.enable.
# Creates derivation + sets config.utils.notifySend.
{ ... }: {
  flake.modules.homeManager.notifySend = { config, pkgs, lib, ... }: let
    isNoctalia = config.programs.noctalia.enable or false;

    cli = pkgs.writeShellApplication {
      name = "hybrid-notify";
      runtimeInputs = with pkgs; [
        coreutils
      ] ++ (if isNoctalia then [ libnotify ] else [ hyprland ]);
      text =
        if isNoctalia then ''
          set -euo pipefail
          urgency="$1"
          message="$2"
          case "$urgency" in
            success) notify-send -u low -t 6000 "nixos-rebuild" "$message" ;;
            error)   notify-send -u critical -t 10000 "nixos-rebuild" "$message" ;;
            *)       notify-send -u normal -t 5000 "nixos-rebuild" "$message" ;;
          esac
        '' else ''
          set -euo pipefail
          urgency="$1"
          message="$2"
          case "$urgency" in
            success) hyprctl notify 5 6000 "rgb(2ecc71)" "$message" >/dev/null 2>&1 ;;
            error)   hyprctl notify 3 10000 "rgb(e74c3c)" "$message" >/dev/null 2>&1 ;;
            *)       hyprctl notify 1 5000 "0" "$message" >/dev/null 2>&1 ;;
          esac
        '';
    };
  in {
    utils.notifySend = cli;
    home.packages = [ cli ];
  };
}
