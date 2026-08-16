#!/usr/bin/env python3
"""Send working Linux dataset report to Arrowhead Games + Steam Support."""
import smtplib
import ssl
import socket
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

EMAIL = "intricos777@gmail.com"
APP_PASS = "hydx wjpd hnxl exum"
TO = ["support@arrowheadgames.com", "steam-support@valvesoftware.com"]
DATE = __import__("datetime").date.today().isoformat()

body = f"""Hello Arrowhead Games and Valve Steam Support,

I am sharing a working Linux setup dataset for HELLDIVERS 2 (AppID 553850)
running under Proton on Linux. I am providing this data in the hope that
native Linux support can be improved, since GameGuard (nProtect) currently
blocks several Linux configurations with Error 113/114 despite the game
running correctly.

WORKING SYSTEM DATASET
======================
OS            : Garuda Linux (Arch-based)
Kernel        : 7.1.8-zen1-3-zen
CPU           : 12th Gen Intel Core i5-12450H
RAM           : 7.4 GiB
GPU (primary) : NVIDIA GeForce RTX 3050 Laptop GPU, 4 GiB
GPU (backup)  : Intel UHD Graphics (Alder Lake-P GT1 / ADL GT2)
NVIDIA driver : 610.57.04
Mesa          : 26.1.7-arch1.1
Vulkan        : 1.4.357
Proton        : Experimental (experimental-11.0-20260805)
Display       : X11
AppID         : 553850 (HELLDIVERS 2)

WORKING STEAM LAUNCH OPTIONS
============================
-tcp PROTON_NO_ESYNC=1 PROTON_NO_FSYNC=1 DXVK_ASYNC=1 PROTON_USE_WINED3D=1 STEAM_OVERLAY=0 __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia DXVK_FILTER_DEVICE_NAME="NVIDIA GeForce RTX 3050 Laptop GPU"

GAMEGUARD COMPATIBILITY MITIGATIONS
===================================
- PROTON_NO_ESYNC=1 / PROTON_NO_FSYNC=1  (reduce kernel calls)
- PROTON_USE_WINED3D=1                    (stability fallback)
- DXVK_ASYNC=1                            (async shader compilation)
- STEAM_OVERLAY=0                         (overlay off)
- -tcp                                    (force TCP networking)
- Ports 28910-28919 TCP/UDP opened        (GameGuard range)
- Kernel params: module.sig_unload=1 kernel.sysrq=1 kernel.yama.ptrace_scope=0

PERFORMANCE CONFIG (maximum FPS, minimum resources)
===================================================
- Fullscreen exclusive, VSync OFF, frame rate uncapped
- 50% render resolution + FSR 2 / DLSS upscaling
- All quality settings minimum (shadows, effects, textures, post-process off)
- Motion blur / DOF / bloom / AO all disabled
- NVIDIA Reflex On + Boost

GPU FAILOVER WATCHDOG (prevents overheat/crash, preserves saves)
================================================================
- Throttles NVIDIA at 80C (power cap 50W, clock cap 900MHz)
- Fails over to Intel iGPU at 88C (graceful restart in same prefix)
- Resets NVIDIA and returns when cooled below 62C for 60s
- Detects XID errors and reacts immediately
- Runs globally for ALL Steam games via systemd user service

Full toolkit, configs, and scripts are public:
https://github.com/intricos777-dot/steam-linux-optimizations

This is a real, reproducible setup on retail hardware. Please consider
official Linux/Proton support so GameGuard anti-cheat stops rejecting
configurations that demonstrably work.

Reporter: {EMAIL}
Date: {DATE}
Host: {socket.gethostname()}

Thank you for your time and for the great game. o7
"""

msg = MIMEMultipart()
msg["From"] = f"Helldivers 2 Linux Dataset <{EMAIL}>"
msg["To"] = ", ".join(TO)
msg["Subject"] = f"Working Helldivers 2 Linux/Proton dataset (AppID 553850) - {DATE} from intricos777"
msg.attach(MIMEText(body, "plain"))

ctx = ssl.create_default_context()
with smtplib.SMTP("smtp.gmail.com", 587) as srv:
    srv.starttls(context=ctx)
    srv.login(EMAIL, APP_PASS)
    srv.send_message(msg)
print("Email sent to:", TO)
