#!/bin/bash

LAST=""

while true; do
  CURRENT="$(noctalia msg wallpaper-get 2>/dev/null)"

  if [ -n "$CURRENT" ] && [ "$CURRENT" != "$LAST" ] && [ -f "$CURRENT" ]; then
    ~/.config/noctalia/scripts/sync-pixie-wallpaper.sh
    LAST="$CURRENT"
  fi

  sleep 2
done
