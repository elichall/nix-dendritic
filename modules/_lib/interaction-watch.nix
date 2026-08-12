# Shared pointer-interaction watcher (DRY source for showoff + otter-launcher).
#
# Imported from feature modules via `import ../_lib/interaction-watch.nix
# { inherit pkgs; }` — same convention as _lib/browser.nix / _lib/theme.nix.
# Kept out of the import-tree because it defines no `flake.modules.*`.
#
# The script is deliberately process-agnostic (modelled on the showoff watcher,
# which works) rather than the otter dismiss-on-pointer pattern (which does
# not): it never relies on grepping a specific process cmdline to decide when
# to act. Consumers spawn it at the moment their surface appears, and it fires
# a caller-supplied callback the first time the pointer moves.
#
# Interface:
#   interaction-watch [--tag NAME] [--grace SECS] [--interval SECS]
#                     [--bail-pattern REGEX] --on-move CMD
#   --tag NAME        Marks the process cmdline as `interaction-watch --tag
#                     NAME` so consumers can reap it via
#                     `pkill -f "interaction-watch --tag NAME"`.
#   --grace SECS      Delay before the reference cursor position is captured
#                     (default 0.5; lets the window settle so the pointer is
#                     not mistaken for "moved" during spawn).
#   --interval SECS   Poll interval for `hyprctl cursorpos` (default 0.1).
#   --bail-pattern    Optional pgrep -f regex: exit without firing when nothing
#                     matches (e.g. the watched surface was closed by ESC).
#   --bail-comm       Optional pgrep -x comm: exact-match alternative to
#                     --bail-pattern. Unlike a regex it can never match this
#                     watcher's own cmdline. Either or both may be given; the
#                     first check that reports the surface gone ends the watch.
#   --on-move CMD     Shell command run via `sh -c` on the first pointer move
#                     (required). Afterwards the watcher exits.
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
