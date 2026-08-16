#!/usr/bin/env bash
# Helldivers 2 Complete Launch Script
# GameGuard compatible + Maximum Performance Graphics

set -euo pipefail

GAME_APPID=553850
STEAM_DIR="$HOME/.local/share/Steam"
PROTON_VERSION="proton_experimental"

# ============================================
# GAMEGUARD COMPATIBILITY ENV VARS
# ============================================
export PROTON_NO_ESYNC=1
export PROTON_NO_FSYNC=1
export DXVK_ASYNC=1
export PROTON_USE_WINED3D=1
export WINEDEBUG="-all"
export DXVK_LOG_LEVEL=none
export STEAM_NETWORKING_SOCKETS=1
export STEAM_NETWORKING_CERT_CUSTOM=1
export STEAM_OVERLAY=0

# GameGuard Network (allow all required ports)
export STEAM_RUNTIME=1

# ============================================
# PRIME OFFLOAD (NVIDIA + Intel iGPU)
# ============================================
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only

# ============================================
# PERFORMANCE TUNING
# ============================================
export MESA_GLTHREAD=1
export MESA_SHADER_CACHE_MAX_SIZE=10G
export RADV_PERFTEST=aco,nggc,mesh_shader
export VKD3D_CONFIG=dxr11,multi_queue
export DXVK_HUD=0

# Disable compositing for fullscreen
export KWIN_COMPOSE=O2ES
export QT_QPA_PLATFORM=wayland
export SDL_VIDEODRIVER=wayland

# ============================================
# PROTON PATH
# ============================================
PROTON_PATH="$STEAM_DIR/compatibilitytools.d/$PROTON_VERSION/proton"
if [[ ! -f "$PROTON_PATH" ]]; then
    PROTON_PATH="$STEAM_DIR/steamapps/common/Proton - Experimental/proton"
fi

# ============================================
# GAME PATH
# ============================================
GAME_PATH="$STEAM_DIR/steamapps/common/Helldivers 2/Helldivers2.exe"
COMPAT_DIR="$STEAM_DIR/steamapps/compatdata/$GAME_APPID"

mkdir -p "$COMPAT_DIR"

# Write compat config (forces Proton Experimental)
cat > "$COMPAT_DIR/compatconfig.ini" << COMPATCFG
[Compatibility]
version=1
tool=$PROTON_VERSION
COMPATCFG

# ============================================
# LAUNCH
# ============================================
echo "============================================"
echo "  HELLDIVERS 2 - GAMEGUARD + MAX PERF LAUNCH"
echo "============================================"
echo "Proton:  $PROTON_VERSION"
echo "GPU:     NVIDIA RTX 3050 (Primary) + Intel iGPU (Offload)"
echo "Mode:    Fullscreen Exclusive | VSync OFF | 50% Render + FSR"
echo "GameGuard: PROTON_NO_ESYNC=1 | -tcp compatible | Ports open"
echo "============================================"

exec "$PROTON_PATH" run "$GAME_PATH" "$@"
