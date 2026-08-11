#!/usr/bin/env bash
# dismiss-on-pointer — closes the otter-launcher the moment the pointer moves.
# The launcher runs inside a persistent ghostty single-instance server, so we
# must NOT pkill ghostty (that would kill the server). We kill the launcher
# process instead: the window closes naturally when its command exits, the
# cold-fallback ghostty instance quits entirely, and the server keeps running
# (quit-after-last-window-closed=false).
set -euo pipefail
LAUNCHER_PROC="/bin/otter-launcher"

# Wait for the launcher process to appear (pgrep is ~5ms vs ~65ms per hyprctl call)
for _ in {1..60}; do
  pgrep -f "$LAUNCHER_PROC" >/dev/null 2>&1 && break
  sleep 0.05
done

sleep 0.3
INITIAL_POS=$(hyprctl cursorpos)

while true; do
  # Launcher already closed by the user (ESC / ran a command) -> stop watching
  pgrep -f "$LAUNCHER_PROC" >/dev/null 2>&1 || exit 0
  sleep 0.2
  CURRENT_POS=$(hyprctl cursorpos)
  if [ "$INITIAL_POS" != "$CURRENT_POS" ]; then
    pkill -f "$LAUNCHER_PROC" >/dev/null 2>&1 || true
    exit 0
  fi
done
