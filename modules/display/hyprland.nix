# ==========================================================================
# HYPRLAND DESKTOP ENVIRONMENT
# ==========================================================================
# System scale: compositor + portal wiring. User scale: session tooling +
# full user config (keybinds, autostart, rules). Rule 4 deps:
# modules/_assets/documentation/module-contracts.md (C8/C9).
# ==========================================================================
{ inputs, ... }:
let
  noctaliaPackage = inputs.noctalia.packages.x86_64-linux.default;
in
{
  flake.modules.nixos.hyprland = { pkgs, ... }: {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      withUWSM = false;
    };
  };

  flake.modules.homeManager.hyprland =
    {
      config,
      osConfig ? { },
      pkgs,
      lib,
      ...
    }:
    let
      # nixos-scope host option (one scale for ALL monitors); absent on standalone-HM → 1.0
      displayScale = osConfig.host.display.scale or 1.0;
      hasPrintKey = osConfig.host.keyboard.hasPrintKey or false;
      noctaliaCmd = lib.getExe noctaliaPackage;
      tmuxCmd = "${lib.getExe pkgs.tmux} new-session -A -s 'main'";
      menu = "otter-open";
      browser = config.browser.command;

      brightnessU = "${lib.getExe pkgs.brightnessctl} set 5%+";
      brightnessD = "${lib.getExe pkgs.brightnessctl} set 5%-";
      volumeU = "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+";
      volumeD = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
      muteAudio = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      muteMic = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";

      # Lid handler (called from lid-switch binds + monitor hotplug events).
      # Lid closed + external monitor present -> disable eDP-1; otherwise ensure
      # it is enabled (closed lid with no external just blanks via dpms).
      lidScript = pkgs.writeShellScript "hypr-lid" ''
        PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.gnugrep pkgs.hyprland ]}
        panel="hl.monitor({ output = \"eDP-1\", mode = \"preferred\", position = \"auto\", scale = ${toString displayScale}, disabled = false })"
        if grep -q closed /proc/acpi/button/lid/*/state 2>/dev/null; then
          if hyprctl monitors -j | grep -q '"name": "\(DP\|HDMI\)'; then
            hyprctl eval 'hl.monitor({ output = "eDP-1", disabled = true })'
          else
            hyprctl eval "$panel"
            hyprctl dispatch dpms off eDP-1
          fi
        else
          hyprctl eval "$panel"
          hyprctl dispatch dpms on eDP-1
        fi
      '';

      screenSnip = "${lib.getExe pkgs.grimblast} copysave area";
      screenShot = "${lib.getExe pkgs.grimblast} copysave screen";
      fileManager = config.terminal.exec "bash -ci '${lib.getExe pkgs.yazi}; exit'";
      systemManager = "otter-power";

      hypridleCmd = lib.getExe pkgs.hypridle;
      showoff = "showoff";
      otterCmd = "otter-apps --refresh-cache";
      playerctlCmd = lib.getExe pkgs.playerctl;
    in
    {
      home.packages =
        config.terminal.packages
        ++ (with pkgs; [
          hypridle
          grimblast
          brightnessctl
          tmux
          yazi
          playerctl
        ]);

      wayland.windowManager.hyprland = {
        enable = true;

        configType = "lua";

        systemd.enable = false;

        extraConfig = ''
          -- --- SINGLE SOURCE OF TRUTH COLOR LINKING ---
          ${
            if config.programs.noctalia.enable then
              ''
                local noctalia_path = os.getenv("HOME") .. "/.config/hypr/noctalia.lua"
                local theme
                local ok, noctalia = pcall(dofile, noctalia_path)
                if ok and type(noctalia) == "table" and noctalia.colors then
                  theme = {
                    accent = noctalia.colors.primary,
                    muted = noctalia.colors.surface,
                    bg = noctalia.colors.shadow,
                  }
                  if type(noctalia.apply_theme) == "function" then
                    noctalia.apply_theme()
                  end
                else
                  theme = {
                    accent = "rgb(74, 199, 236)",
                    muted = "rgb(88, 91, 112)",
                    bg = "rgb(17, 17, 27)"
                  }
                end
              ''
            else
              ''
                local theme = {
                  accent = "rgb(74, 199, 236)",
                  muted = "rgb(88, 91, 112)",
                  bg = "rgb(17, 17, 27)"
                }
              ''
          }

          ------------------
          -- -- MONITORS -- --
          ------------------
          -- any other monitor, on any port (empty output = catch-all fallback); same scale as the internal panel
          hl.monitor({ output = "", mode = "preferred", position = "auto", scale = ${toString displayScale} })
          -- internal panel (host.display.scale, nixos scope via osConfig)
          hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = ${toString displayScale} })

          ---------------------
          -- -- MY PROGRAMS -- --
          ---------------------
          local terminal = "${config.terminal.term}"
          local tmux = "${config.terminal.exec tmuxCmd}"
          local menu = "${menu}"
          local browser = "${browser}"
          local brightnessU = "${brightnessU}"
          local brightnessD = "${brightnessD}"
          local volumeU = "${volumeU}"
          local volumeD = "${volumeD}"
          local muteAudio = "${muteAudio}"
          local muteMic = "${muteMic}"
          local screenSnip = "${screenSnip}"
          local screenShot = "${screenShot}"
          local fileManager = "${fileManager}"
          local systemManager = "${systemManager}"
          local sleepScreen = "${showoff}"

          -------------------
          -- -- AUTOSTART -- --
          -------------------
          hl.on("hyprland.start", function()
            hl.exec_cmd("bash -c '${lib.getExe pkgs.tmux} new-session -d -s main 2>/dev/null'")
            hl.exec_cmd("${hypridleCmd}")
            hl.exec_cmd("${otterCmd}")
            hl.exec_cmd("${noctaliaCmd} &")
            hl.exec_cmd("bash -c 'systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP NIXOS_OZONE_WL && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP NIXOS_OZONE_WL && systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal'")
          end)

          -------------------------------
          -- -- ENVIRONMENT VARIABLES -- --
          -------------------------------
          hl.env("XDG_SCREENSHOTS_DIR", "/home/elichall/Pictures/Screenshots")

          -----------------------
          -- -- LOOK AND FEEL -- --
          -----------------------
          hl.animation({ leaf = "workspaces", enabled = false })
          hl.animation({ leaf = "workspacesIn", enabled = false })
          hl.animation({ leaf = "workspacesOut", enabled = false })

          hl.config({
            general = {
              gaps_in = 4,
              gaps_out = 6,
              border_size = 1,
              ["col.active_border"] = { colors = { theme.accent, theme.muted }, angle = 45 },
              ["col.inactive_border"] = theme.muted,
              resize_on_border = false,
              allow_tearing = false,
              layout = "dwindle",
            },
            decoration = {
              rounding = 10,
              rounding_power = 2,
              active_opacity = 1.0,
              inactive_opacity = 1.0,
              shadow = {
                enabled = true,
                range = 4,
                render_power = 3,
                color = theme.bg,
              },
              blur = {
                enabled = true,
                size = 3,
                passes = 1,
                vibrancy = 0.1696,
              },
            },
            animations = {
              enabled = true,
              bezier = {
                { "easeOutQuint",   0.23, 1,    0.32, 1 },
                { "easeInOutCubic", 0.65, 0.05, 0.36, 1 },
                { "linear",         0,    0,    1,    1 },
                { "almostLinear",   0.5,  0.5,  0.75, 1 },
                { "quick",          0.15, 0,    0.1,  1 },
              },
              animation = {
                { "global",        1, 10,   "default" },
                { "border",        1, 5.39, "easeOutQuint" },
                { "windows",       1, 4.79, "easeOutQuint" },
                { "windowsIn",     1, 4.1,  "easeOutQuint", "popin 87%" },
                { "windowsOut",    1, 1.49, "linear",       "popin 87%" },
                { "fadeIn",        1, 1.73, "almostLinear" },
                { "fadeOut",       1, 1.46, "almostLinear" },
                { "fade",          1, 3.03, "quick" },
                { "layers",        1, 3.81, "easeOutQuint" },
                { "layersIn",      1, 4,    "easeOutQuint", "fade" },
                { "layersOut",     1, 1.5,  "linear",       "fade" },
                { "fadeLayersIn",  1, 1.79, "almostLinear" },
                { "fadeLayersOut", 1, 1.39, "almostLinear" },
                { "workspaces",    0, 0,    "default" },
                { "workspacesIn",  0, 0,    "default" },
                { "workspacesOut", 0, 0,    "default" },
                { "zoomFactor",    1, 7,    "quick" },
              },
            },
            dwindle = { preserve_split = true },
            master = { new_status = "master" },
            xwayland = { force_zero_scaling = true },
            misc = {
              force_default_wallpaper = 0,
              disable_hyprland_logo = true,
            },
            input = {
              kb_layout = "us",
              follow_mouse = 1,
              sensitivity = 0,
              touchpad = { natural_scroll = false },
            },
          })

          hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
          hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

          ---------------------
          -- -- KEYBINDINGS -- --
          ---------------------
          local mainMod = "SUPER"

          hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("[float] " .. terminal))
          hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(tmux))
          hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(sleepScreen))
          hl.bind(mainMod .. " + C", hl.dsp.window.close())
          hl.bind(mainMod .. " + escape", hl.dsp.exec_cmd(systemManager))
          hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
          hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("[float] " .. fileManager))
          hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
          hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(menu))
          hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
          hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(screenSnip))
          hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd(screenShot))
          ${lib.optionalString (!hasPrintKey) ''
            -- no Print key (host.keyboard.hasPrintKey = false): Super+Shift+S = area snip
            hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(screenSnip))
          ''}

          hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(brightnessU), { repeating = true, locked = true })
          hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(brightnessD), { repeating = true, locked = true })
          hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(volumeU), { repeating = true, locked = true })
          hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(volumeD), { repeating = true, locked = true })
          hl.bind("XF86AudioMute", hl.dsp.exec_cmd(muteAudio), { locked = true })
          hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(muteMic), { locked = true })

          hl.bind("XF86AudioNext", hl.dsp.exec_cmd("${playerctlCmd} next"), { locked = true })
          hl.bind("XF86AudioPause", hl.dsp.exec_cmd("${playerctlCmd} play-pause"), { locked = true })
          hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("${playerctlCmd} play-pause"), { locked = true })
          hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("${playerctlCmd} previous"), { locked = true })

          hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
          hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
          hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
          hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

          for i = 1, 9 do
            hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
            hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
          end
          hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))
          hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

          hl.bind(mainMod .. " + M", hl.dsp.workspace.toggle_special("magic"))
          hl.bind(mainMod .. " + SHIFT + M", hl.dsp.window.move({ workspace = "special:magic" }))

          hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
          hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

          hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
          hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

          --------------------------
          -- -- WORKSPACE RULES -- --
          --------------------------
          hl.workspace_rule({ workspace = "1", monitor = "eDP-1", default = true })
          for w = 2, 5 do
            hl.workspace_rule({ workspace = tostring(w), monitor = "eDP-1" })
          end

          -- External monitors (anything but the internal panel) get workspace
          -- blocks left-to-right: 1st external 6-10, 2nd 11-15, 3rd 16-20, ...
          -- so swapping the Framework expansion-card port (DP-1/DP-2/...) or
          -- adding a second display still works. Re-applied on every hotplug;
          -- pcall keeps a Lua error here from aborting the rest of the config.
          local function assign_external_workspaces()
            pcall(function()
              local externals = {}
              for _, m in ipairs(hl.get_monitors()) do
                if m.name ~= "eDP-1" then
                  table.insert(externals, m)
                end
              end
              table.sort(externals, function(a, b)
                if a.x ~= b.x then return a.x < b.x end
                return a.name < b.name
              end)
              for i, m in ipairs(externals) do
                local first = 6 + (i - 1) * 5
                hl.workspace_rule({ workspace = tostring(first), monitor = m.name, default = true })
                for w = first + 1, first + 4 do
                  hl.workspace_rule({ workspace = tostring(w), monitor = m.name })
                end
              end
            end)
          end
          assign_external_workspaces()
          hl.on("monitor.added", assign_external_workspaces)
          hl.on("monitor.removed", assign_external_workspaces)

          -- Lid: logind ignores it (network.nix) so SSH survives; this decides the panel.
          hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("${lidScript}"), { locked = true })
          hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("${lidScript}"), { locked = true })
          hl.on("monitor.added", function() hl.exec_cmd("${lidScript}") end)
          hl.on("monitor.removed", function() hl.exec_cmd("${lidScript}") end)

          hl.workspace_rule({ workspace = "special:magic", gaps_out = { top = 40, right = 250, bottom = 40, left = 250 } })

          --------------------------
          -- -- LAYER RULES -- --
          --------------------------
          hl.layer_rule({
            name = "noctalia",
            match = {
              namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
            },
            no_anim = true,
            ignore_alpha = 0.5,
            blur = true,
            blur_popups = true,
          })

          -----------------------
          -- -- WINDOW RULES -- --
          -----------------------
          hl.window_rule({
            name = "special_workspace_window",
            match = { initial_class = "^(com\\.special\\.window)$" },
            workspace = "special:magic",
          })

          hl.window_rule({
            name = "otter_launcher_rule",
            match = { initial_class = "^(com\\.otter\\.launcher)$" },
            float = true,
            center = true,
            size = { 550, 250 },
            stay_focused = true,
            focus_on_activate = false,
          })

          hl.window_rule({
            name = "termfilechooser_rule",
            match = { initial_class = "^termfilechooser$" },
            float = true,
            center = true,
            size = { 1000, 650 },
          })

          hl.window_rule({
            name = "center_focus_rule",
            match = { initial_class = "^(com\\.center\\.focus)$" },
            float = true,
            center = true,
            size = { 900, 600 },
          })

          hl.window_rule({
            name = "paraview_file_dialog",
            match = { class = "^paraview$", title = "^Open File.*" },
            center = true,
          })

          hl.window_rule({
            name = "suppress-maximize-events",
            match = { class = ".*" },
            suppress_event = "maximize",
          })

          hl.window_rule({
            name = "fix-xwayland-drags",
            match = {
              class = "^$",
              title = "^$",
              xwayland = true,
              float = true,
              fullscreen = false,
              pin = false,
            },
            no_focus = true,
          })

          hl.window_rule({
            name = "move-hyprland-run",
            match = { class = "hyprland-run" },
            move = { 20, "monitor_h-120" },
            float = true,
          })
        '';
      };
    };
}
