-- Hyprland Startup Configuration (Lua format, v0.55+)
-- This runs once when Hyprland starts.
--
-- CRITICAL ORDER:
--   1. Create the headless output FIRST
--   2. Start Sunshine AFTER (so it can find the virtual display)
--
-- hyprlang equivalent:
--   exec-once = hyprctl output create headless
--   exec-once = systemctl --user start app-dev.lizardbyte.app.Sunshine.service

hl.on("hyprland.start", function()
    -- Create virtual headless display for Sunshine to capture
    -- NOTE: The command is "headless" (lowercase), NOT "HEADLESS-1"
    hl.exec_cmd("hyprctl output create headless")

    -- Start the streaming server (must come AFTER the display is created)
    hl.exec_cmd("systemctl --user start app-dev.lizardbyte.app.Sunshine.service")

    -- Idle daemon (optional)
    hl.exec_cmd("hypridle &")

    -- Polkit agent (required for GUI privilege escalation)
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || /usr/libexec/polkit-gnome-authentication-agent-1")
end)

-- Environment variables
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

-- IMPORTANT: Fixes unbearable lag when streaming a headless virtual display
hl.env("WLR_NO_HARDWARE_CURSORS", "1")

-- Qt / Electron settings
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
