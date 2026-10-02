#!/bin/bash

STATE="$HOME/.cache/hypr-minimize"
mkdir -p "$STATE"

# If there is a minimized window, restore the most recently minimized one
if [ -f "$STATE/last" ]; then
  address=$(cat "$STATE/last")

  # Check that the window still exists
  if hyprctl clients -j | jq -e --arg addr "$address" \
    '.[] | select(.address == $addr)' >/dev/null; then

    workspace=$(cat "$STATE/$address")

    hyprctl dispatch movetoworkspace "$workspace,address:$address"
    hyprctl dispatch focuswindow "address:$address"

    rm -f "$STATE/last" "$STATE/$address"
    exit 0
  else
    rm -f "$STATE/last" "$STATE/$address"
  fi
fi

# Minimize the currently focused window
address=$(hyprctl activewindow -j | jq -r '.address')
workspace=$(hyprctl activewindow -j | jq -r '.workspace.id')

[ "$address" = "0x0" ] && exit 0

echo "$workspace" >"$STATE/$address"
echo "$address" >"$STATE/last"

hyprctl dispatch movetoworkspace "special:minimized"
