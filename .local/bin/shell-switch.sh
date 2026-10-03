#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/shell-switch/last"
mkdir -p "$(dirname "$STATE_FILE")"

TARGET="${1:-}"

# No argument = use last selected shell
if [[ -z "$TARGET" ]]; then
  if [[ -f "$STATE_FILE" ]]; then
    TARGET="$(cat "$STATE_FILE")"
  else
    TARGET="dms"
  fi
fi

if [[ "$TARGET" != "no" && "$TARGET" != "ca" && "$TARGET" != "ii" && "$TARGET" != "dms" ]]; then
  echo "Usage: shell-switch.sh [no|ca|ii|dms]"
  exit 1
fi

echo "Stopping all shells..."

# Stop DMS through systemd
systemctl --user stop dms.service 2>/dev/null || true

# Stop Noctalia
if pgrep -x "noctalia" >/dev/null; then
  pkill -x "noctalia" || true
fi

# Stop Caelestia
if pgrep -f "caelestia" >/dev/null; then
  caelestia shell -k 2>/dev/null || true
fi

# Stop ii
if pgrep -x "qs" >/dev/null; then
  pkill -x "qs" || true
fi

sleep 0.5

sync_apps_from_wallpaper() {
  # Re-render noctalia-managed app themes (kitty, ghostty, gtk noctalia.css,
  # obsidian snippet, ...) for the given wallpaper, even when the noctalia
  # daemon is stopped (e.g. Caelestia is active). Best-effort, never fails switch.
  local wall="${1:-}"
  if [[ -z "$wall" ]]; then
    return 0
  fi
  if [[ -x "$HOME/.local/bin/caelestia-noctalia-sync.sh" ]]; then
    "$HOME/.local/bin/caelestia-noctalia-sync.sh" "$wall" 2>&1 | tail -n 5 || true
  fi
}

caelestia_wallpaper() {
  local f="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/wallpaper/path.txt"
  [[ -f "$f" ]] && cat "$f" || true
}

noctalia_wallpaper() {
  python3 - "${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml" 2>/dev/null <<'PY' || true
import sys, tomllib
try:
    d = tomllib.load(open(sys.argv[1], 'rb'))
    print(d.get('wallpaper', {}).get('default', {}).get('path', ''))
except Exception:
    pass
PY
}

case "$TARGET" in
no)
  echo "Starting Noctalia..."
  noctalia -d
  # Continuity: adopt the Caelestia wallpaper so app colors don't jump,
  # then re-apply templates for the current palette.
  CAEL_WALL="$(caelestia_wallpaper)"
  if [[ -n "$CAEL_WALL" && -f "$CAEL_WALL" ]]; then
    for _ in $(seq 1 20); do
      if noctalia msg wallpaper-set "$CAEL_WALL" >/dev/null 2>&1; then
        break
      fi
      sleep 0.5
    done
  fi
  noctalia msg templates-apply >/dev/null 2>&1 || true
  ;;

ca)
  echo "Starting Caelestia..."
  # Force-refresh colors left stale by the Noctalia session. Re-applying the
  # *same* mode is a no-op in the CLI (setter early-returns: no save, no
  # regenerate, no apply), so flip to the opposite mode and back. Each leg
  # rewrites scheme.json (shell FileView event), regenerates dynamic colors
  # from the current wallpaper, re-applies app themes and fires the postHook
  # sync. Runs before the shell starts, so there is no visible light/dark
  # flash. First leg is silent so only one completion notification appears.
  CAEL_MODE_CUR="$(caelestia scheme get -m 2>/dev/null | tail -n 1 || true)"
  if [[ "$CAEL_MODE_CUR" == "dark" || "$CAEL_MODE_CUR" == "light" ]]; then
    if [[ "$CAEL_MODE_CUR" == "dark" ]]; then CAEL_MODE_TMP="light"; else CAEL_MODE_TMP="dark"; fi
    CAELESTIA_SYNC_NOTIFY=0 caelestia scheme set -m "$CAEL_MODE_TMP" >/dev/null 2>&1 || true
    caelestia scheme set -m "$CAEL_MODE_CUR" >/dev/null 2>&1 || true
  fi
  unset CAEL_MODE_CUR CAEL_MODE_TMP
  caelestia shell -d
  # Caelestia's own engine themes its set on wallpaper change, but not
  # noctalia's outputs — sync those too. Adopt noctalia's wallpaper for
  # continuity when it differs.
  NOCT_WALL="$(noctalia_wallpaper)"
  CAEL_WALL="$(caelestia_wallpaper)"
  if [[ -n "$NOCT_WALL" && -f "$NOCT_WALL" && "$NOCT_WALL" != "$CAEL_WALL" ]]; then
    caelestia wallpaper -f "$NOCT_WALL" >/dev/null 2>&1 || true
    # wallpaper postHook fires the sync async; also run once synchronously
    # so colors are correct even if hooks are disabled.
    sync_apps_from_wallpaper "$NOCT_WALL"
  else
    sync_apps_from_wallpaper "$CAEL_WALL"
  fi
  ;;

ii)
  echo "Starting ii..."
  qs -c ii
  # Keep app colors fresh even on shells without their own theming.
  sync_apps_from_wallpaper "$(caelestia_wallpaper)"
  ;;

dms)
  echo "Starting DankMaterialShell..."
  systemctl --user start dms.service
  sync_apps_from_wallpaper "$(caelestia_wallpaper)"
  ;;
esac

# Remember the selected shell
printf '%s\n' "$TARGET" >"$STATE_FILE"

echo "Switched to: $TARGET"
