# Steam Linux Optimizations — Running Helldivers 2 (and other games) on Linux

Working, tested setup for running **HELLDIVERS™ 2** (and other Steam games) on Linux with Proton, including GameGuard compatibility, GPU failover/overheating protection, and maximum-performance graphics tuning.

**Author:** intricos777 (intricos777-dot)
**Tested on:** Garuda Linux, kernel 7.1.8-zen1-3-zen, ASUS TUF Dash F15 FX517ZC

---

## 📋 System Specs (test platform)

| Component | Details |
|-----------|---------|
| **OS** | Garuda Linux (Arch-based) |
| **Kernel** | 7.1.8-zen1-3-zen |
| **CPU** | 12th Gen Intel Core i5-12450H (Alder Lake) |
| **RAM** | 7.4 GiB |
| **GPU (primary)** | NVIDIA GeForce RTX 3050 Laptop GPU, 4 GiB |
| **GPU (backup)** | Intel UHD Graphics (Alder Lake-P GT1 / ADL GT2) |
| **NVIDIA driver** | 610.57.04 |
| **Mesa** | 26.1.7-arch1.1 |
| **Vulkan** | 1.4.357 |
| **Proton** | Experimental (experimental-11.0-20260805) |
| **Display** | X11 |

---

## ✅ What Works

- **Helldivers 2 (AppID 553850)** — launchable via Steam with Proton Experimental
- **GPU failover watchdog** — global, protects ALL Steam games from overheating/crashes
- **GameGuard** (nProtect) — partial compatibility via environment overrides (see caveats)
- **NVIDIA-first + Intel iGPU fallback** rendering via DXVK device filtering
- **Port forwarding / UPnP** for GameGuard + Steam network
- **Performance graphics** — 50% render + FSR, all settings minimum, VSync off

---

## 🚀 Quick Start

### 1. Clone & run the compatibility check

```bash
git clone https://github.com/intricos777-dot/steam-linux-optimizations
cd steam-linux-optimizations
./gameguard-compat check
```

### 2. Apply NVIDIA-first + Intel backup

```bash
sudo cp xorg.conf.d/10-nvidia-prime.conf /etc/X11/xorg.conf.d/
sudo cp modprobe.d/i915.conf /etc/modprobe.d/
sudo cp profile.d/prime-offload.sh /etc/profile.d/
```

### 3. Install the global GPU watchdog

```bash
mkdir -p ~/.config/systemd/user
cp systemd/gpu-watchdog.service ~/.config/systemd/user/
cp scripts/gpu-watchdog.sh ~/.local/bin/gpu-watchdog
chmod +x ~/.local/bin/gpu-watchdog
systemctl --user daemon-reload
systemctl --user enable --now gpu-watchdog
gpu-watchdog status
```

The watchdog **auto-detects any running Steam game**, throttles NVIDIA before overheating, fails over to the Intel iGPU if critical, and returns to NVIDIA when cool — all while preserving your game saves (same prefix).

### 4. Steam launch options (for HD2)

```
-tcp PROTON_NO_ESYNC=1 PROTON_NO_FSYNC=1 DXVK_ASYNC=1 PROTON_USE_WINED3D=1 STEAM_OVERLAY=0 __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia DXVK_FILTER_DEVICE_NAME="NVIDIA GeForce RTX 3050 Laptop GPU"
```

### 5. Apply performance graphics config

```bash
./scripts/helldivers2-graphics-config.sh
```

---

## 🌡️ GPU Failover Watchdog

`scripts/gpu-watchdog.sh` — runs as a systemd user service, monitors all games.

| Threshold | Action |
|-----------|--------|
| **80 °C** | Throttle: power cap 50 W, clock cap 900 MHz |
| **88 °C** | Failover: graceful game close → Intel iGPU (state preserved) |
| **62 °C** (stable 60 s) | Recover: reset NVIDIA → relaunch on NVIDIA |
| **XID error** | Immediate failover to Intel |

RTX 3050 reference limits: slowdown 97 °C, shutdown 100 °C.

> **Note:** DXVK/Proton binds one GPU per process — failover is a *graceful restart in the same prefix*, not a live mid-game swap. Autosaves survive.

---

## 🎮 In-Game Settings (verified)

| Setting | Value |
|---------|-------|
| Display Mode | Fullscreen Exclusive |
| VSync | **OFF** |
| Frame Rate Limit | Uncapped (0) |
| Render Resolution | 50% |
| Upscaling | FSR 2 / DLSS |
| All quality presets | **Minimum** |
| Motion Blur / DOF / Bloom / AO | **OFF** |
| NVIDIA Reflex | On + Boost |

Config lives at:
```
~/.local/share/Steam/steamapps/compatdata/553850/pfx/drive_c/users/steamuser/AppData/Local/Helldivers2/Saved/Config/Windows/
```

---

## 🔧 GameGuard Compatibility Notes

GameGuard (nProtect) does not officially support Linux/Proton. Working mitigations:

| Flag | Effect |
|------|--------|
| `PROTON_NO_ESYNC=1` `PROTON_NO_FSYNC=1` | Reduce kernel calls GameGuard dislikes |
| `PROTON_USE_WINED3D=1` | Software fallback stability |
| `DXVK_ASYNC=1` | Async shader compilation (fewer stutters) |
| `STEAM_OVERLAY=0` | Overlay off (anti-cheat often conflicts) |
| `-tcp` | Force TCP networking for GameGuard WebSocket |
| Ports `28910-28919` TCP/UDP | GameGuard communication range |

Wrappers: `~/.local/bin/gameguard-wine-wrapper`, `~/.local/bin/gg-proton-launch`

---

## 🧩 Directory Layout

```
steam-linux-optimizations/
├── README.md
├── gameguard-compat              # compatibility checker (Python)
├── tools/
│   └── gameguard-compat.py
├── scripts/
│   ├── gpu-watchdog.sh           # global GPU failover (all games)
│   ├── helldivers2-launch.sh
│   ├── helldivers2-complete-launch.sh
│   ├── helldivers2-graphics-config.sh
│   ├── gameguard-prepare-network.sh
│   └── fix-wine-proton.sh
├── systemd/
│   ├── gpu-watchdog.service
│   └── gameguard-network.service
├── config/
│   ├── GameUserSettings.ini
│   ├── Engine.ini
│   └── Scalability.ini
├── graphics/                     # Steam launch options reference
├── xorg.conf.d/
│   └── 10-nvidia-prime.conf
├── modprobe.d/
│   └── i915.conf
└── profile.d/
    └── prime-offload.sh
```

---

## ⚠️ Known Caveats

1. **GameGuard** may still show Error 113/114 (unsupported OS) — nProtect has no official Linux support; the flags above are the maximum achievable workaround.
2. **GPU failover** is graceful-restart, not seamless hot-swap (DXVK limitation).
3. **Port forwarding** via local miniupnpd only works if your router exposes the IGD externally; otherwise configure the ports on the router itself.
4. Kernel params `module.sig_unload=1 kernel.sysrq=1 kernel.yama.ptrace_scope=0` help some anti-cheat tools; add to `/etc/default/grub` then `grub-mkconfig`.

---

## 📧 Feedback / Support

This repo is a living dataset of what works on real hardware. Questions, PRs, and working-setup reports welcome.

---

MIT License — do whatever, just credit the sources. Built from real testing, not theory.
