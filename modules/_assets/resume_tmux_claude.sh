#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./resume_tmux_claude.sh "<target_time>" "<target_pane>" [optional_prompt]
#
# Examples:
#   ./resume_tmux_claude.sh "23:45:00" "dev:0.0"
#   ./resume_tmux_claude.sh "02:15:00" "claude" "Proceed with running the test suite."

TARGET_TIME_STR="${1:?Error: Target timestamp required (e.g., '23:45:00' or '2026-10-23 02:00:00')}"
TMUX_TARGET="${2:?Error: Tmux target required (e.g., 'session:window.pane' or 'session')}"
PROMPT="${3:-Continue from where we left off. Resume the pending implementation and run tests.}"

# Validate target tmux pane exists
if ! tmux has-session -t "$TMUX_TARGET" 2>/dev/null; then
    echo "Error: Target tmux session/pane '$TMUX_TARGET' does not exist." >&2
    exit 1
fi

TARGET_EPOCH=$(date -d "$TARGET_TIME_STR" +%s)
NOW_EPOCH=$(date +%s)

# Roll over to tomorrow if time-only string is earlier today
if (( TARGET_EPOCH <= NOW_EPOCH )); then
    if [[ ! "$TARGET_TIME_STR" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        TARGET_EPOCH=$(date -d "tomorrow $TARGET_TIME_STR" +%s)
    else
        echo "Error: Target timestamp ($TARGET_TIME_STR) is in the past." >&2
        exit 1
    fi
fi

SLEEP_SECONDS=$(( TARGET_EPOCH - NOW_EPOCH ))

printf "Current time:       %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
printf "Target restoration: %s (in %d seconds)\n" "$(date -d "@$TARGET_EPOCH" '+%Y-%m-%d %H:%M:%S')" "$SLEEP_SECONDS"
printf "Injecting to tmux:  %s\n" "$TMUX_TARGET"

sleep "$SLEEP_SECONDS"

printf "[%s] Waking up. Verifying pane and injecting keys...\n" "$(date '+%Y-%m-%d %H:%M:%S')"

if ! tmux has-session -t "$TMUX_TARGET" 2>/dev/null; then
    echo "Error: Tmux target '$TMUX_TARGET' disappeared during wait." >&2
    exit 1
fi

# Send prompt characters literally using -l, then dispatch carriage return
tmux send-keys -t "$TMUX_TARGET" -l "$PROMPT"
tmux send-keys -t "$TMUX_TARGET" Enter

printf "[%s] Successfully sent resume command to '%s'.\n" "$(date '+%Y-%m-%d %H:%M:%S')"
