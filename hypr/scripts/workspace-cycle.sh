#!/usr/bin/env bash

MAX=10
DIRECTION="$1"

CURRENT=$(hyprctl activeworkspace -j | jq -r '.id')

if [[ "$DIRECTION" == "next" ]]; then
  NEXT=$((CURRENT % MAX + 1))
else
  NEXT=$((CURRENT == 1 ? MAX : CURRENT - 1))
fi

hyprctl dispatch workspace "$NEXT"
