{ config, pkgs, ... }:

{
  # ==========================================================================
  # SHOWOFF — Magic Workspace Sleep Screen
  # ==========================================================================
  # Three scripts baked into Nix derivations via writeShellApplication.
  # runtimeInputs guarantees all dependencies are in PATH at evaluation time.
  # Config files (hypridle, tmux showoff) delivered via xdg.configFile.

  xdg.configFile = {
    # Hypridle triggers showoff after 300s of inactivity
    "hypr/hypridle.conf".text = ''
      listener {
          timeout = 300
          on-timeout = showoff --idle
      }
    '';

    # Tmux config for the isolated showoff session (no status bar, true color, fast escape)
    "tmux/showoff.conf".text = ''
      # 1. Internal Color Space
      # Forces tmux to allocate a 256-color matrix for its nested panes rather than the 8-color screen default.
      set -g default-terminal "tmux-256color"

      # 2. True Color (RGB) Override
      # Maps 24-bit color support to the external Wayland surface. Ghostty typically advertises
      # its $TERM as either ghostty or xterm-256color depending on shell integration.
      set -ag terminal-overrides ",xterm-256color:RGB"
      set -ag terminal-overrides ",ghostty:RGB"

      # 3. UI Minimalism
      # Destroys the persistent green status bar at the bottom of the window.
      set -g status off

      # 4. Input Latency Mitigation
      # Tmux inherently delays the ESC key by 500ms to evaluate complex keybindings.
      # This must be zeroed to prevent input lag when navigating TUI applications like btop.
      set -sg escape-time 0

      # Inactive pane border color (e.g., arch blue)
      set -g pane-border-style fg="#1793d1"

      # Active pane border color (e.g., arch blue)
      set -g pane-active-border-style fg="#1793d1"
    '';
  };

  home.packages = with pkgs; [
    # ========================================================================
    # SHOWOFF SCRIPTS (Nix-native, fully declarative)
    # ========================================================================

    # Main toggle/idle/kill dispatcher
    (writeShellApplication {
      name = "showoff";
      runtimeInputs = [ jq tmux hyprland procps ];
      text = ''
        TERMINAL="ghostty"
        WORKSPACE_PRI="special:showoff"
        WORKSPACE_SEC="special:showoff_sec"

        # 1. Hardware Matrix Detection
        ACTIVE_MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
        MON_COUNT=$(hyprctl monitors -j | jq length)
        MON_PRIMARY=$(hyprctl monitors -j | jq -r '.[0].name')

        if [ "$MON_COUNT" -gt 1 ]; then
          MON_SECONDARY=$(hyprctl monitors -j | jq -r '.[1].name')
        fi

        kill_showoff() {
          hyprctl dispatch 'hl.dsp.submap("reset")'

          if pgrep -f "$TERMINAL --class=showoff-" >/dev/null; then
            # Toggle primary off if visible
            if [ "$(hyprctl monitors -j | jq -r '.[] | select(.name == "'"$MON_PRIMARY"'") | .specialWorkspace.name')" == "$WORKSPACE_PRI" ]; then
              hyprctl dispatch "hl.dsp.focus({ monitor = \"$MON_PRIMARY\" })"
              hyprctl dispatch 'hl.dsp.workspace.toggle_special("showoff")'
            fi

            # Toggle secondary off if visible
            if [ "$MON_COUNT" -gt 1 ]; then
              if [ "$(hyprctl monitors -j | jq -r '.[] | select(.name == "'"$MON_SECONDARY"'") | .specialWorkspace.name')" == "$WORKSPACE_SEC" ]; then
                hyprctl dispatch "hl.dsp.focus({ monitor = \"$MON_SECONDARY\" })"
                hyprctl dispatch 'hl.dsp.workspace.toggle_special("showoff_sec")'
              fi
            fi

            # Restore original input focus
            hyprctl dispatch "hl.dsp.focus({ monitor = \"$ACTIVE_MONITOR\" })"

            sleep 0.1

            pkill -f "$TERMINAL --class=showoff-"
            # Explicitly destroy the isolated tmux server and its socket
            tmux -L showoff_socket kill-server 2>/dev/null
            pkill -f "showoff_watcher"
          fi
          exit 0
        }

        # 2. Strict Argument Routing
        if [[ "''${1:-}" == "--kill" ]]; then
          kill_showoff
        fi

        if pgrep -f "$TERMINAL --class=showoff-" >/dev/null; then
          if [[ "''${1:-}" == "--idle" ]]; then
            exit 0
          else
            kill_showoff
          fi
        fi

        # 3. Targeted Spawning
        # Explicitly force the primary dashboard to the primary display
        hyprctl dispatch "hl.dsp.exec_cmd(\"$TERMINAL --class=showoff-dash --background-opacity=0.7 -e showoff-layout\", { workspace = \"$WORKSPACE_PRI\", monitor = \"$MON_PRIMARY\" })"

        # If a secondary display is connected, spawn the rotator maximized on its own special workspace
        if [ "$MON_COUNT" -gt 1 ]; then
          hyprctl dispatch "hl.dsp.exec_cmd(\"$TERMINAL --class=showoff-sec --background-opacity=0.7 -e term-rotator\", { workspace = \"$WORKSPACE_SEC\", monitor = \"$MON_SECONDARY\" })"
        fi

        # 4. Synchronous Render Polling & Toggling
        for _ in {1..20}; do
          if hyprctl clients -j | jq -e '.[] | select(.workspace.name == "'"$WORKSPACE_PRI"'")' >/dev/null; then

            # Deploy Primary
            if [ "$(hyprctl monitors -j | jq -r '.[] | select(.name == "'"$MON_PRIMARY"'") | .specialWorkspace.name')" != "$WORKSPACE_PRI" ]; then
              hyprctl dispatch "hl.dsp.focus({ monitor = \"$MON_PRIMARY\" })"
              hyprctl dispatch 'hl.dsp.workspace.toggle_special("showoff")'
            fi

            # Deploy Secondary
            if [ "$MON_COUNT" -gt 1 ]; then
              if [ "$(hyprctl monitors -j | jq -r '.[] | select(.name == "'"$MON_SECONDARY"'") | .specialWorkspace.name')" != "$WORKSPACE_SEC" ]; then
                hyprctl dispatch "hl.dsp.focus({ monitor = \"$MON_SECONDARY\" })"
                hyprctl dispatch 'hl.dsp.workspace.toggle_special("showoff_sec")'
              fi
            fi

            # Restore original focus before intercepting inputs
            hyprctl dispatch "hl.dsp.focus({ monitor = \"$ACTIVE_MONITOR\" })"
            break
          fi
          sleep 0.1
        done

        # 5. Global Input Interception
        hyprctl dispatch 'hl.dsp.submap("showoff_idle")'

        (
          exec -a showoff_watcher bash -c '
            sleep 0.5
            INITIAL_POS=$(hyprctl cursorpos)

            while true; do
                CURRENT_POS=$(hyprctl cursorpos)
                if [ "$INITIAL_POS" != "$CURRENT_POS" ]; then
                    showoff --kill
                    exit 0
                fi
                sleep 0.1
            done
            '
        ) &
        disown
      '';
    })

    # Tmux grid layout for the primary monitor dashboard
    (writeShellApplication {
      name = "showoff-layout";
      runtimeInputs = [ tmux jq ];
      text = ''
        SESSION="showoff"
        SOCKET="showoff_socket"
        CONF="$HOME/.config/tmux/showoff.conf"

        if ! tmux -L "$SOCKET" has-session -t "$SESSION" 2>/dev/null; then
          tmux -L "$SOCKET" -f "$CONF" new-session -d -s "$SESSION"

          # 1. Primary X-Axis Split -> [0: Left], [1: Right]
          tmux -L "$SOCKET" split-window -h -p 50

          # 2. Right Column Y-Axis Split -> [1: Rotator], [2: Btop]
          tmux -L "$SOCKET" select-pane -t 1
          tmux -L "$SOCKET" split-window -v -p 55

          # 3. Left Column Bottom Split -> [0: Left Top], [1: Cava]
          # (Indices 1 and 2 shift to 2 and 3)
          tmux -L "$SOCKET" select-pane -t 0
          tmux -L "$SOCKET" split-window -v -p 23

          # 4. Left Column Middle Split -> [0: Left Top], [1: Fastfetch]
          # Allocating 75% to the new bottom pane leaves a safe 25% for the clock above it
          # (Indices shift again)
          tmux -L "$SOCKET" select-pane -t 0
          tmux -L "$SOCKET" split-window -v -p 95

          # 5. Left Column Top-Most X-Axis Split -> [0: Clock], [1: Gping]
          tmux -L "$SOCKET" select-pane -t 0
          tmux -L "$SOCKET" split-window -h -p 95

          # FINAL INDEX MAP:
          # 0: Top-Left (Clock)
          # 1: Top-Right (Gping)
          # 2: Middle-Left (Fastfetch)
          # 3: Bottom-Left (Cava)
          # 4: Top-Right Column (Rotator)
          # 5: Bottom-Right Column (Btop)

          # Dispatch execution strings safely to the finalized grid
          tmux -L "$SOCKET" send-keys -t 0 "exec tty-clock -t -B -s -C 5" C-m
          tmux -L "$SOCKET" send-keys -t 1 "exec gping 1.1.1.1" C-m
          tmux -L "$SOCKET" send-keys -t 2 "exec sh -c 'clear && fastfetch --structure-disabled colors && sleep infinity'" C-m
          tmux -L "$SOCKET" send-keys -t 3 "exec cava" C-m
          tmux -L "$SOCKET" send-keys -t 4 "exec sh -c 'clear && term-rotator'" C-m
          tmux -L "$SOCKET" send-keys -t 5 "exec btop" C-m
        fi

        tmux -L "$SOCKET" attach-session -t "$SESSION"
      '';
    })

    # Cycles through terminal art apps on the secondary monitor
    (writeShellApplication {
      name = "term-rotator";
      runtimeInputs = [
        cmatrix cbonsai asciiquarium-transparent sl lolcat
        pipes cowsay
        coreutils gawk
      ];
      text = ''
        export TERM=xterm-256color

        APPS=(
          "cmatrix -f -a -B"
          "cbonsai -l --leaf='#,&,%'"
          "asciiquarium -t"
          "sl -a -c -e | lolcat 0.0001"
          "pipes.sh -p 4 -t 3 -R -r 0"
          "echo 'Hello World!' | cowsay -f tux | lolcat && sleep infinity"
        )

        while true; do
          # 1. Ingest the randomized null-delimited strings into SHUFFLED_APPS
          mapfile -t -d $'\0' SHUFFLED_APPS < <(printf "%s\0" "''${APPS[@]}" | shuf -z)

          # 2. Iterate over the new array. The loop's stdin remains attached to the terminal.
          for app in "''${SHUFFLED_APPS[@]}"; do
            bin=$(echo "$app" | awk '{print $1}')

            if command -v "$bin" >/dev/null 2>&1; then
              timeout --foreground 15s bash -c "$app" || true
            else
              sleep 2
            fi
            clear
          done
        done
      '';
    })
  ];
}
