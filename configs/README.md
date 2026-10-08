# Reference Config Files

These are the actual working configuration files from the CachyOS + Hyprland setup. Use them as reference when setting up a new system.

## Directory Structure

```
configs/
├── hyprland/
│   ├── monitors.lua          # Virtual headless monitor configuration
│   └── startup.lua           # Startup commands (creates headless output, starts Sunshine)
└── sddm/
    └── sddm.conf             # Auto-login configuration
```

## Notes

- These configs use Hyprland's **Lua** config format (v0.55+). If your version uses the old `hyprlang` format, see the `.conf` equivalents documented inline.
- Replace `tokit` with your actual username.
- Replace `2560x1440@120.0` with your desired resolution and refresh rate.
- The `turn-off-core6+14.sh` script is hardware-specific (CPU stability fix) and not relevant to the streaming setup.
