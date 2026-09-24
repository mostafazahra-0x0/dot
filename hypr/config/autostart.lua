-- Auto-start config
hl.on("hyprland.start", function()
        hl.exec_cmd("dbus-update-activation-environment --systemd --all")
        hl.exec_cmd("noctalia -d")
        hl.exec_cmd("xhost +SI:localuser:root")
end)
