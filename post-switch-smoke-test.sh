#!/usr/bin/env bash
# ==========================================================================
# POST-SWITCH SMOKE TEST — run inside the graphical session after
#   sudo nixos-rebuild switch --flake ~/.nix#workstation
#
# Verifies the dendritic config replaced the static legacy /etc/nixos
# configuration: keybind targets on PATH, otter launcher health, theme
# engine state, hyprland/waybar wiring, and user unit status.
#
# Read-only. Exit code is non-zero if any check fails.
# ==========================================================================
set -u

FAIL=0
ok() { printf 'PASS  %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n== %s ==\n' "$1"; }

# `command -v` only searches PATH; the HM profile is on the session PATH.
have() { command -v "$1" >/dev/null 2>&1; }

section "1. Keybind targets / launcher binaries"
for bin in \
  otter-open otter-power otter-apps otter-diagnose otter-launch otter-launcher \
  showoff waybar way-edges hypridle hyprctl grimblast brightnessctl playerctl \
  waypaper awww theme ghostty tmux yazi nvim wlctl bluetui jolt btop gdu; do
  if have "$bin"; then ok "bin: $bin"; else bad "bin: $bin (missing from PATH)"; fi
done

section "2. otter-diagnose (menu dependency audit)"
if otter-diagnose >/tmp/otter-smoke-diagnose.log 2>&1; then
  ok "otter-diagnose: all dependencies present"
else
  bad "otter-diagnose: missing dependencies (see /tmp/otter-smoke-diagnose.log)"
  grep MISSING /tmp/otter-smoke-diagnose.log | head -20
fi

section "3. Otter config deployed"
CFG="$HOME/.config/otter-launcher/config.toml"
if [ -f "$CFG" ]; then
  ok "config: $CFG exists"
  if grep -q '@OVERLAY_IMAGE@' "$CFG"; then
    bad "config: unsubstituted @OVERLAY_IMAGE@ token remains"
  else
    ok "config: no stray tokens"
  fi
else
  bad "config: $CFG missing"
fi

section "4. Theme engine"
if [ -f "$HOME/.local/share/theme/active.json" ]; then
  ok "theme: active.json present"
  CURRENT=$(theme current 2>/dev/null || echo "?")
  ok "theme: current = ${CURRENT:-unset}"
else
  bad "theme: active.json missing (initTheme did not run)"
fi
for f in \
  "$HOME/.config/hypr/palette.lua" \
  "$HOME/.config/waybar/colors.css" \
  "$HOME/.config/tmux/colors.tmux" \
  "$HOME/.config/nvim/lua/lean/core/palette.lua" \
  "$HOME/.config/cava/themes/nixos-generated" \
  "$HOME/.config/gtk-3.0/gtk.css" \
  "$HOME/.config/gtk-4.0/gtk.css" \
  "$HOME/.local/share/theme/generated/ghostty/theme.conf"; do
  if [ -e "$f" ]; then ok "theme: $f"; else bad "theme: $f missing"; fi
done

section "5. Ghostty theme indirection"
GC="$HOME/.config/ghostty/config"
if [ -f "$GC" ]; then
  if grep -q '^config-file' "$GC"; then
    ok "ghostty: config-file indirection present"
  else
    bad "ghostty: no config-file line (theme reset on switch?)"
  fi
  if grep -q '^theme =' "$GC"; then
    bad "ghostty: static theme= line present (blocks runtime theme)"
  else
    ok "ghostty: no static theme= line"
  fi
else
  bad "ghostty: config missing"
fi

section "6. Hyprland wiring"
# Recent hyprland versions use a single Lua config file (hyprland.lua);
# older releases used hyprland.conf. Check whichever exists.
HL="$HOME/.config/hypr/hyprland.lua"
[ -f "$HL" ] || HL="$HOME/.config/hypr/hyprland.conf"
if [ -f "$HL" ]; then
  ok "hyprland: config found ($(basename "$HL"))"
  # Window-class regexes are written with Lua-escaped dots (com\\.waybar\\.tui);
  # strip backslashes so the checks match both the escaped and plain forms.
  HL_PLAIN="$(tr -d '\\' < "$HL")"
  for pat in "com.otter.launcher" "com.waybar.tui" "com.special.window" "showoff_idle"; do
    if grep -qF -- "$pat" <<<"$HL_PLAIN"; then ok "hyprland: $pat referenced"; else bad "hyprland: $pat missing"; fi
  done
else
  bad "hyprland: $HOME/.config/hypr/hyprland.{lua,conf} missing"
fi

section "7. Showoff wiring"
if [ -f "$HOME/.config/hypr/hypridle.conf" ]; then
  ok "hypridle: conf present"
else
  bad "hypridle: conf missing"
fi

section "8. Wallpaper + session services"
for unit in rclone-box; do
  if systemctl --user is-failed "$unit" >/dev/null 2>&1; then
    bad "unit: $unit in failed state"
  else
    ok "unit: $unit not failed"
  fi
done
if pgrep -x awww-daemon >/dev/null 2>&1; then
  ok "awww: daemon running"
else
  bad "awww: daemon not running"
fi
if [ -f "$HL" ] && grep -qF "waypaper --restore" "$HL"; then
  ok "hyprland: waypaper restore wired in autostart"
else
  bad "hyprland: waypaper restore not wired in autostart"
fi

section "9. Wallpapers"
COUNT=$(ls "$HOME/Pictures/Wallpapers" 2>/dev/null | wc -l)
if [ "$COUNT" -ge 17 ]; then
  ok "wallpapers: $COUNT present"
else
  bad "wallpapers: only $COUNT (expected >= 17)"
fi

printf '\n=== %d check(s) failed ===\n' "$FAIL"
exit "$FAIL"
