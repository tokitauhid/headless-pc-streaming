# Complete Headless PC Streaming Setup Guide

This guide documents every step needed to turn a desktop PC into a headless streaming machine accessible from a laptop via Moonlight. It is written to be **distro-agnostic** with specific sections for different desktop environments.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install Sunshine](#2-install-sunshine)
3. [Enable Auto-Login](#3-enable-auto-login)
4. [Create the Virtual Headless Monitor](#4-create-the-virtual-headless-monitor)
5. [Configure Sunshine to Start on Boot](#5-configure-sunshine-to-start-on-boot)
6. [Fix Headless Cursor Lag](#6-fix-headless-cursor-lag)
7. [Wake-on-LAN Setup](#7-wake-on-lan-setup)
8. [Moonlight Client Setup](#8-moonlight-client-setup)
9. [Disable Idle/Suspend While Streaming](#9-disable-idlesuspend-while-streaming)
10. [Desktop-Specific Instructions](#10-desktop-specific-instructions)

---

## 1. Prerequisites

### On the Desktop PC (the host you stream FROM):
- Linux with a Wayland or X11 desktop environment
- A GPU with hardware video encoding (AMD VAAPI, NVIDIA NVENC, or Intel QSV)
- Gigabit Ethernet (highly recommended for low latency)
- No physical monitor needs to be plugged in

### On the Laptop (the client you stream TO):
- Moonlight client installed ([moonlight-stream.org](https://moonlight-stream.org))
- Connected to the same local network as the PC

---

## 2. Install Sunshine

Sunshine is the self-hosted game streaming server that Moonlight connects to.

### Fedora
```bash
# Sunshine is available via COPR or Flatpak
sudo dnf install -y sunshine
# OR
flatpak install flathub dev.lizardbyte.app.Sunshine
```

### Arch / CachyOS
```bash
sudo pacman -S sunshine
```

### Ubuntu / Debian
```bash
# Download the .deb from https://github.com/LizardByte/Sunshine/releases
sudo dpkg -i sunshine-*.deb
sudo apt-get install -f
```

### First-Time Pairing
1. Start Sunshine: `sunshine`
2. Open `https://localhost:47990` in a browser on the PC
3. Set a username and password for the web UI
4. On your laptop, open Moonlight and add the PC's IP address
5. Moonlight will show a PIN — enter it in the Sunshine web UI to pair

---

## 3. Enable Auto-Login

**Why:** Sunshine runs as a **user service**. It only starts after you log in. Without a monitor and keyboard attached, you cannot type your password at the login screen. Auto-login bypasses this.

### SDDM (KDE Plasma, Hyprland, LXQt)
Edit `/etc/sddm.conf` (create it if it doesn't exist):
```ini
[Autologin]
User=YOUR_USERNAME
Session=plasma        # or "hyprland" or your DE's session name
```

To find your session name:
```bash
ls /usr/share/wayland-sessions/    # Wayland sessions
ls /usr/share/xsessions/           # X11 sessions
```

### GDM (GNOME)
```bash
sudo nano /etc/gdm/custom.conf
```
```ini
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=YOUR_USERNAME
```

### LightDM (XFCE, Cinnamon, MATE)
```bash
sudo nano /etc/lightdm/lightdm.conf
```
```ini
[Seat:*]
autologin-user=YOUR_USERNAME
autologin-session=xfce    # or your session name
```

> [!CAUTION]
> Auto-login means anyone with physical access to the PC can access your desktop. Since this PC will be headless, the risk is minimal, but be aware of this if the machine is in a shared environment.

---

## 4. Create the Virtual Headless Monitor

**Why:** When no physical monitor is plugged in, the desktop environment has no screen to render to. Sunshine needs a screen to capture. We create a software "virtual" screen.

### Hyprland (Wayland)

Hyprland requires you to explicitly create a headless output. Add this to your startup config:

**Startup (create the virtual output):**
```
exec-once = hyprctl output create headless
```
Or in Lua config (Hyprland ≥ 0.55):
```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl output create headless")
end)
```

**Monitor config (give it a resolution):**
```
monitor=HEADLESS-1,2560x1440@120.0,0x0,1.0
```
Or in Lua:
```lua
hl.monitor({
    output = "HEADLESS-1",
    mode = "2560x1440@120.0",
    position = "0x0",
    scale = 1.0,
})
```

> [!WARNING]
> The command is `hyprctl output create headless` (lowercase "headless"). Do **NOT** write `hyprctl output create HEADLESS-1` — that is a different, incorrect command that will silently fail.

> [!WARNING]
> Tools like `nwg-displays` can overwrite your monitor config and set `HEADLESS-1` to `disabled = true`. If Moonlight suddenly stops connecting after using display management tools, check your monitors config first.

### KDE Plasma (Wayland)

KDE Plasma on Wayland supports virtual outputs natively via `kscreen`:

```bash
# Method 1: Use kscreen-doctor to add a virtual output
kscreen-doctor output.add virtual/2560x1440@120
```

Alternatively, use a **headless HDMI dummy plug** (~$5-10 on Amazon) which is the most foolproof method for KDE. It tricks the GPU into thinking a real monitor is attached.

If using a dummy plug, just configure its resolution via System Settings → Display and Monitor.

### GNOME (Wayland)

GNOME supports headless outputs through Mutter:

```bash
# Create a virtual monitor
gnome-randr --output VIRTUAL1 --mode 2560x1440
```

Or use `mutter`'s `--virtual-monitor` flag. Again, a dummy plug is the simplest approach for GNOME.

### X11 (Any Desktop)

On X11, virtual monitors are straightforward:
```bash
# Add a virtual display
xrandr --addmode VIRTUAL1 2560x1440
xrandr --output VIRTUAL1 --mode 2560x1440
```

Or use `xorg.conf` with a dummy driver:
```bash
sudo pacman -S xf86-video-dummy   # Arch
sudo dnf install xorg-x11-drv-dummy  # Fedora
```

---

## 5. Configure Sunshine to Start on Boot

Sunshine should start automatically after login.

### As a systemd user service (Recommended)
```bash
# Enable and start
systemctl --user enable app-dev.lizardbyte.app.Sunshine.service
systemctl --user start app-dev.lizardbyte.app.Sunshine.service
```

If the service file doesn't exist, create one:
```bash
mkdir -p ~/.config/systemd/user/
cat > ~/.config/systemd/user/sunshine.service << 'EOF'
[Unit]
Description=Sunshine Game Stream Host
After=graphical-session.target

[Service]
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/sunshine
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable sunshine.service
```

The `ExecStartPre=/bin/sleep 5` gives the desktop environment time to fully initialize the virtual display before Sunshine tries to capture it.

### Via Desktop Autostart
Alternatively, add Sunshine to your DE's autostart:
```bash
mkdir -p ~/.config/autostart/
cat > ~/.config/autostart/sunshine.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Sunshine
Exec=sunshine
X-GNOME-Autostart-enabled=true
EOF
```

> [!IMPORTANT]
> Sunshine MUST start **after** the virtual headless monitor exists. If it starts before the monitor is created, it will find zero screens and fail to capture anything. The `sleep 5` in the systemd service handles this timing. If using autostart or exec-once in your WM config, make sure the monitor creation command comes first.

---

## 6. Fix Headless Cursor Lag

**Why:** On headless (virtual) Wayland displays, the GPU tries to use hardware cursor acceleration. Since there is no physical screen to receive the hardware cursor plane, this causes massive pipeline stalls and makes the stream unbearably laggy.

### Hyprland
Add to your environment variables:
```
env = WLR_NO_HARDWARE_CURSORS,1
```
Or in Lua:
```lua
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
```

### Sway
```
seat * xcursor_theme default 24
# In your sway config or environment:
# export WLR_NO_HARDWARE_CURSORS=1
```

### KDE Plasma / GNOME
This issue is primarily a wlroots-based compositor problem (Hyprland, Sway). KDE and GNOME handle cursor rendering differently, so you likely won't need this fix. If you do experience cursor lag, try setting `KWIN_FORCE_SW_CURSOR=1` for KDE.

---

## 7. Wake-on-LAN Setup

**Why:** To power on the PC remotely from your laptop without pressing the physical power button.

### Step 1: Enable in BIOS/UEFI
Restart the PC, enter BIOS, and enable one of these (name varies by motherboard):
- "Wake on LAN"
- "Power On By PCI-E"
- "Power On By Network"
- "ErP Ready" → must be **DISABLED** (it blocks WoL)

### Step 2: Enable in the OS
```bash
# Check current WoL status
sudo ethtool enp39s0 | grep -i wake-on
# "Wake-on: g" means enabled, "Wake-on: d" means disabled

# Enable WoL
sudo ethtool -s enp39s0 wol g
```

To make it permanent, create a systemd service:
```bash
sudo cat > /etc/systemd/system/wol.service << 'EOF'
[Unit]
Description=Enable Wake-on-LAN
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ethtool -s enp39s0 wol g

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable wol.service
```

Or use NetworkManager (Fedora default):
```bash
nmcli connection modify "Wired connection 1" 802-3-ethernet.wake-on-lan magic
```

### Step 3: Note Your MAC Address
You'll need this for Moonlight to send the wake packet:
```bash
ip link show enp39s0 | grep ether
# Example output: link/ether 2c:f0:5d:e7:81:eb
```

### Step 4: Configure Moonlight
In Moonlight on your laptop:
1. Add the PC manually using its local IP address
2. Go to the PC's settings in Moonlight
3. Enter the MAC address for Wake-on-LAN
4. Now when the PC is off, clicking it in Moonlight will send a magic packet to wake it

---

## 8. Moonlight Client Setup

See **[MOONLIGHT-TIPS.md](MOONLIGHT-TIPS.md)** for detailed client configuration.

---

## 9. Disable Idle/Suspend While Streaming

Your PC may go to sleep while you are streaming if an idle timer fires. You should either:

### Option A: Increase or disable idle timers
For `hypridle`, the idle config is at `~/.config/hypr/hypridle.conf`. The key listeners are:
- Screen lock timeout
- DPMS off timeout (turns off virtual display — will freeze stream!)
- Suspend timeout

Consider disabling DPMS off and suspend entirely for a headless setup, or increase the timeouts significantly.

### Option B: Use Sunshine's built-in idle inhibitor
Sunshine should inhibit idle automatically while a client is connected. Check `sunshine.conf`:
```ini
# Sunshine should handle this automatically, but if it doesn't:
idle_inhibit_screensaver = enabled
```

### Option C: Systemd inhibit
```bash
systemd-inhibit --what=idle --who=sunshine --why="Game streaming" --mode=block sunshine
```

---

## 10. Desktop-Specific Instructions

### Fedora KDE Plasma (Recommended for ease of setup)

1. **Install Sunshine:** `sudo dnf install sunshine` or Flatpak
2. **Auto-login:** Edit `/etc/sddm.conf` → `User=YOUR_USER`, `Session=plasma`
3. **Virtual monitor:** Plug in a dummy HDMI dongle (simplest), or use `kscreen-doctor`
4. **Start Sunshine:** `systemctl --user start app-dev.lizardbyte.app.Sunshine.service`
5. **WoL:** `nmcli connection modify "Wired connection 1" 802-3-ethernet.wake-on-lan magic`
6. **Done!**

### Fedora GNOME

1. **Install Sunshine:** Same as above
2. **Auto-login:** Edit `/etc/gdm/custom.conf`
3. **Virtual monitor:** Dummy plug or GNOME virtual display
4. **Start Sunshine:** Systemd user service or autostart desktop entry
5. **WoL:** Same NetworkManager command

### Hyprland

1. **Install Sunshine:** Via package manager
2. **Auto-login:** Edit your display manager config (SDDM, GDM, etc.)
3. **Virtual monitor:** `exec-once = hyprctl output create headless` + monitor config
4. **Cursor fix:** `env = WLR_NO_HARDWARE_CURSORS,1`
5. **Start Sunshine:** `exec-once = systemctl --user start app-dev.lizardbyte.app.Sunshine.service` (AFTER the headless output creation)
6. **Bar/Shell:** Make sure your status bar (waybar, noctalia, etc.) is configured to show on `HEADLESS-1`, not just your physical monitor name
7. **WoL:** Systemd service or NetworkManager
