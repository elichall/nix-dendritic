# ==========================================================================
# HYPRLAND DESKTOP ENVIRONMENT
# ==========================================================================
# System-scale (NixOS): compositor + portal wiring. User-scale (Home
# Manager): session tooling + the full user config (keybinds, autostart,
# workspace/window rules), ported from legacy modules/hyprland.nix.
#
# PATH STRATEGY (Phase 3): user-scope binaries are referenced by absolute
# store path because the graphical session does not reliably carry the
# Home Manager profile on PATH. System-scope binaries (wpctl via
# wireplumber, hyprctl via the compositor, systemctl, bash, flatpak) stay
# PATH-based. Module-owned wrappers (otter-open/otter-power/otter-apps,
# showoff) stay PATH-based until their focused passes land.
#
# AGENTS.md Rule 4: every binary referenced by keybinds/autostart is
# declared in home.packages here (duplicates across modules are allowed).
{ inputs, ... }: {
  flake.modules.nixos.hyprland = { pkgs, ... }: {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      withUWSM = false;
    };
  };

  flake.modules.homeManager.hyprland = { pkgs, ... }: let
    terminal = "${pkgs.ghostty}/bin/ghostty";
    tmuxCmd = "${terminal} -e ${pkgs.tmux}/bin/tmux new-session -A -s 'main'";
    menu = "otter-open";
    browser = (import ../_lib/browser.nix).command;

    brightnessU = "${pkgs.brightnessctl}/bin/brightnessctl set 5%+";
    brightnessD = "${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
    volumeU = "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+";
    volumeD = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
    muteAudio = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
    muteMic = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";

    screenSnip = "${pkgs.grimblast}/bin/grimblast copysave area";
    screenShot = "${pkgs.grimblast}/bin/grimblast copysave screen";
    fileManager = "${terminal} -e bash -ci '${pkgs.yazi}/bin/yazi; exit'";
    systemManager = "otter-power";

    waybarCmd = "${pkgs.waybar}/bin/waybar";
    wayEdges = "${pkgs.way-edges}/bin/way-edges";
    hypridleCmd = "${pkgs.hypridle}/bin/hypridle";
    otterApps = "otter-apps --refresh-cache";
    playerctlCmd = "${pkgs.playerctl}/bin/playerctl";
  in {
    home.packages = with pkgs; [
      hypridle
      grimblast
      brightnessctl
      ghostty
      tmux
      yazi
      waybar
      way-edges
      playerctl
    ];

    wayland.windowManager.hyprland = {
      enable = true;

      configType = "lua";

      systemd.enable = false;

      extraConfig = ''
        -- --- SINGLE SOURCE OF TRUTH COLOR LINKING ---
        local status, theme = pcall(require, "palette")
        if not status then
          theme = {
            accent = "rgb(74, 199, 236)",
            muted = "rgb(88, 91, 112)",
            bg = "rgb(17, 17, 27)"
          }
        end

        ------------------
        -- -- MONITORS -- --
        ------------------
        hl.monitor({ output = "DP-1", mode = "preferred", position = "auto", scale = 1 })
        hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1 })

        ---------------------
        -- -- MY PROGRAMS -- --
        ---------------------
        local terminal = "${terminal}"
        local tmux = "${tmuxCmd}"
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

        -------------------
        -- -- AUTOSTART -- --
        -------------------
        hl.on("hyprland.start", function()
          hl.exec_cmd("${waybarCmd}")
          hl.exec_cmd("${wayEdges}")
          hl.exec_cmd("${hypridleCmd}")
          hl.exec_cmd("${otterApps}")
          hl.exec_cmd("bash -c 'systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP NIXOS_OZONE_WL && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP NIXOS_OZONE_WL && systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal'")
          -- Persistent headless ghostty server for the otter-launcher. Kept alive
          -- so `ghostty +new-window --class=com.otter.launcher` opens near-instantly.
          hl.exec_cmd("${terminal} --class=com.otter.launcher --initial-window=false --quit-after-last-window-closed=false --gtk-single-instance=true")
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
        hl.bind(mainMod .. " + C", hl.dsp.window.close())
        hl.bind(mainMod .. " + escape", hl.dsp.exec_cmd(systemManager))
        hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
        hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("[float] " .. fileManager))
        hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
        hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(menu))
        hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
        hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(screenSnip))
        hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd(screenShot))

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

        ------------------
        -- -- SUBMAPS -- --
        ------------------
        hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("showoff"))

        hl.define_submap("showoff_idle", function()
          hl.bind("catchall", hl.dsp.exec_cmd("showoff --kill"))
          hl.bind("mouse:272", hl.dsp.exec_cmd("showoff --kill"), { mouse = true })
          hl.bind("mouse:273", hl.dsp.exec_cmd("showoff --kill"), { mouse = true })
          hl.bind("mouse:274", hl.dsp.exec_cmd("showoff --kill"), { mouse = true })
          hl.bind("escape", hl.dsp.submap("reset"))
        end)

        --------------------------
        -- -- WORKSPACE RULES -- --
        --------------------------
        hl.workspace_rule({ workspace = "1", monitor = "eDP-1", default = true })
        for w = 2, 5 do
          hl.workspace_rule({ workspace = tostring(w), monitor = "eDP-1" })
        end

        hl.workspace_rule({ workspace = "6", monitor = "DP-2", default = true })
        for w = 7, 10 do
          hl.workspace_rule({ workspace = tostring(w), monitor = "DP-2" })
        end

        hl.workspace_rule({ workspace = "special:magic", gaps_out = { top = 40, right = 250, bottom = 40, left = 250 } })
        hl.workspace_rule({ workspace = "special:showoff" })
        hl.workspace_rule({ workspace = "special:showoff_sec" })

        -----------------------
        -- -- WINDOW RULES -- --
        -----------------------
        hl.window_rule({
          name = "waybar_tui_rule",
          match = { initial_class = "^(com\\.waybar\\.tui)$" },
          float = true,
          center = true,
          size = { 900, 600 },
        })

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
