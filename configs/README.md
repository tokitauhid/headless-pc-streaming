# Reference Config Files

These are the actual working configuration files from the **Fedora KDE Plasma** and **CachyOS Hyprland** headless setups. Use them as reference when setting up a new system.

## Directory Structure

```
configs/
├── fedora-kde/
│   ├── set-headless-resolution.sh      # Resolution injection script (kscreen-doctor)
│   ├── set-headless-resolution.desktop # KDE Autostart desktop entry
│   ├── 00-disable-gpu-audio.rules      # Udev rule preventing AMD GPU D3hot PCIe crash
│   └── sunshine.conf                   # Working Sunshine config for KMS hardware capture
├── hyprland/
│   ├── monitors.lua                    # Virtual headless monitor configuration
│   └── startup.lua                     # Startup commands (creates headless output, starts Sunshine)
└── sddm/
    └── sddm.conf                       # Auto-login configuration
```

## Notes

- **Fedora KDE:**
  - `set-headless-resolution.sh` should be placed in `~/.local/bin/` and made executable (`chmod +x`).
  - `set-headless-resolution.desktop` belongs in `~/.config/autostart/`.
  - `00-disable-gpu-audio.rules` belongs in `/etc/udev/rules.d/`.
  - `sunshine.conf` belongs in `~/.config/sunshine/sunshine.conf`.
- **Hyprland:**
  - These configs use Hyprland's **Lua** config format (v0.55+). If your version uses the old `hyprlang` format, see the `.conf` equivalents documented inline in [SETUP.md](../docs/SETUP.md).
- Replace `tokit` with your actual username where appropriate.
- Replace `2560x1440@120.0` with your desired resolution and refresh rate.
- The `turn-off-core6+14.sh` script is hardware-specific (CPU stability fix) and not relevant to the streaming setup.
