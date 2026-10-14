# Complete Headless PC Streaming Setup Guide

This guide documents every step needed to turn a desktop PC into a headless streaming machine accessible from a laptop via **Moonlight** and **Sunshine**. No physical monitor needs to be attached to the host PC.

---

## Table of Contents

- [1. Prerequisites](#1-prerequisites)
- [2. Track A: Fedora + KDE Plasma (Wayland)](#2-track-a-fedora--kde-plasma-wayland)
  - [Step 1: Install Sunshine](#step-1-install-sunshine-fedora)
  - [Step 2: Enable SDDM Auto-Login (Mandatory for Headless)](#step-2-enable-sddm-auto-login-mandatory-for-headless)
  - [Step 3: Setup the Display Environment](#step-3-setup-the-display-environment-kde)
    - [Option 1: Fully Headless (No Monitor, No Dummy Plug)](#option-1-fully-headless-no-monitor-no-dummy-plug---recommended)
    - [Option 2: Hardware Dummy Plug](#option-2-hardware-dummy-plug-simplest-hardware-option)
    - [Option 3: Extra / Secondary Virtual Display (krfb-virtualmonitor)](#option-3-extra--secondary-virtual-display-krfb-virtualmonitor)
  - [Step 4: Configure Sunshine to Capture the Display](#step-4-configure-sunshine-to-capture-the-display)
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

### Step 3: Setup the Display Environment (KDE)

Unlike Hyprland (which supports creating headless virtual outputs natively via `hyprctl`), **KDE Plasma's KWin compositor requires an active DRM connector on startup**. If KWin boots with no monitor and no dummy plug attached, it cannot initialize its rendering pipeline, and Sunshine fails with:
`Fatal: Unable to find display or encoder during startup`.

Select the option that matches your setup:
* **[Option 1: Fully Headless (No Monitor, No Dummy Plug)](#option-1-fully-headless-no-monitor-no-dummy-plug---recommended)** — **Recommended** for true headless servers. 100% software solution using a forced kernel DRM connector + custom mode injection.
* **[Option 2: Hardware Dummy Plug](#option-2-hardware-dummy-plug-simplest-hardware-option)** — Physical HDMI/DP plug (~$5).
* **[Option 3: Extra / Secondary Virtual Display (krfb-virtualmonitor)](#option-3-extra--secondary-virtual-display-krfb-virtualmonitor)** — For adding a 2nd virtual monitor alongside a physical or forced display.

---

#### Option 1: Fully Headless (No Monitor, No Dummy Plug — Recommended)

This method forces the Linux kernel to treat an empty physical port (e.g. `HDMI-A-1`) as permanently connected, initializes KWin normally at boot, and automatically injects high-resolution modes (e.g. 2560×1440 @ 120Hz) upon login.

##### 1. Prerequisite: Prevent AMD GPU Audio D3hot PCIe Crash (AMD GPUs)
> [!CRITICAL]
> **Essential for AMD Radeon GPUs (Navi 10 / RX 5000/6000 series):**
> When no display is plugged into the GPU, the GPU's HDMI/DP audio controller enters a low-power `D3hot` sleep state. Due to an AMD PCIe power management bug, this collapses the GPU's PCIe link, knocking the entire graphics card off the bus and freezing the system.
> 
> To permanently prevent this, create a udev rule to remove the GPU HDMI audio controller from the PCI bus:
> ```bash
> sudo bash -c 'cat << "EOF" > /etc/udev/rules.d/00-disable-gpu-audio.rules
> # Completely remove GPU HDMI audio controller from the PCI bus to prevent D3hot crash
> ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1002", ATTR{class}=="0x040300", ATTR{remove}="1"
> EOF'
> ```
> *(Note: This only disables the GPU's HDMI/DP audio output. Your motherboard analog/USB audio and Sunshine virtual audio sink are completely unaffected).*

##### 2. Force the Kernel DRM Connector Active
Instruct the kernel DRM subsystem to report `HDMI-A-1` as always connected using the `video=...e` kernel parameter:
```bash
# Add video kernel parameter across all installed kernels
sudo grubby --update-kernel=ALL --args="video=HDMI-A-1:2560x1440@120e"

# Persist in /etc/default/grub (for future kernel updates):
sudo sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="video=HDMI-A-1:2560x1440@120e /' /etc/default/grub
```
* The trailing `e` forces the output state to **enabled**.
* KWin now detects `HDMI-A-1` during early boot, successfully initializes Wayland, and Sunshine finds a valid display.

##### 3. Inject Custom Resolution on Login (`kscreen-doctor`)
> [!NOTE]
> Because no physical monitor is connected to supply an EDID, the DRM driver defaults the forced output to a safe fallback resolution (typically 640×480 or 1024×768). The `2560x1440@120` in the kernel argument only acts as a hint.
> To unlock full 2560×1440 @ 120Hz, we inject a custom modeline into KWin via an autostart script.

1. Create the autostart script:
```bash
mkdir -p ~/.local/bin
cat << 'EOF' > ~/.local/bin/set-headless-resolution.sh
#!/bin/bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export WAYLAND_DISPLAY=wayland-0

# Wait for KWin to finish initializing
sleep 2

# Inject 2560x1440@120Hz custom mode (CVT reduced blanking)
kscreen-doctor output.HDMI-A-1.addCustomMode.2560.1440.120000.reduced 2>/dev/null || true

# Apply the 2560x1440@120 mode
kscreen-doctor output.HDMI-A-1.mode.2560x1440@120 2>/dev/null || true

# Disable any leftover software virtual monitor
kscreen-doctor output.Virtual-Virtual-1.disable 2>/dev/null || true
EOF
chmod +x ~/.local/bin/set-headless-resolution.sh
```

2. Register the script with KDE Autostart:
```bash
mkdir -p ~/.config/autostart
cat << 'EOF' > ~/.config/autostart/set-headless-resolution.desktop
[Desktop Entry]
Type=Application
Name=Set Headless 1440p120 Resolution
Exec=/home/tokit/.local/bin/set-headless-resolution.sh
Terminal=false
X-KDE-autostart-phase=2
EOF
```
*(Replace `/home/tokit` with your actual `$HOME` path if different).*

##### 4. How to Undo / Revert
If you reconnect a physical monitor or wish to revert these changes:
```bash
# 1. Remove kernel argument
sudo grubby --update-kernel=ALL --remove-args="video=HDMI-A-1:2560x1440@120e"
sudo sed -i 's/video=HDMI-A-1:2560x1440@120e //' /etc/default/grub

# 2. Remove autostart script
rm -f ~/.local/bin/set-headless-resolution.sh
rm -f ~/.config/autostart/set-headless-resolution.desktop

# 3. (Optional) Re-enable GPU HDMI audio if using monitor speakers:
# sudo rm -f /etc/udev/rules.d/00-disable-gpu-audio.rules

# 4. Reboot
sudo reboot
```

---

#### Option 2: Hardware Dummy Plug (~$5-10 Hardware Option)
A physical HDMI or DisplayPort dummy plug (EDID emulator) tricks your GPU into recognizing a physical monitor:
1. Plug the dummy plug into an open GPU port (e.g. HDMI or DisplayPort).
2. Open **System Settings → Display and Monitor** in KDE.
3. Configure your desired resolution (e.g., 2560×1440 @ 120Hz), scaling, and position entirely via the GUI.
4. Sunshine's default **KMS** hardware capture works automatically.

---

#### Option 3: Extra / Secondary Virtual Display (`krfb-virtualmonitor`)
> [!IMPORTANT]
> **Use this option when you want an extra/secondary virtual display** alongside your primary monitor or forced connector (e.g. for a dual-monitor streaming layout or dedicated second workspace).
> **Do NOT use this as the sole display for headless booting on KDE**, because KWin will fail to initialize before this virtual output is created.

If you want an additional virtual screen:
```bash
# Ensure krfb is installed (default on Fedora KDE):
sudo dnf install -y krfb

# Test spawning the virtual monitor:
krfb-virtualmonitor --resolution 2560x1440 --name "Virtual-1"
```

**Add to KDE Autostart via GUI or CLI:**
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

### Step 4: Configure Sunshine to Capture the Display

> [!WARNING]
> **Do NOT Put Display Names into Application Settings:**
> In the Sunshine Web UI under **Applications → Edit** (e.g. `Headless Display` or `Desktop`):
> - The **"Output"** field is for **command logging** (redirecting `stdout` to a file).
> - The **"Command"** field is for launching an executable (e.g. `steam`).
> Leaving a display name like `HDMI-A-1` or `Virtual-Virtual-1` in either field will cause Sunshine to fail with `Permission denied / Unable to find executable`. **Leave both fields blank for desktop streaming.**

Display selection and capture method are configured based on which option you chose in Step 3:

#### For Option 1 (Fully Headless) or Option 2 (Dummy Plug):
These methods provide a real DRM connector, allowing high-performance **KMS hardware capture** with direct VA-API / NVENC hardware encoding:

**Edit `~/.config/sunshine/sunshine.conf`:**
```ini
capture = kms
output_name = HDMI-A-1    # Or your dummy plug port, e.g. DP-1
```

Or via Sunshine Web UI (`https://localhost:47990`):
1. Go to **Audio / Video** → set **Display Id** to `HDMI-A-1` (or your port).
2. Go to **Advanced** → set **Capture** to `Autodetect` or `KMS`.
3. Click **Save** and **Apply Changes**.

#### For Option 3 (Extra Virtual Display via `krfb-virtualmonitor`):
Because software virtual displays exist purely within KWin's compositor space without a hardware DRM plane, Sunshine must capture them via KWin Screencast:

**Edit `~/.config/sunshine/sunshine.conf`:**
```ini
capture = kwin
output_name = Virtual-Virtual-1
```

Or via Sunshine Web UI (`https://localhost:47990`):
1. Go to **Audio / Video** → set **Display Id** to `Virtual-Virtual-1`.
2. Go to **Advanced** → set **Capture** to `KWin Screencast`.
3. Click **Save** and **Apply Changes**.

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
