#!/bin/bash

PIXIE="/usr/share/sddm/themes/pixie/assets/background.jpg"
WALLPAPER="$(noctalia msg wallpaper-get)"

if [ -f "$WALLPAPER" ]; then
    sudo magick "$WALLPAPER" "$PIXIE"
fi
