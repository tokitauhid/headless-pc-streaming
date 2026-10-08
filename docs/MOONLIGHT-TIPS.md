# Moonlight Client Tips

Optimal settings for streaming from your headless PC.

---

## Recommended Settings

| Setting | Recommended Value | Notes |
|---------|-------------------|-------|
| Resolution | Match your monitor (e.g., 2560x1440) | Must match the headless monitor resolution on the PC |
| FPS | 120 | Match the headless monitor refresh rate |
| Video Bitrate | 50-80 Mbps | Gigabit LAN can handle up to ~150 Mbps easily |
| Video Codec | AV1 (Recommended)/HEVC (H.265) | RX 5700 XT supports HEVC but NOT AV1 |
| HDR | Off | Unless your monitor and GPU both support it |
| Audio | Stereo | Sunshine creates a virtual audio sink automatically |

---

## Important Keyboard Shortcuts

These work while you are connected to a stream:

| Shortcut | Action |
|----------|--------|
| `Ctrl + Alt + Shift + Z` | Toggle mouse capture / release mouse |
| `Ctrl + Alt + Shift + Z` | Toggle system keyboard shortcut passthrough |
| `Ctrl + Alt + Shift + M` | Toggle mouse mode (desktop ↔ game) |
| `Ctrl + Alt + Shift + Q` | Force quit the stream |

---

## Mouse Settings

### "Optimize mouse for remote desktop instead of games"
- **UNCHECK** this if you are gaming. It switches to relative mouse mode which games expect.
- **CHECK** this if you are doing desktop work. It uses absolute mouse positioning which feels more natural for desktop use.

### If right-click-drag doesn't work in a game
Press `Ctrl + Alt + Shift + M` to toggle mouse mode, or switch the game to Windowed mode. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#-right-click-drag-not-working-in-games) for the full explanation.

---

## Wake-on-LAN from Moonlight

1. Add your PC to Moonlight using its **local IP address**
2. Go to the PC's properties/settings in Moonlight
3. Enter the PC's **MAC address** (e.g., `2c:f0:5d:e7:81:eb`)
4. When the PC is powered off, clicking it in Moonlight will send a Wake-on-LAN magic packet
5. Wait ~15-20 seconds for the PC to boot and auto-login
6. Click again to connect to the stream

---

## Multi-Monitor Notes

If you have multiple headless monitors configured on the PC, Sunshine may not know which one to stream. You can select the specific monitor in Sunshine's web UI (`https://PC_IP:47990`) under Configuration → Video → Output Name. Set it to `HEADLESS-1` (or whatever your virtual monitor is named).
