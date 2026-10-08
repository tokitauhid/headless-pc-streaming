-- Hyprland Monitor Configuration (Lua format, v0.55+)
-- This configures both the physical and virtual headless monitor.
--
-- The HDMI-A-1 entry is for when a physical monitor IS plugged in.
-- The HEADLESS-1 entry is the virtual monitor Sunshine captures.
-- When booting headless, only HEADLESS-1 will be active.
--
-- hyprlang equivalent:
--   monitor=HDMI-A-1,2560x1440@120.0,1920x0,1.0,vrr,0
--   monitor=HEADLESS-1,2560x1440@120.0,4480x0,1.0,vrr,0

hl.monitor({
    output = "HDMI-A-1",
    mode = "2560x1440@120.0",
    position = "1920x0",
    scale = 1.0,
    vrr = 0
})

hl.monitor({
    output = "HEADLESS-1",
    mode = "2560x1440@120.0",
    position = "4480x0",
    scale = 1.0,
    vrr = 0
})
