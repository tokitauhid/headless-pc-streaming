#!/bin/bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export WAYLAND_DISPLAY=wayland-0

# Wait for KWin to finish initializing
sleep 2

# Ensure 2560x1440@120Hz custom mode exists on HDMI-A-1
kscreen-doctor output.HDMI-A-1.addCustomMode.2560.1440.120000.reduced 2>/dev/null || true

# Set active mode to 2560x1440@120
kscreen-doctor output.HDMI-A-1.mode.2560x1440@120 2>/dev/null || true

# Disable overlapping software virtual monitor if active
kscreen-doctor output.Virtual-Virtual-1.disable 2>/dev/null || true
