# Headless PC Streaming Setup

Stream your desktop PC to your laptop over the local network using **Sunshine** (host) and **Moonlight** (client). No physical monitor needed on the PC.

## Hardware

| Component | Spec |
|-----------|------|
| CPU | AMD Ryzen 5 3600 6-Core |
| GPU | AMD Radeon RX 5700 XT (Navi 10) |
| RAM | 16 GB |
| Network | Gigabit Ethernet (`enp39s0`, MAC: `2c:f0:5d:e7:81:eb`) |

## How It Works

```
┌─────────────────────┐          LAN (Gigabit)         ┌──────────────────┐
│   DESKTOP PC        │ ◄───────────────────────────── │   LAPTOP         │
│                     │                                │                  │
│  KDE / Hyprland     │   Sunshine encodes the         │  Moonlight       │
│  Virtual Headless   │   virtual display and          │  decodes and     │
│  monitor at         │   streams it over the          │  displays it on  │
│  2560x1440@120Hz    │   network                      │  your monitor    │
│                     │                                │                  │
│  Sunshine (host)    │ ─────────────────────────────► │  (client)        │
└─────────────────────┘                                └──────────────────┘
```

The PC boots headless (no monitor plugged in), auto-logs in, creates a software virtual display, starts Sunshine, and waits for Moonlight connections.

## Quick Start

See the full setup guide: **[docs/SETUP.md](docs/SETUP.md)** (with separate tracks for **Fedora KDE Plasma** and **Arch/CachyOS Hyprland**).

## Documentation

| Document | Description |
|----------|-------------|
| [docs/SETUP.md](docs/SETUP.md) | Step-by-step setup guide with dedicated tracks for Fedora KDE & Arch Hyprland |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Real-world errors, causes, and solutions encountered during setup |
| [docs/MOONLIGHT-TIPS.md](docs/MOONLIGHT-TIPS.md) | Moonlight client settings for the best experience |
| [configs/](configs/) | Reference config files from working Hyprland and SDDM setups |

## Workflow

1. Keep your physical monitor permanently connected to your **laptop**.
2. When you need the big PC, open **Moonlight** on your laptop.
3. Wake the PC via **Wake-on-LAN** (Moonlight can send magic packets).
4. Wait ~15-20 seconds for boot + auto-login.
5. Connect via Moonlight. You're in!
6. When done, shut down the PC from within the stream.
