#!/usr/bin/env bash
# Helldivers 2 GameGuard-Optimized Launch Script
# Run this instead of launching directly from Steam

set -euo pipefail

GAME_APPID=553850
STEAM_DIR="$HOME/.local/share/Steam"
PROTON_VERSION="proton_experimental"

# GameGuard-required environment variables
export PROTON_NO_ESYNC=1
export PROTON_NO_FSYNC=1
export DXVK_ASYNC=1
export PROTON_USE_WINED3D=1
export WINEDEBUG="-all"
export DXVK_LOG_LEVEL=none

# GameGuard network
export STEAM_NETWORKING_SOCKETS=1
export STEAM_NETWORKING_CERT_CUSTOM=1

# Disable Steam overlay (can conflict with GameGuard)
export STEAM_OVERLAY=0

# PRIME offload for Intel iGPU
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia

# Proton path
PROTON_PATH="$STEAM_DIR/compatibilitytools.d/$PROTON_VERSION/proton"
if [[ ! -f "$PROTON_PATH" ]]; then
    PROTON_PATH="$STEAM_DIR/steamapps/common/Proton - Experimental/proton"
fi

# Game path
GAME_PATH="$STEAM_DIR/steamapps/common/Helldivers 2/Helldivers2.exe"
COMPAT_DIR="$STEAM_DIR/steamapps/compatdata/$GAME_APPID"

mkdir -p "$COMPAT_DIR"

# Write compat config
cat > "$COMPAT_DIR/compatconfig.ini" << COMPATCFG
[Compatibility]
version=1
tool=$PROTON_VERSION
COMPATCFG

# Launch via Proton
echo "Launching Helldivers 2 with GameGuard compatibility..."
echo "Proton: $PROTON_PATH"
echo "Game: $GAME_PATH"

exec "$PROTON_PATH" run "$GAME_PATH" "$@"
