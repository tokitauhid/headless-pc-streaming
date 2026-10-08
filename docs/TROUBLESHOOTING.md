# Troubleshooting Guide

Every problem documented here was actually encountered during the setup process. These are real issues with real solutions.

---

## 🔴 Moonlight Can't Find/Connect to PC

### Symptom
Moonlight on the laptop doesn't see the PC, or shows it as offline.

### Causes & Fixes

**1. Sunshine isn't running**
```bash
# Check if Sunshine is running
systemctl --user status app-dev.lizardbyte.app.Sunshine.service

# If it's not running, start it
systemctl --user start app-dev.lizardbyte.app.Sunshine.service
```

**2. Stuck at login screen (most common after reboot)**
Sunshine is a **user service** — it only starts after you log in. If auto-login isn't configured, the PC sits at the login screen forever.

Fix: [Enable auto-login](SETUP.md#3-enable-auto-login)

**3. No virtual display exists**
Sunshine found zero screens to capture, so it's running but can't stream.

Check the Sunshine log:
```bash
tail -n 30 ~/.config/sunshine/sunshine.log
```
If you see:
```
[wlgrab] -------- Start of Wayland monitor list --------
[wlgrab] --------- End of Wayland monitor list ---------
```
That means there are zero monitors. The virtual headless display was never created.

Fix: [Create the virtual headless monitor](SETUP.md#4-create-the-virtual-headless-monitor)

**4. Display management tool wiped your monitor config**
Tools like `nwg-displays` can overwrite your monitor config and set `HEADLESS-1` to `disabled = true`, killing your headless setup.

Check your monitor config for lines like:
```
monitor=HEADLESS-1,disable
```
or in Lua:
```lua
hl.monitor({ output = "HEADLESS-1", disabled = true })
```

Fix: Remove the `disable`/`disabled` directive and restore the proper resolution config.

---

## 🔴 Stream is Connected but Frozen (Static Image)

### Symptom
Moonlight connects successfully but shows a single frozen frame that never updates.

### Causes & Fixes

**1. Multiple headless monitors confusing Sunshine**
If you accidentally created more than one headless output (HEADLESS-1, HEADLESS-2, etc.), Sunshine doesn't know which one to capture and the log will show:
```
[wlgrab] Selected monitor [] for streaming
```
Note the empty `[]` — it selected nothing.

Fix: Remove extra headless monitors and restart Sunshine:
```bash
# Hyprland
hyprctl output remove HEADLESS-2
systemctl --user restart app-dev.lizardbyte.app.Sunshine.service
```

**2. Monitor was hot-unplugged while streaming**
If you yanked the HDMI cable while Sunshine was actively capturing that physical display, the display ceases to exist and Sunshine freezes trying to capture a dead output.

Fix: This is exactly why we use a permanent headless virtual display. Never unplug a monitor that Sunshine is actively streaming. Reboot the PC to recover.

---

## 🔴 Unbearable Lag / Very Slow Stream

### Symptom
The stream is technically working but has extreme input lag or visual lag, even on a gigabit LAN.

### Cause
On headless (virtual) Wayland displays using wlroots-based compositors (Hyprland, Sway), the GPU attempts hardware cursor acceleration. Since there's no physical screen, this causes massive pipeline stalls.

### Fix
Disable hardware cursors:

**Hyprland:**
```
env = WLR_NO_HARDWARE_CURSORS,1
```
Or in Lua:
```lua
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
```

**Sway / Other wlroots:**
```bash
export WLR_NO_HARDWARE_CURSORS=1
```

> This requires a full session restart (reboot or re-login) to take effect.

---

## 🔴 Top Bar / Status Bar Not Visible

### Symptom
Your desktop streams fine but the status bar (waybar, noctalia-shell, etc.) is missing.

### Cause
The bar is configured to only show on your old physical monitor name (e.g., `HDMI-A-1`). Since you're now streaming from `HEADLESS-1`, the bar doesn't appear.

### Fix
Update your bar's configuration to include `HEADLESS-1` in its monitor list.

**Noctalia:** Edit `~/.config/noctalia/settings.json` and update monitor references.

**Waybar:** Edit `~/.config/waybar/config` and set:
```json
"output": ["HEADLESS-1"]
```
Or remove the `output` field entirely to show on all monitors.

---

## 🔴 Keyboard Shortcuts Don't Work While Streaming

### Symptom
Your desktop keybinds (Super key, Alt-Tab, etc.) don't work when streaming via Moonlight.

### Fix
By default, Moonlight intercepts system keyboard shortcuts so they control the laptop instead of the remote PC.

**Toggle system shortcuts:** Press `Ctrl + Alt + Shift + Z` while in the stream.

**Permanent fix:** In Moonlight settings, enable **"Capture system keyboard shortcuts"**.

---

## 🔴 Mouse Stuck / Can't Release Mouse from Moonlight

### Fix
Press `Ctrl + Alt + Shift + Z` to toggle mouse capture.

If that doesn't work, press `Ctrl + Alt + Shift + Q` to force-quit the stream.

---

## 🔴 Right-Click Drag Not Working in Games

### Symptom
In games like Timberborn where you right-click-drag to move the camera, the first drag works but subsequent drags fail.

### Cause
Wayland handles mouse pointer locks aggressively in fullscreen mode, which conflicts with how Moonlight sends relative mouse data.

### Fixes (try in order)

**1. Toggle mouse mode in Moonlight:**
Press `Ctrl + Alt + Shift + M` while in the stream to switch between desktop and game mouse mode.

**2. Switch the game to Windowed mode:**
Change the game's display setting from Fullscreen to Windowed. This avoids the Wayland pointer lock issue entirely.

**3. Fake borderless fullscreen via window rules (Hyprland):**
Leave the game in Windowed mode but use Hyprland window rules to strip borders and force it fullscreen:
```
windowrulev2 = float, class:^(steam_app_APPID)$
windowrulev2 = noborder, class:^(steam_app_APPID)$
windowrulev2 = minsize 2560 1440, class:^(steam_app_APPID)$
windowrulev2 = maxsize 2560 1440, class:^(steam_app_APPID)$
windowrulev2 = center, class:^(steam_app_APPID)$
windowrulev2 = norounding, class:^(steam_app_APPID)$
```
Replace `APPID` with the game's Steam App ID. Find the class name with `hyprctl clients`.

---

## 🔴 PC Goes to Sleep / Suspends During Streaming

### Symptom
The stream drops because the PC suspended itself due to idle timeout.

### Fix
Check your idle daemon config. For `hypridle`, look at `~/.config/hypr/hypridle.conf`. Increase or disable:
- DPMS off timeout (this turns off the virtual display and freezes the stream)
- Suspend timeout

See [SETUP.md Section 9](SETUP.md#9-disable-idlesuspend-while-streaming) for details.

---

## 🔴 `hyprctl output create HEADLESS-1` Silently Fails

### Symptom
The headless monitor is never created even though the command is in your startup config.

### Cause
The correct command is:
```bash
hyprctl output create headless      # ✅ correct (lowercase)
```

NOT:
```bash
hyprctl output create HEADLESS-1    # ❌ wrong — this is the output NAME, not the type
```

The first argument is the **backend type** (`headless`), not the monitor name. Hyprland automatically assigns the name `HEADLESS-1`, `HEADLESS-2`, etc.

---

## 🔴 AV1 Encoding Error in Sunshine Logs

### Symptom
Sunshine log shows:
```
[av1_vaapi @ ...] No usable encoding profile found.
Could not open codec [av1_vaapi]: Function not implemented
```

### Fix
This is harmless. The RX 5700 XT does not support AV1 hardware encoding. Sunshine automatically falls back to H.264 or HEVC (which the 5700 XT supports fine). The log even says:
```
// Ignore any errors mentioned above, they are not relevant. //
```

No action needed.
