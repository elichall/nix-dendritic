{ config, pkgs, ... }:

{
  # ==========================================================================
  # NATIVE WAYBAR MANAGEMENT
  # ==========================================================================
  programs.waybar = {
    enable = true;
    # Let UWSM track execution instead of the baseline Home Manager daemon
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
          "network"
          "bluetooth"
          "cpu"
          "temperature"
          "memory"
          "battery"
        ];

        "custom/nixos" = {
          format = "";
          tooltip = false;
          on-click-right = "ghostty --class=com.waybar.tui -e bash -c 'fastfetch; read -n 1 -p \"Press any key to exit...\"'";
          on-click = "otter-open";
        };

        "hyprland/workspaces" = {
          format = "{name}";
          disable-scroll = true;
          all-outputs = true;
        };

        "clock" = {
          format = "{:%A %I:%M}";
          tooltip-format = "<tt><big>{calendar}</big></tt>";
          calendar = {
            mode = "month";
            format = {
              today = "<span color='#ff6699'><b><u>{}</u></b></span>";
            };
          };
        };

        "custom/weather" = {
          format = "{}";
          tooltip = true;
          interval = 1800;
          exec = "${pkgs.curl}/bin/curl -s 'wttr.in/?format=1' | ${pkgs.gnused}/bin/sed 's/+//g'";
          on-click = "ghostty --class=com.waybar.tui -e weathr";
        };

        "network" = {
          format-wifi = "  {signalStrength}%";
          format-ethernet = "󰈀 ";
          format-disconnected = "󰖪 ";
          format-disabled = "󰖪 ";
          on-click = "ghostty --class=com.waybar.tui -e wlctl";
          on-click-right = "nmcli radio wifi | grep -q 'enabled' && nmcli radio wifi off || nmcli radio wifi on";
          tooltip-format = "    {ifname} via {gwaddr}";
          tooltip-format-wifi = "  {essid}\n    IP: {ipaddr}\n    Signal: {signalStrength}%\n {bandwidthUpBytes}   {bandwidthDownBytes}";
          tooltip-format-disconnected = "Disconnected";
        };

        "bluetooth" = {
          format-on = "";
          format-off = "󰂲";
          format-disabled = "󰂲";
          format-connected = "";
          on-click = "ghostty --class=com.waybar.tui -e bluetui";
          on-click-right = "bluetoothctl show | grep -q 'Powered: yes' && bluetoothctl power off || bluetoothctl power on";
          tooltip-format = "{controller_alias}\t{controller_address}";
          tooltip-format-connected = "{device_alias}";
        };

        "battery" = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon}  {capacity}%";
          format-charging = " {capacity}%";
          format-plugged = " {capacity}%";
          format-full = " {capacity}%";
          format-not-charging = " {capacity}%";
          format-icons = [
            ""
            ""
            ""
            ""
            ""
          ];
          interval = 60;
          tooltip-format = "Time Remaining: {time}\nPower Draw {power}W";
          on-click = "ghostty --class=com.waybar.tui -e jolt";
        };

        "cpu" = {
          format = "  {usage}%";
          on-click = "ghostty --class=com.waybar.tui -e btop";
          tooltip-format = "Clock Speed: {avg_frequency} GHz\n\nCore Load Breakdown:\n{usage_per_core}";
        };

        "temperature" = {
          hwmon-path = "/sys/class/hwmon/hwmon7/temp1_input";
          critical-threshold = 80;
          format = " {temperatureC}°C";
          format-critical = " {temperatureC}°C";
          on-click = "ghostty --class=com.waybar.tui -e btop";
        };

        "memory" = {
          format = "  {used}GB";
          on-click = "ghostty --class=com.waybar.tui -e btop";
          tooltip-format = "RAM: {used:0.1f}GB / {total:0.1f}GB ({percentage}%)\nSwap: {swapUsed:0.1f}GB / {swapTotal:0.1f}GB ({swapPercentage}%)";
        };
      };
    };

    style = ''
      @import "colors.css";

      * {
          font-family: "JetBrains Mono", "Font Awesome 6 Free", "FontAwesome", sans-serif;
          font-size: 14px;
          font-weight: bold;
          min-height: 0;
      }

      window#waybar {
          background-color: rgba(0, 0, 0, 0.4);
          border-radius: 20px;
      }

      window#waybar #custom-nixos {
          color: #74c7ec;
          font-size: 24px;
          background-color: transparent;
          border: none;
          padding-left: 12px;
          padding-right: 8px;
          min-width: 32px;
          text-shadow: 
              -2px -2px 0 #000000,  2px -2px 0 #000000,
              -2px  2px 0 #000000,  2px  2px 0 #000000,
               0px -2px 0 #000000,  0px  2px 0 #000000,
              -2px  0px 0 #000000,  2px  0px 0 #000000;
      }

      window#waybar #custom-nixos:hover {
          color: #89dceb;
          font-size: 26px;
          padding-left: 10px;
          padding-right: 10px;
      }

      #workspaces, #clock, #custom-weather, #network, #bluetooth, #battery, #memory, #cpu, #temperature {
          background-color: @theme_bg;
          border-color: @theme_muted;
          color: @theme_accent;
          border-style: solid;
          border-width: 2px;
          border-radius: 14px;
          padding: 2px 12px;
          margin: 4px;
      }

      #workspaces { padding: 2px 6px; }
      #workspaces button { color: @theme_muted; padding: 0 4px; }
      #workspaces button.active { color: @theme_accent; }

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
          background: @theme_bg;
          border: 2px solid @theme_accent;
          border-radius: 10px;
          padding: 8px;
      }
      tooltip label {
          font-family: "JetBrains Mono";
          color: @theme_fg;
          font-size: 13px;
      }
    '';
  };
}
