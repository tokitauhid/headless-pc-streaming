# Troubleshooting Guide

Every problem documented here was encountered during real-world testing and setup. These solutions cover both **Fedora KDE Plasma (Wayland)** and **Arch/CachyOS (Hyprland)** environments.

---

## Table of Contents

- [🔴 Moonlight Cannot Find or Connect to Host PC](#-moonlight-cannot-find-or-connect-to-host-pc)
  - [1. PC Stuck at Login Screen (Common after Reboot or Headless Boot)](#1-pc-stuck-at-login-screen-common-after-reboot-or-headless-boot)
  - [2. "Unable to find executable [...] Permission denied" Error](#2-unable-to-find-executable--permission-denied-error)
  - [3. Sunshine Service Not Running](#3-sunshine-service-not-running)
  - [4. Firewall Blocking Sunshine Ports](#4-firewall-blocking-sunshine-ports)
- [🔴 Display & Streaming Issues](#-display--streaming-issues)
  - [1. Moonlight Streams Physical Monitor Instead of Virtual Display](#1-moonlight-streams-physical-monitor-instead-of-virtual-display)
  - [2. KMS Capture Fails with "Unknown Monitor connector type [Virtual-Virtual]"](#2-kms-capture-fails-with-unknown-monitor-connector-type-virtual-virtual)
  - [3. Display Name Mistakenly Placed in Application "Output" Field](#3-display-name-mistakenly-placed-in-application-output-field)
  - [4. `kscreen-doctor output.add` Command Does Not Work (KDE Plasma)](#4-kscreen-doctor-outputadd-command-does-not-work-kde-plasma)
  - [5. Stream Connected but Frozen / Single Static Frame](#5-stream-connected-but-frozen--single-static-frame)
  - [6. `hyprctl output create HEADLESS-1` Silently Fails (Hyprland)](#6-hyprctl-output-create-headless-1-silently-fails-hyprland)
  - [7. Status Bar / Waybar / Noctalia Missing](#7-status-bar--waybar--noctalia-missing)
- [🔴 Performance & Input Issues](#-performance--input-issues)
  - [1. Extreme Mouse / Display Lag on Headless Display (Hyprland / wlroots)](#1-extreme-mouse--display-lag-on-headless-display-hyprland--wlroots)
  - [2. Right-Click Drag Not Working in Fullscreen Games](#2-right-click-drag-not-working-in-fullscreen-games)
  - [3. Keyboard Shortcuts Intercepted by Laptop](#3-keyboard-shortcuts-intercepted-by-laptop)
  - [4. Stream Disconnects or Host Suspends While Playing](#4-stream-disconnects-or-host-suspends-while-playing)
  - [5. Harmless AV1 Encoder Error in Sunshine Log](#5-harmless-av1-encoder-error-in-sunshine-log)

---

## 🔴 Moonlight Cannot Find or Connect to Host PC

### 1. PC Stuck at Login Screen (Common after Reboot or Headless Boot)

#### Symptom
You can SSH into your host PC from your laptop, but Moonlight says the PC is offline or fails to connect. In `~/.config/sunshine/sunshine.log`, you see:
```text
Fatal: Unable to find display or encoder during startup.
Fatal: Please ensure your manually chosen GPU and monitor are connected and powered on.
```

#### Cause
Sunshine runs as a **systemd user service** (`sunshine.service`), which relies on an active graphical desktop session. Without auto-login enabled, the PC boots into the SDDM/GDM greeter (`plasmalogin`). KWin and the Wayland compositor do not start until a user logs in, leaving Sunshine with zero displays to capture.

#### Fix
Enable auto-login so the graphical desktop launches on boot without keyboard interaction:

**For SDDM (KDE Plasma / Hyprland):**
```bash
sudo mkdir -p /etc/sddm.conf.d
sudo bash -c 'cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=$(whoami)
Session=plasma
EOF'
```
*(If using Hyprland, replace `Session=plasma` with `Session=hyprland`)*.

---

### 2. "Unable to find executable [...] Permission denied" Error

#### Symptom
Moonlight connects briefly and immediately drops. In `sunshine.log`, you see:
```text
Error: Unable to find executable [Virtual-Virtual-1]. Is it in your PATH?
Info: Executing: [Virtual-Virtual-1] in [""]
Warning: Couldn't run [Virtual-Virtual-1]: System: Permission denied
```

#### Cause
In the Sunshine Web UI under **Applications → Edit** (e.g. `Headless Display`), the virtual monitor name (`Virtual-Virtual-1`) was entered into the **Command** field (`cmd`). Sunshine attempts to execute this as a binary on your computer, cannot find it, and aborts the entire stream.

#### Fix
1. Open Sunshine Web UI: `https://localhost:47990` → **Applications**.
2. Click **Edit** on your app.
3. **Completely clear the Command field** (leave it empty).
4. Save. When Command is blank, Sunshine streams the raw desktop.

---

### 3. Sunshine Service Not Running

#### Symptom
Moonlight shows the host PC with a lock or offline icon.

#### Fix
```bash
# Check service status
systemctl --user status app-dev.lizardbyte.app.Sunshine.service

# Start or restart
systemctl --user restart app-dev.lizardbyte.app.Sunshine.service
```

---

### 4. Firewall Blocking Sunshine Ports

#### Symptom
Sunshine is running and auto-logged in, but Moonlight cannot discover the PC.

#### Fix (Fedora / firewalld):
Open Sunshine's required ports:
```bash
sudo firewall-cmd --permanent --add-port={47984,47989,47990,48010}/tcp
sudo firewall-cmd --permanent --add-port={47998,47999,48000,48002,48010}/udp
sudo firewall-cmd --reload
```

---

## 🔴 Display & Streaming Issues

### 1. Moonlight Streams Physical Monitor Instead of Virtual Display

#### Symptom
When connecting from Moonlight, you see your physical desktop monitor rather than the virtual headless output.

#### Causes & Fixes
* **Cause A: Display ID missing in Sunshine config.**
  * *Fix:* In Sunshine Web UI (**Configuration → Audio / Video**), set **Display Id** to your virtual output identifier (e.g. `Virtual-Virtual-1` or `HEADLESS-1`).
* **Cause B: KDE KWin prefixing mismatch.**
  * *Fix:* If you spawned `krfb-virtualmonitor` using `--name Virtual-1`, KDE prefixes it with `Virtual-`, making the true name **`Virtual-Virtual-1`**. Verify with `kscreen-doctor -o` and match it in Sunshine.

---

### 2. KMS Capture Fails with "Unknown Monitor connector type [Virtual-Virtual]"

#### Symptom
In `~/.config/sunshine/sunshine.log`:
```text
Error: Unknown Monitor connector type [Virtual-Virtual]: Please report this to the GitHub issue tracker
Info: Monitor 0 is HDMI-A-1: HKC OVERSEAS LIMITED E2721H
Info: Screencasting with KMS
Info: Mapped 'HDMI-A-1' to kmsgrab monitor index 0
```
Sunshine ignores the virtual display and grabs the physical HDMI port.

#### Cause
Sunshine's default capture backend is **KMS**, which directly interrogates hardware GPU DRM connectors (`/dev/dri/card*`). Software virtual monitors created by `krfb-virtualmonitor` exist inside KWin's compositor and have no physical DRM connector.

#### Fix
Switch Sunshine to compositor-level capture:
1. In Sunshine Web UI, go to **Configuration → Advanced** (left sidebar).
2. Set **Capture** from *Autodetect* to **`KWin Screencast`** (`capture = kwin`).
3. Save and apply changes.

*(Note: If using a **Hardware Dummy Plug**, this error does not occur because the dummy plug creates a genuine hardware KMS connector on the GPU).*

---

### 3. Display Name Mistakenly Placed in Application "Output" Field

#### Symptom
You typed `Virtual-1` into the Application config, but Sunshine still streams the physical monitor.

#### Cause
In Sunshine's **Applications → Edit** interface, the **"Output"** field with the folder icon is for saving command console logs (`stdout` redirection to a file), **NOT** for selecting video displays.

#### Fix
Erase the entry from the Application **Output** field and leave it blank. Set the display globally under **Configuration → Audio / Video → Display Id**.

---

### 4. `kscreen-doctor output.add` Command Does Not Work (KDE Plasma)

#### Symptom
Running `kscreen-doctor output.add virtual/...` fails or prints command syntax help.

#### Cause
KDE Plasma's `kscreen-doctor` tool manages existing outputs; it does not provide an `output.add` command on Wayland.

#### Fix
* Use a physical HDMI/DisplayPort dummy plug (configured via **System Settings → Display and Monitor**).
* OR use KDE's virtual monitor binary:
  ```bash
  krfb-virtualmonitor --resolution 2560x1440 --name "Virtual-1"
  ```

---

### 5. Stream Connected but Frozen / Single Static Frame

#### Causes & Fixes
1. **Multiple virtual outputs active:** If multiple headless displays were created (`HEADLESS-1` and `HEADLESS-2`), Sunshine may get confused and select nothing (`[wlgrab] Selected monitor []`).
   * *Fix:* Remove redundant outputs (`hyprctl output remove HEADLESS-2` or `killall krfb-virtualmonitor`) and restart Sunshine.
2. **Physical cable unplugged during an active stream:** If a physical monitor that was being actively streamed is unplugged, the capture pipeline breaks.
   * *Fix:* Use a persistent virtual headless output so physical cable state does not affect streaming.

---

### 6. `hyprctl output create HEADLESS-1` Silently Fails (Hyprland)

#### Symptom
Hyprland never creates the headless monitor.

#### Cause
The first parameter to `hyprctl output create` is the **backend type** (`headless`), not the output name.

#### Fix
```bash
hyprctl output create headless      # ✅ Correct (lowercase)
# Do NOT run: hyprctl output create HEADLESS-1  ❌
```

---

### 7. Status Bar / Waybar / Noctalia Missing

#### Symptom
The desktop streams properly, but your bar is missing.

#### Fix
Waybar or shell configurations often pin outputs to physical connector names (`HDMI-A-1`). Edit `~/.config/waybar/config` and add `"HEADLESS-1"` (or `"Virtual-Virtual-1"`), or remove the `"output"` filter to display on all monitors.

---

## 🔴 Performance & Input Issues

### 1. Extreme Mouse / Display Lag on Headless Display (Hyprland / wlroots)

#### Symptom
Input lag and visual stutter are severe despite low ping over Gigabit Ethernet.

#### Cause
On wlroots compositors, the GPU attempts hardware cursor acceleration on headless outputs, causing pipeline lockups.

#### Fix
Disable hardware cursors in `~/.config/hypr/hyprland.conf`:
```ini
env = WLR_NO_HARDWARE_CURSORS,1
```

---

### 2. Right-Click Drag Not Working in Fullscreen Games

#### Symptom
Camera dragging with right-click stops responding after the first click in games (e.g. RTS or builder games).

#### Fix
1. Press `Ctrl + Alt + Shift + M` in Moonlight to toggle mouse capture mode.
2. Switch the game from Exclusive Fullscreen to **Windowed** or **Borderless Windowed**.

---

### 3. Keyboard Shortcuts Intercepted by Laptop

#### Fix
* While streaming, press `Ctrl + Alt + Shift + Z` to toggle host shortcut capture.
* In Moonlight settings on your laptop, permanently enable **"Capture system keyboard shortcuts"**.

---

### 4. Stream Disconnects or Host Suspends While Playing

#### Fix
Prevent systemd and Wayland idle managers from suspending:
* In `~/.config/sunshine/sunshine.conf`, set:
  ```ini
  idle_inhibit_screensaver = enabled
  ```
* In `hypridle.conf` (Hyprland), increase or comment out DPMS off and suspend rules.

---

### 5. Harmless AV1 Encoder Error in Sunshine Log

#### Symptom
```text
[av1_vaapi @ ...] No usable encoding profile found.
Could not open codec [av1_vaapi]: Function not implemented
```

#### Fix
Harmless notice on older AMD GPUs (like Radeon RX 5700 XT) that lack hardware AV1 encode blocks. Sunshine automatically falls back to H.264 / HEVC. No action needed.
