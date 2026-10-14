# Complete Headless PC Streaming Setup Guide

This guide documents every step needed to turn a desktop PC into a headless streaming machine accessible from a laptop via **Moonlight** and **Sunshine**. No physical monitor needs to be attached to the host PC.

---

## Table of Contents

- [1. Prerequisites](#1-prerequisites)
- [2. Track A: Fedora + KDE Plasma (Wayland)](#2-track-a-fedora--kde-plasma-wayland)
  - [Step 1: Install Sunshine](#step-1-install-sunshine-fedora)
  - [Step 2: Enable SDDM Auto-Login (Mandatory for Headless)](#step-2-enable-sddm-auto-login-mandatory-for-headless)
  - [Step 3: Setup the Virtual Display](#step-3-setup-the-virtual-display-kde)
  - [Step 4: Configure Sunshine to Capture the Virtual Display](#step-4-configure-sunshine-to-capture-the-virtual-display)
  - [Step 5: Enable Sunshine Autostart](#step-5-enable-sunshine-autostart)
- [3. Track B: Arch / CachyOS + Hyprland (Wayland)](#3-track-b-arch--cachyos--hyprland-wayland)
  - [Step 1: Install Sunshine](#step-1-install-sunshine-arch)
  - [Step 2: Enable Auto-Login](#step-2-enable-auto-login-hyprland)
  - [Step 3: Create Headless Monitor in Hyprland](#step-3-create-headless-monitor-in-hyprland)
  - [Step 4: Fix Headless Cursor Lag](#step-4-fix-headless-cursor-lag)
  - [Step 5: Configure Sunshine & Autostart](#step-5-configure-sunshine--autostart-hyprland)
  - [Step 6: Status Bar Configuration](#step-6-status-bar-configuration)
- [4. Shared Configuration](#4-shared-configuration)
  - [Wake-on-LAN Setup](#wake-on-lan-setup)
  - [Moonlight Client Setup](#moonlight-client-setup)
  - [Prevent Idle / Suspend While Streaming](#prevent-idle--suspend-while-streaming)

---

## 1. Prerequisites

### On the Host Desktop PC:
- Linux with AMD, NVIDIA, or Intel GPU capable of hardware video encoding (VA-API, NVENC, or QSV).
- Wired Gigabit Ethernet connection (strongly recommended for sub-5ms network latency).
- Display Environment: Either **Fedora KDE Plasma (Wayland)** or **Arch/CachyOS Hyprland**.

### On the Client Laptop / Device:
- **Moonlight** installed ([moonlight-stream.org](https://moonlight-stream.org)).
- Connected to the same local area network (LAN) as the desktop PC.

---

## 2. Track A: Fedora + KDE Plasma (Wayland)

### Step 1: Install Sunshine (Fedora)
Sunshine is available via RPM package or Flatpak:
```bash
sudo dnf install -y sunshine
# Or via Flatpak:
# flatpak install flathub dev.lizardbyte.app.Sunshine
```

Pair your Moonlight client with Sunshine initially:
1. Start Sunshine once: `sunshine`
2. Open the web interface in a browser: `https://localhost:47990`
3. Set your admin username and password.
4. On your laptop, open Moonlight, enter your PC's IP, and input the generated PIN in Sunshine's web UI (**PIN** tab).

---

### Step 2: Enable SDDM Auto-Login (Mandatory for Headless)

> [!CRITICAL]
> Sunshine runs as a **user service**. It only launches **after** your graphical desktop session starts.
> If auto-login is disabled, the PC sits at the SDDM login screen after boot. Sunshine will find no display, throw `Fatal: Unable to find display or encoder during startup`, and refuse Moonlight connections.

Create an SDDM autologin configuration drop-in:
```bash
sudo mkdir -p /etc/sddm.conf.d
sudo bash -c 'cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=$(whoami)
Session=plasma
EOF'
```
*(Verify your session file exists at `/usr/share/wayland-sessions/plasma.desktop`)*.

---

### Step 3: Setup the Virtual Display (KDE)

KDE Plasma does not support the old `kscreen-doctor output.add` command. Choose one of two methods:

#### Method 1: Headless HDMI/DP Dummy Plug (Recommended / 100% GUI)
A hardware dummy plug (~$5–$10 on Amazon) tricks your GPU into recognizing a real physical monitor:
1. Plug the dummy plug into an open GPU port (e.g. HDMI or DisplayPort).
2. Open **System Settings → Display and Monitor** in KDE.
3. Configure your desired resolution (e.g., 2560×1440 @ 120Hz), scaling, and position entirely via the GUI.
4. With a dummy plug, Sunshine's default **KMS** hardware capture works automatically without extra compositor adjustments.

#### Method 2: Software Virtual Output via `krfb-virtualmonitor`
If you do not have a physical dummy plug, use KDE's built-in virtual monitor utility:
```bash
# Ensure krfb is installed (default on Fedora KDE):
sudo dnf install -y krfb

# Test spawning the virtual monitor:
krfb-virtualmonitor --resolution 2560x1440 --name "Virtual-1"
```

**Add to KDE Autostart via GUI:**
1. Open **System Settings → Autostart**.
2. Click **Add...** → **Add Command** (or Add Application).
3. Set Command to: `krfb-virtualmonitor --resolution 2560x1440 --name "Virtual-1"`
4. Save. When KDE boots, KWin will automatically create this virtual display.

> [!NOTE]
> **KWin Output Naming Rule:**
> KDE Plasma automatically prefixes all virtual outputs with `Virtual-`. 
> When you launch with `--name "Virtual-1"`, KWin names the actual display **`Virtual-Virtual-1`**. 
> Run `kscreen-doctor -o` to confirm the exact identifier.

---

### Step 4: Configure Sunshine to Capture the Virtual Display

> [!WARNING]
> **Do NOT Put Display Names into Application Settings:**
> In the Sunshine Web UI under **Applications → Edit** (e.g. `Headless Display` or `Desktop`):
> - The **"Output"** field is for **command logging** (redirecting `stdout` to a file).
> - The **"Command"** field is for launching an executable (e.g. `steam`).
> Leaving a display name like `Virtual-Virtual-1` in either field will cause Sunshine to fail with `Permission denied / Unable to find executable`. **Leave both fields blank for desktop streaming.**

Display selection is configured globally:

#### In the Sunshine Web UI:
1. Open `https://localhost:47990` in your browser.
2. In the left sidebar, click **Audio / Video**:
   * Locate the **`Display Id`** field (below *Adapter Name*, placeholder `DP-0`).
   * Enter your virtual output name: `Virtual-Virtual-1` (or your dummy plug port, e.g. `DP-1`).
3. If using `krfb-virtualmonitor`, switch the capture method:
   * In the left sidebar, click **Advanced** (below *Config Files*).
   * Find **`Capture`** (default: *Autodetect*).
   * Change it to **`KWin Screencast`** (required because software virtual displays do not have a hardware DRM connector for KMS).
4. Click the blue **Save** button at the bottom.
5. Click **Apply Changes** (top-right banner) to reload Sunshine.

#### Alternatively, edit `sunshine.conf` directly:
Edit `~/.config/sunshine/sunshine.conf`:
```ini
# When using krfb-virtualmonitor:
capture = kwin
output_name = Virtual-Virtual-1

# When using a Hardware Dummy Plug:
# capture = kms
# output_name = DP-1
```

---

### Step 5: Enable Sunshine Autostart

Ensure Sunshine starts automatically when your desktop logs in:

```bash
# Enable the user service
systemctl --user enable app-dev.lizardbyte.app.Sunshine.service
systemctl --user start app-dev.lizardbyte.app.Sunshine.service
```

If the service unit does not exist, create `~/.config/systemd/user/sunshine.service`:
```ini
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
```
Reload and enable:
```bash
systemctl --user daemon-reload
systemctl --user enable sunshine.service
```

---

## 3. Track B: Arch / CachyOS + Hyprland (Wayland)

### Step 1: Install Sunshine (Arch)
```bash
sudo pacman -S sunshine
```

---

### Step 2: Enable Auto-Login (Hyprland)

Sunshine requires an active graphical session. If using SDDM with Hyprland:
```ini
# /etc/sddm.conf
[Autologin]
User=YOUR_USERNAME
Session=hyprland
```

---

### Step 3: Create Headless Monitor in Hyprland

Hyprland provides native headless output creation via `hyprctl`.

#### Startup configuration:
Add to `~/.config/hypr/hyprland.conf`:
```ini
exec-once = hyprctl output create headless
```
Or in Lua config (Hyprland ≥ 0.55):
```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl output create headless")
end)
```

> [!WARNING]
> Use lowercase `headless`: `hyprctl output create headless`. 
> Do **NOT** write `hyprctl output create HEADLESS-1` (that is the assigned name, not the type, and will silently fail).

#### Monitor mode configuration:
Add to `~/.config/hypr/hyprland.conf`:
```ini
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

---

### Step 4: Fix Headless Cursor Lag

On wlroots-based compositors (Hyprland, Sway), the GPU tries to use hardware cursor planes on virtual screens, resulting in severe lag and stutter.

Disable hardware cursors in `~/.config/hypr/hyprland.conf`:
```ini
env = WLR_NO_HARDWARE_CURSORS,1
```
Or in Lua:
```lua
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
```

---

### Step 5: Configure Sunshine & Autostart (Hyprland)

In `~/.config/sunshine/sunshine.conf`:
```ini
capture = kms
output_name = HEADLESS-1
```

Start Sunshine in `hyprland.conf` **after** monitor creation:
```ini
exec-once = sleep 2 && systemctl --user start app-dev.lizardbyte.app.Sunshine.service
```

---

### Step 6: Status Bar Configuration

If your status bar (Waybar, Noctalia, etc.) disappears over the stream, it is likely pinned to your old physical monitor name (`HDMI-A-1`, `DP-1`).

Update `~/.config/waybar/config`:
```json
"output": ["HEADLESS-1"]
```
*(Or remove the `"output"` constraint altogether so it displays on any connected screen).*

---

## 4. Shared Configuration

### Wake-on-LAN Setup
Allow your laptop to turn on the desktop PC remotely over the network.

#### Step 1: Enable in BIOS/UEFI
- Enable **Wake-on-LAN** or **Power On by PCI-E / Network**.
- Disable **ErP Ready** / Deep Sleep (ErP cuts power to the NIC when shut down).

#### Step 2: Enable in NetworkManager (Fedora & Arch)
```bash
nmcli connection modify "Wired connection 1" 802-3-ethernet.wake-on-lan magic
```
Find your MAC address:
```bash
ip link show enp39s0 | grep ether
```

#### Step 3: Configure Moonlight Client
In Moonlight on your laptop:
1. Add the desktop PC by IP.
2. Open PC settings in Moonlight and enter the MAC address.
3. When the desktop PC is offline, clicking the PC tile in Moonlight will wake it up.

---

### Moonlight Client Setup
For optimal latency and image quality on your client:
* **Resolution & FPS:** Match your host virtual display (e.g., 2560×1440 @ 120 FPS).
* **Bitrate:** 50–100 Mbps on local Gigabit Ethernet.
* **Video Codec:** HEVC or AV1 (if supported by client hardware).
* **Keyboard Shortcuts:** Enable **"Capture system keyboard shortcuts"** in Moonlight settings so `Alt+Tab` and `Super` operate on the remote desktop.

---

### Prevent Idle / Suspend While Streaming

To prevent the host PC from sleeping while streaming:

#### Option A: Sunshine screensaver inhibitor
In `~/.config/sunshine/sunshine.conf`:
```ini
idle_inhibit_screensaver = enabled
```

#### Option B: Systemd inhibit wrapper
```bash
systemd-inhibit --what=idle --who=sunshine --why="Streaming" --mode=block sunshine
```
