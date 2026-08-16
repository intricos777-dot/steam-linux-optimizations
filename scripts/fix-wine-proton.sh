#!/usr/bin/env bash
# Wine/Proton Fix & GameGuard Wrapper Setup
# Fixes Wine/Proton issues and creates GameGuard-compatible wrapper

set -euo pipefail

log() { echo "[$(date '+%H:%M:%S')] $*"; }
warn() { echo "[$(date '+%H:%M:%S')] ⚠ $*"; }
err() { echo "[$(date '+%H:%M:%S')] ❌ $*"; }

STEAM_DIR="$HOME/.local/share/Steam"
COMPAT_DIR="$STEAM_DIR/steamapps/compatdata/553850"
PREFIX_DIR="$COMPAT_DIR/pfx"

log "=== Wine/Proton Fix & GameGuard Wrapper Setup ==="

# 1. Fix Steam Proton installations
log "1. Ensuring Proton-Experimental and Proton-GE are installed..."
flatpak install flathub com.valvesoftware.Steam.CompatibilityTool.Proton-Experimental -y 2>/dev/null || true
flatpak install flathub com.valvesoftware.Steam.CompatibilityTool.Proton-GE -y 2>/dev/null || true

# 2. Fix Wine prefix
log "2. Repairing Wine prefix for Helldivers 2..."
if [[ -d "$PREFIX_DIR" ]]; then
    log "   Backing up existing prefix..."
    mv "$PREFIX_DIR" "${PREFIX_DIR}.backup.$(date +%s)"
fi

mkdir -p "$PREFIX_DIR"

# 3. Create clean Wine prefix with proper DLL overrides
log "3. Creating clean Wine prefix with GameGuard-friendly overrides..."

export WINEPREFIX="$PREFIX_DIR"
export WINEDLLOVERRIDES="ntdll,kernel32,kernelbase,advapi32,user32,gdi32,ws2_32,iphlpapi,dbghelp,version=n,b"
export WINEDEBUG="-all"

# Initialize prefix
wineboot --init 2>/dev/null || true

# 4. Install required Windows components via winetricks
log "4. Installing required Windows components..."
if command -v winetricks >/dev/null; then
    winetricks --unattended vcrun2019 vcrun2022 d3dcompiler_47 dxvk 2>/dev/null || true
else
    warn "winetricks not installed, skipping VC++/DXVK install"
fi

# 5. Set registry keys for GameGuard compatibility
log "5. Setting GameGuard-friendly registry keys..."
cat > /tmp/gg_registry.reg << 'REG'
Windows Registry Editor Version 5.00

; GameGuard compatibility
[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
"ntdll"="native,builtin"
"kernel32"="native,builtin"
"kernelbase"="native,builtin"
"advapi32"="native,builtin"
"user32"="native,builtin"
"gdi32"="native,builtin"
"ws2_32"="native,builtin"
"iphlpapi"="native,builtin"
"dbghelp"="native,builtin"
"version"="native,builtin"

; Disable Wine debugger
[HKEY_CURRENT_USER\Software\Wine\WineDbg]
"ShowCrashDialog"=dword:00000000

; Network settings for GameGuard
[HKEY_CURRENT_USER\Software\Wine\Network]
"UseNativeIPHLPAPI"="1"

; Graphics
[HKEY_CURRENT_USER\Software\Wine\Direct3D]
"dxgi"="builtin"
"d3d11"="builtin"
"d3d10"="builtin"
"d3d9"="builtin"

; Disable Wine crash dialog
[HKEY_CURRENT_USER\Software\Wine\WineDbg]
"ShowCrashDialog"=dword:00000000
REG

wine regedit /tmp/gg_registry.reg 2>/dev/null || true

# 6. Create GameGuard-specific wrapper script
log "6. Creating GameGuard Wine wrapper..."
WRAPPER_DIR="$HOME/.local/bin"
mkdir -p "$WRAPPER_DIR"

cat > "$WRAPPER_DIR/gameguard-wine-wrapper" << 'WRAPPER'
#!/usr/bin/env bash
# GameGuard Wine Wrapper
# Runs Wine with GameGuard-optimized environment

export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/Steam/steamapps/compatdata/553850/pfx}"
export WINEDLLOVERRIDES="ntdll,kernel32,kernelbase,advapi32,user32,gdi32,ws2_32,iphlpapi,dbghelp,version=n,b"
export WINEDEBUG="-all"
export WINEESYNC=0
export WINEFSYNC=0

# GameGuard needs these
export WINE_LARGE_ADDRESS_AWARE=1
export __GL_THREADED_OPTIMIZATIONS=1

# PRIME offload
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only

# DXVK
export DXVK_ASYNC=1
export DXVK_HUD=0
export DXVK_LOG_LEVEL=none

# Disable Wine crash dialog
export WINEDEBUG="-all"
export WINEDBG="-all"

exec wine "$@"
WRAPPER

chmod +x "$WRAPPER_DIR/gameguard-wine-wrapper"

# 7. Create Proton-compatible wrapper for Steam
log "7. Creating Proton launch wrapper..."
cat > "$WRAPPER_DIR/gg-proton-launch" << 'PROTON_WRAPPER'
#!/usr/bin/env bash
# GameGuard Proton Launch Wrapper
# Use this as Steam launch command: gg-proton-launch %command%

STEAM_DIR="$HOME/.local/share/Steam"
PROTON_PATH="$STEAM_DIR/compatibilitytools.d/proton_experimental/proton"
[[ -f "$PROTON_PATH" ]] || PROTON_PATH="$STEAM_DIR/steamapps/common/Proton - Experimental/proton"

export PROTON_NO_ESYNC=1
export PROTON_NO_FSYNC=1
export PROTON_USE_WINED3D=1
export DXVK_ASYNC=1
export DXVK_HUD=0
export DXVK_LOG_LEVEL=none
export WINEDEBUG="-all"
export WINEDBG="-all"
export STEAM_OVERLAY=0
export STEAM_NETWORKING_SOCKETS=1

export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only

exec "$PROTON_PATH" run "$@"
PROTON_WRAPPER

chmod +x "$WRAPPER_DIR/gg-proton-launch"

# 8. Fix Steam launch options
log "8. Updating Steam launch options..."
LAUNCH_OPTS="gg-proton-launch %command%"
STEAM_LAUNCH_FILE="$COMPAT_DIR/launch_options.txt"
echo "$LAUNCH_OPTS" > "$STEAM_LAUNCH_FILE"

# 9. Fix dxvk cache
log "9. Clearing DXVK/VKD3D cache..."
rm -rf "$HOME/.cache/dxvk" "$HOME/.cache/vkd3d" 2>/dev/null || true
mkdir -p "$HOME/.cache/dxvk" "$HOME/.cache/vkd3d"

# 10. Set proper permissions
log "10. Fixing permissions..."
chown -R "$USER:$USER" "$PREFIX_DIR" 2>/dev/null || true
chmod -R u+rwX "$PREFIX_DIR" 2>/dev/null || true

# 11. Verify Wine installation
log "11. Verifying Wine installation..."
if command -v wine >/dev/null; then
    wine --version
    wine64 --version
else
    err "Wine not found! Installing..."
    sudo pacman -S wine wine-gecko wine-mono --noconfirm 2>/dev/null || true
fi

log "=== Wine/Proton Fix Complete ==="
echo ""
echo "Created wrappers:"
echo "  $WRAPPER_DIR/gameguard-wine-wrapper  - Raw Wine wrapper"
echo "  $WRAPPER_DIR/gg-proton-launch        - Proton launch wrapper (for Steam)"
echo ""
echo "Steam Launch Options (copy to Steam > Properties > Launch Options):"
echo "  gg-proton-launch %command%"
echo ""
echo "Or manually:"
echo "  PROTON_NO_ESYNC=1 PROTON_NO_FSYNC=1 DXVK_ASYNC=1 PROTON_USE_WINED3D=1 STEAM_OVERLAY=0 %command%"
