# otter-apps — XDG desktop-file picker with fzf + icon preview.
# Consumed by writeShellApplication in otter.nix (runtimeInputs declare fzf,
# chafa, gawk, grep, coreutils, util-linux). Kept as a data file so the
# command logic stays reviewable outside the Nix wrapping.
shopt -s nullglob

US=$'\x1f'

data_dirs=("${XDG_DATA_HOME:-$HOME/.local/share}")
IFS=: read -ra _xdg <<< "${XDG_DATA_DIRS:-}"
for d in "${_xdg[@]}"; do [ -n "$d" ] && data_dirs+=("$d"); done

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/otter-launcher"
CACHE="$CACHE_DIR/apps.tsv"

resolve_icon_path() {
  local name="${1:-}" base d path
  [ -f "$name" ] && echo "$name" && return 0
  base="${name##*/}"
  [ -z "$base" ] && return 1
  for ext in .png .svg .xpm .jpg .jpeg .ico; do base="${base%"$ext"}"; done
  [ -z "$base" ] && return 1
  for d in "${data_dirs[@]}"; do
    [ -d "$d/icons" ] || continue
    path="$d/icons/hicolor/scalable/apps/$base.svg"
    [ -f "$path" ] && echo "$path" && return 0
    for size in 256 128 512 96 64 48 32 22 16; do
      path="$d/icons/hicolor/${size}x${size}/apps/$base.png"
      [ -f "$path" ] && echo "$path" && return 0
    done
    path="$d/icons/Adwaita/scalable/apps/$base.svg"
    [ -f "$path" ] && echo "$path" && return 0
  done
  return 1
}

# Emit the sorted app list. Reuses ~/.cache/otter-launcher/apps.tsv when it is
# fresh (no .desktop file newer than it); otherwise rebuilds it. The scan+sort
# (~70-100ms) then only happens once per desktop-file change instead of on
# every keystroke (~2ms cache read).
list() {
  local files=("$@")
  if [ -f "$CACHE" ] && [ "${#files[@]}" -gt 0 ] \
     && ! find "${files[@]}" -newer "$CACHE" 2>/dev/null | grep -q .; then
    cat "$CACHE"
    return 0
  fi
  mkdir -p "$CACHE_DIR"
  awk -v US="$US" '
    function emit() {
      # Skip btop+ (the btop fork): btop is the installed monitor, and listing
      # both would show two btop instances in the picker.
      if (name && exec && nd != "true" && name !~ /^btop\+/) {
        gsub(/ ?%[cDdFfikmNnUuv]/, "", exec)
        print name US exec US icon
      }
      name = exec = icon = nd = ""; active = 0
    }
    FNR == 1 { if (NR > 1) emit() }
    /^\[Desktop Entry\]/ { active = 1; next }
    /^\[Desktop Action/ { active = 0; next }
    # waypaper is CLI-only here (driven by the theme engine); its GUI desktop
    # entry is intentionally excluded from the app picker.
    active && FILENAME ~ /waypaper\.desktop$/ { next }
    active && /^Name=/      { name = substr($0, index($0,"=")+1); next }
    active && /^Exec=/      { exec = substr($0, index($0,"=")+1); next }
    active && /^Icon=/      { icon = substr($0, index($0,"=")+1); next }
    active && /^NoDisplay=/ { nd   = substr($0, index($0,"=")+1); next }
    END { emit() }
  ' "${files[@]}" | LC_ALL=C sort -t"$US" -k1,1 -u | tee "$CACHE"
}

PREVIEW=false
REFRESH=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --preview) PREVIEW=true; shift ;;
    --refresh-cache) REFRESH=true; shift ;;
    --icon-path) shift; resolve_icon_path "${1:-}"; exit $? ;;
    *) break ;;
  esac
done
query="$*"

files=()
for d in "${data_dirs[@]}"; do files+=("$d"/applications/*.desktop); done

if $REFRESH; then
  list "${files[@]}" >/dev/null
  exit 0
fi

if $PREVIEW; then
  # shellcheck disable=SC2016 # fzf expands {} / $FZF_* itself (not bash)
  choice=$(list "${files[@]}" | fzf -q "$query" -1 -0 \
    --delimiter="$US" \
    --with-nth=1 \
    --preview 'p=$(otter-apps --icon-path {3}); [ -n "$p" ] && chafa -f symbols -s 18x18 "$p" || echo "  no icon"' \
    --preview-window=left:20,noinfo \
    --info-command 'printf "apps ($FZF_POS/$FZF_TOTAL_COUNT)"' \
    --color "info:8,separator:8" \
    --prompt '   >> ' \
    --cycle)
else
  choice=$(list "${files[@]}" | fzf -q "$query" --delimiter="$US" --with-nth=1)
fi

if [ -n "$choice" ]; then
  cmd="${choice#*"$US"}"
  cmd="${cmd%%"$US"*}"
  [ -n "$cmd" ] && setsid -f sh -c "$cmd" </dev/null >/dev/null 2>&1
fi
