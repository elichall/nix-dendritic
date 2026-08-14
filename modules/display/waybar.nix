# ==========================================================================
# WAYBAR STATUS BAR
# ==========================================================================
# PATH strategy + UWSM tracking: modules/_assets/module-contracts.md
# (C8/C9). Ported from legacy modules/desktop-stable.nix.
# ==========================================================================
{ inputs, ... }: {
  flake.modules.homeManager.waybar =
    { pkgs, ... }:
    let
      ghosttyBin = "${pkgs.ghostty}/bin/ghostty";
      tui = app: "${ghosttyBin} --class=com.waybar.tui -e ${app}";
      fastfetchBin = "${pkgs.fastfetch}/bin/fastfetch";
      weathrBin = "${pkgs.weathr}/bin/weathr";
      wlctlPkg = inputs.wlctl.packages.${pkgs.stdenv.hostPlatform.system}.default;
      wlctlBin = "${wlctlPkg}/bin/wlctl";
      bluetuiBin = "${pkgs.bluetui}/bin/bluetui";
      joltBin = "${pkgs.jolt-tui}/bin/jolt";
      btopBin = "${pkgs.btop}/bin/btop";
    in
    {
      home.packages = with pkgs; [
        ghostty
        fastfetch
        weathr
        wlctlPkg
        bluetui
        jolt-tui
        btop
      ];

      programs.waybar = {
        enable = true;
        systemd.enable = false;

        settings = {
          mainBar = {
            layer = "top";
            position = "top";
            margin-top = 5;
            margin-left = 5;
            margin-right = 5;
            spacing = 0;

            modules-left = [
              "custom/nixos"
              "hyprland/workspaces"
            ];
            modules-center = [
              "clock"
              "custom/weather"
            ];
            modules-right = [
              "cpu"
              "temperature"
              "memory"
              "custom/system"
              "bluetooth"
              "network"
              "battery"
            ];

            "custom/nixos" = {
              format = "";
              tooltip = false;
              on-click-right = "${ghosttyBin} --class=com.waybar.tui -e bash -c '${fastfetchBin}; read -n 1 -p \"Press any key to exit...\"'";
              on-click = "otter-open";
            };

            "hyprland/workspaces" = {
              format = "{name}";
              disable-scroll = true;
              all-outputs = true;
            };

            "clock" = {
              format = "󰥔  {:%A %I:%M}";
              tooltip-format = "<tt><big>{calendar}</big></tt>";
              calendar = {
                mode = "month";
                format = {
                  today = "<span color='#ff6699'><b><u>{}</u></b></span>";
                };
              };
            };

            "custom/weather" = {
              format = " {}";
              tooltip = true;
              interval = 1800;
              exec = "${pkgs.curl}/bin/curl -s 'wttr.in/?format=%t' | ${pkgs.gnused}/bin/sed 's/+//g'";
              on-click = "${tui weathrBin}";
            };

            "network" = {
              format-wifi = "{icon} ";
              format-ethernet = "󰈀 ";
              format-disconnected = "󰤫 ";
              format-disabled = "󰤮 ";
              on-click = "${tui wlctlBin}";
              on-click-right = "nmcli radio wifi | grep -q 'enabled' && nmcli radio wifi off || nmcli radio wifi on";
              tooltip-format = "    {ifname} via {gwaddr}";
              tooltip-format-wifi = "  {essid}\n    IP: {ipaddr}\n    Signal: {signalStrength}%\n {bandwidthUpBytes}   {bandwidthDownBytes}";
              tooltip-format-disconnected = "Disconnected";
              format-icons = [
                "󰤯"
                "󰤟"
                "󰤢"
                "󰤨"
              ];
            };

            "bluetooth" = {
              format-on = "󰂯";
              format-off = "󰂲";
              format-disabled = "󰂲";
              format-connected = "󰂯";
              on-click = "${tui bluetuiBin}";
              on-click-right = "bluetoothctl show | grep -q 'Powered: yes' && bluetoothctl power off || bluetoothctl power on";
              tooltip-format = "{controller_alias}\t{controller_address}";
              tooltip-format-connected = "{device_alias}";
            };

            "battery" = {
              states = {
                warning = 30;
                critical = 15;
              };
              format = "{icon} {capacity}%";
              format-charging = "{icon} {capacity}%";
              format-plugged = "{icon} {capacity}%";
              format-icons = [
                "󰁺"
                "󰁻"
                "󰁼"
                "󰁽"
                "󰁾"
                "󰁿"
                "󰂀"
                "󰂁"
                "󰂂"
                "󰁹"
              ];
              full-at = 80;
              interval = 60;
              tooltip-format = "Time Remaining: {time}\nPower Draw {power}W";
              on-click = "${tui joltBin}";
            };

            "cpu" = {
              format = " {icon}";
              on-click = "${tui btopBin}";
              tooltip-format = "Clock Speed: {avg_frequency} GHz\n\nCore Load Breakdown:\n{usage_per_core}";
              format-icons = [
                "[■▫▫▫▫▫▫▫▫▫]"
                "[■■▫▫▫▫▫▫▫▫]"
                "[■■■▫▫▫▫▫▫▫]"
                "[■■■■▫▫▫▫▫▫]"
                "[■■■■■▫▫▫▫▫]"
                "[■■■■■■▫▫▫▫]"
                "[■■■■■■■▫▫▫]"
                "[■■■■■■■■▫▫]"
                "[■■■■■■■■■▫]"
                "[■■■■■■■■■■]"
              ];
            };

            "temperature" = {
              hwmon-path = "/sys/class/hwmon/hwmon7/temp1_input";
              critical-threshold = 80;
              format = "{temperatureC}°C";
              format-critical = " {temperatureC}°C";
              on-click = "${tui btopBin}";
            };

            "memory" = {
              format = " {icon}";
              on-click = "${tui btopBin}";
              tooltip-format = "RAM: {used:0.1f}GB / {total:0.1f}GB ({percentage}%)\nSwap: {swapUsed:0.1f}GB / {swapTotal:0.1f}GB ({swapPercentage}%)";
              format-icons = [
                "[■▫▫▫▫▫▫▫▫▫]"
                "[■■▫▫▫▫▫▫▫▫]"
                "[■■■▫▫▫▫▫▫▫]"
                "[■■■■▫▫▫▫▫▫]"
                "[■■■■■▫▫▫▫▫]"
                "[■■■■■■▫▫▫▫]"
                "[■■■■■■■▫▫▫]"
                "[■■■■■■■■▫▫]"
                "[■■■■■■■■■▫]"
                "[■■■■■■■■■■]"
              ];
            };

            "custom/system" = {
              format = "";
              on-click = "";
              tooltip-format = "WIP wayedges system tray";
            };
          };
        };

        style = ''
          @import "colors.css";

          * {
              /* Prioritize the Nerd Font variant, fall back to strict monospace */
              font-family: "JetBrainsMono Nerd Font", "JetBrains Mono", monospace;
              font-size: 15px;
              font-weight: bold;
              min-height: 0;
              
              /* Enforce fixed-width numerals */
              font-feature-settings: "tnum";
          }

          window#waybar {
              background-color: rgba(0, 0, 0, 0);
              border-radius: 20px;
          }

          /* Formatting Defaults */
          #workspaces, #clock, #custom-weather, #custom-system, #network, #bluetooth, #battery, #memory, #cpu, #temperature {
              background-color: rgba(0, 0, 0, 0.5);
              color: rgba(200, 200, 200, 1.0);
              padding: 4px 18px;
              /* margin: 4px; the underlying window buffer space */ 
          }

          /* left block */
          window#waybar #custom-nixos {
              color: #74c7ec;
              font-size: 24px;
              background-color: rgba(0, 0, 0, 0.5);
              border: none;
              min-width: 32px;
              padding-left: 4px;
              margin-right: 0px;
              padding-right: 8px;
              border-right-width: 0px;
              border-radius: 14px 0px 0px 14px;
              text-shadow: 
                  -1px -1px 0 #000000,  1px -1px 0 #000000,
                  -1px  1px 0 #000000,  1px  1px 0 #000000,
                   0px -1px 0 #000000,  0px  1px 0 #000000,
                  -1px  0px 0 #000000,  1px  0px 0 #000000;
          }
          window#waybar #custom-nixos:hover {
              color: #89dceb;
          }
          #workspaces {
              border-width: 2px;
              border-radius: 14px;
              padding: 2px 12px;
              margin-left: 0px;
              padding-left: 12px;
              border-left-width: 0px;
              border-radius: 0px 14px 14px 0px;
          }
          #workspaces { padding: 2px 6px; }
          #workspaces button { color: rgba(190, 190, 190, 0.70); padding: 0 4px; }
          #workspaces button.active { color: rgba(200, 200, 200, 1.0); }

          /* Hover: workspaces-style rounded pill darken. Modules are windowed Gtk::EventBoxes
             (that's why :hover fires) that paint background + border-radius — so darkening the
             whole pill gives the same rounded-box hover the workspace buttons have. Pill stays
             opaque (boundary not washed out); background-color keeps the existing 0.5 base. */
          #clock:hover, #custom-weather:hover, #cpu:hover, #temperature:hover, #memory:hover, #custom-system:hover, #bluetooth:hover, #network:hover, #battery:hover {
              background-color: rgba(0, 0, 0, 0.65);
          }
          /* Workspaces keeps the full-fill hover (transparent button, no pill boundary) */
          #workspaces button:hover { background-color: rgba(0, 0, 0, 0.2); }

          /* center block */
          #clock {
              margin-right: 0px;
              padding-right: 12px;
              border-right-width: 0px;
              border-radius: 14px 0px 0px 14px;
          }
          #custom-weather {
              margin-left: 0px;
              padding-left: 12px;
              border-left-width: 0px;
              border-radius: 0px 14px 14px 0px;
          }

          /* right block */
          #cpu {
              margin-right: 0px;
              padding-right: 4px;
              border-right-width: 0px;
              border-radius: 14px 0px 0px 14px;
          }
          #temperature {
              margin-left: 0px;
              padding-left: 4px;
              border-left-width: 0px;
              margin-right: 0px;
              padding-right: 12px;
              border-right-width: 0px;
              border-radius: 0px 0px 0px 0px;
          }
          #memory {
              margin-left: 0px;
              padding-left: 12px;
              border-left-width: 0px;
              margin-right: 0px;
              padding-right: 12px;
              border-right-width: 0px;
              border-radius: 0px 0px 0px 0px;
          }
          #custom-system {
              margin-left: 0px;
              padding-left: 12px;
              border-left-width: 0px;
              margin-right: 0px;
              padding-right: 12px;
              border-right-width: 0px;
              border-radius: 0px 0px 0px 0px;
          }
          #bluetooth {
              margin-left: 0px;
              padding-left: 12px;
              border-left-width: 0px;
              margin-right: 0px;
              padding-right: 12px;
              border-right-width: 0px;
              border-radius: 0px 0px 0px 0px;
          }
          #network {
              margin-left: 0px;
              padding-left: 12px;
              border-left-width: 0px;
              margin-right: 0px;
              padding-right: 12px;
              border-right-width: 0px;
              border-radius: 0px 0px 0px 0px;
          }
          #battery {
              margin-left: 0px;
              padding-left: 12px;
              border-left-width: 0px;
              border-radius: 0px 14px 14px 0px;
          }

          #battery.warning { border-color: @theme_accent; }
          #battery.critical, #temperature.critical {
              border-color: #f38ba8;
              animation-name: blink;
              animation-duration: 1s;
              animation-timing-function: linear;
              animation-iteration-count: infinite;
          }

          @keyframes blink {
              to { background-color: #f38ba8; color: #000000; }
          }

          tooltip {
              background: rgba(0, 0, 0, 0.6);
              border-radius: 10px;
              padding: 8px;
          }
          tooltip label {
              font-family: "JetBrains Mono";
              color: rgba(190, 190, 190, 1.0);
              font-size: 13px;
          }
        '';
      };
    };
}
