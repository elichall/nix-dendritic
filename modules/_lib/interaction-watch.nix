# Shared pointer-interaction watcher (DRY source for showoff + otter-launcher).
# Full interface spec: modules/_assets/documentation/module-contracts.md (C15).
# Usage: interaction-watch [--tag NAME] [--grace SECS] [--interval SECS]
#                          [--bail-pattern REGEX] [--bail-comm COMM] --on-move CMD
# Kept out of the import-tree because it defines no `flake.modules.*`.
{
  pkgs,
}:
pkgs.writeShellApplication {
  name = "interaction-watch";
  runtimeInputs = [
    pkgs.hyprland
    pkgs.coreutils
    pkgs.procps
  ];
  text = ''
    set -u

    TAG=""
    GRACE="0.5"
    INTERVAL="0.1"
    BAIL_PATTERN=""
    BAIL_COMM=""
    ON_MOVE=""

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --tag) TAG="''${2:-}"; shift 2 ;;
        --grace) GRACE="''${2:-0.5}"; shift 2 ;;
        --interval) INTERVAL="''${2:-0.1}"; shift 2 ;;
        --bail-pattern) BAIL_PATTERN="''${2:-}"; shift 2 ;;
        --bail-comm) BAIL_COMM="''${2:-}"; shift 2 ;;
        --on-move) ON_MOVE="''${2:-}"; shift 2 ;;
        *) echo "interaction-watch: unknown argument: $1" >&2; exit 1 ;;
      esac
    done

    if [ -z "$ON_MOVE" ]; then
      echo "interaction-watch: --on-move is required" >&2
      exit 1
    fi

    # TAG is intentionally not consumed by the script logic: it exists so the
    # process cmdline carries `--tag NAME`, letting consumers reap the watcher
    # with `pkill -f "interaction-watch --tag NAME"`. Read it to silence SC2034.
    : "''${TAG}"

    # Exit immediately when the watched surface is already gone. Either
    # configured check may trigger: exact comm match (--bail-comm, pgrep -x)
    # or cmdline regex (--bail-pattern, pgrep -f).
    bail() {
      if [ -n "$BAIL_COMM" ] && ! pgrep -x "$BAIL_COMM" >/dev/null 2>&1; then
        return 0
      fi
      if [ -n "$BAIL_PATTERN" ] && ! pgrep -f "$BAIL_PATTERN" >/dev/null 2>&1; then
        return 0
      fi
      return 1
    }

    sleep "$GRACE"
    if bail; then exit 0; fi

    initial=""
    while true; do
      current="$(hyprctl cursorpos 2>/dev/null || true)"
      if [ -n "$current" ]; then
        if [ -z "$initial" ]; then
          initial="$current"
        elif [ "$current" != "$initial" ]; then
          sh -c "$ON_MOVE" >/dev/null 2>&1 || true
          exit 0
        fi
      fi
      sleep "$INTERVAL"
      if bail; then exit 0; fi
    done
  '';
}
