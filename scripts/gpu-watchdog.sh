#!/usr/bin/env bash
# GPU Failover Watchdog - Global (all Steam games)
# Monitors NVIDIA GPU health. On overheat/crash:
#   1. Proactively throttles (power + clock caps) before critical
#   2. Gracefully relaunches the running game on Intel iGPU (same prefix = state preserved)
#   3. Resets NVIDIA when cooled, relaunches back on NVIDIA
#
# Auto-detects ANY running Steam game via process scan.
#
# Usage: gpu-watchdog.sh [start|stop|status]
# Runs as: systemd user service (see below)

set -uo pipefail

STEAM_DIR="$HOME/.local/share/Steam"
PID_FILE="/tmp/gpu-watchdog.pid"
LOG_FILE="/tmp/gpu-watchdog.log"
LOCK_FILE="/tmp/gpu-watchdog.lock"

# NVIDIA: RTX 3050 Laptop (T.Limit 97C, Shutdown 100C)
TEMP_HIGH=80        # start throttling here
TEMP_CRITICAL=88    # failover to Intel here
TEMP_RECOVER=62     # NVIDIA is safe to use again here
POLL_SECS=5
STABLE_COOL_CYCLES=12   # ~60s of cooldown before switching back
PWR_CAP=50               # watts while throttled

INTEL_VK_NAME="Intel(R) Graphics (ADL GT2)"

GPU_MODE="auto"      # auto | nvidia | intel
COOL_CYCLES=0

log() { echo "$(date '+%F %T') $*" | tee -a "$LOG_FILE"; }

acquire_lock() {
    if ! mkdir "$LOCK_FILE" 2>/dev/null; then
        echo "watchdog already running (lock: $LOCK_FILE)" >&2
        exit 1
    fi
    echo $$ > "$PID_FILE"
}

release_lock() { rm -rf "$LOCK_FILE"; }
trap release_lock EXIT

nvidia_alive() { nvidia-smi -q -d TEMPERATURE >/dev/null 2>&1; }

nvidia_temp() { nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null; }

# --- GPU control ---------------------------------------------------------
throttle_nvidia() {
    log "THROTTLE: capping power to ${PWR_CAP}W"
    nvidia-smi -pl "$PWR_CAP" >/dev/null 2>&1
    nvidia-smi -lgc 0,900 >/dev/null 2>&1     # lock graphics clock low
    nvidia-smi -lmc 405 >/dev/null 2>&1       # lower mem clock (auto)
}

unthrottle_nvidia() {
    log "UNTHROTTLE: restoring power limit"
    nvidia-smi -pl -1 >/dev/null 2>&1          # -1 = default
    nvidia-smi -rgc >/dev/null 2>&1            # reset graphics clocks
    nvidia-smi -rmc >/dev/null 2>&1            # reset memory clocks
    nvidia-smi -pm 1 >/dev/null 2>&1           # persistence mode on
}

reset_nvidia() {
    log "RESET: attempting NVIDIA driver/state reset"
    nvidia-smi -pm 0 >/dev/null 2>&1
    sleep 1
    nvidia-smi -pm 1 >/dev/null 2>&1
    unthrottle_nvidia
    if ! nvidia_alive; then
        log "RESET: driver unresponsive - trying module reload"
        if lsmod | grep -q '^nvidia_drm'; then
            sudo rmmod nvidia_drm nvidia_modeset nvidia_uvm nvidia 2>/dev/null
            sleep 2
            sudo modprobe nvidia_drm 2>/dev/null
            sleep 2
        fi
    fi
}

# --- Game control --------------------------------------------------------
# Auto-detect the currently running Steam game (works for ALL games)
GAME_EXE=""
GAME_NAME=""
GAME_APPID=""

detect_game() {
    local line exe
    line=$(ps -eo args 2>/dev/null | grep -E "steamapps/common/.*\.exe" | grep -v grep | head -1)
    if [[ -z "$line" ]]; then
        GAME_EXE=""; GAME_NAME=""; GAME_APPID=""
        return 1
    fi
    # Extract the .exe path
    exe=$(echo "$line" | grep -oE "steamapps/common/[^ ]+\.exe" | head -1)
    [[ -z "$exe" ]] && return 1
    GAME_EXE="$exe"
    GAME_NAME=$(basename "$(dirname "$exe")")
    # Find AppID from manifest whose installdir matches
    local manifest dir
    for manifest in "$STEAM_DIR"/steamapps/appmanifest_*.acf; do
        dir=$(grep '"installdir"' "$manifest" | sed 's/.*"installdir"[[:space:]]*"\(.*\)"/\1/')
        if [[ "$dir" == "$GAME_NAME" ]]; then
            GAME_APPID=$(basename "$manifest" | sed 's/appmanifest_//;s/\.acf//')
            break
        fi
    done
    [[ -n "$GAME_APPID" ]] && COMPAT_DIR="$STEAM_DIR/steamapps/compatdata/$GAME_APPID"
    return 0
}

game_running() {
    ps -eo args 2>/dev/null | grep -qE "steamapps/common/.*\.exe"
}

stop_game() {
    if [[ -n "$GAME_EXE" ]]; then
        local base
        base=$(basename "$GAME_EXE")
        log "STOP: gracefully closing $GAME_NAME ($base) - autosaves in prefix"
        pkill -f "$base" 2>/dev/null
        sleep 5
        pkill -9 -f "$base" 2>/dev/null
    else
        pkill -f "\.exe" 2>/dev/null
    fi
    sleep 3
}

start_game() {
    local gpu="$1"
    local vkname
    detect_game || {
        log "START: no game detected to relaunch"
        return 1
    }
    if [[ "$gpu" == "intel" ]]; then
        vkname="$INTEL_VK_NAME"
        log "START: relaunching $GAME_NAME on INTEL iGPU"
    else
        vkname="NVIDIA GeForce RTX 3050 Laptop GPU"
        log "START: relaunching $GAME_NAME on NVIDIA GPU"
    fi

    # Find a Proton tool in preference order
    local proton=""
    for cand in \
        "$STEAM_DIR/compatibilitytools.d/proton_experimental/proton" \
        "$STEAM_DIR/steamapps/common/Proton - Experimental/proton" \
        "$STEAM_DIR/steamapps/common/Proton Hotfix/proton" \
        "$STEAM_DIR/steamapps/common/Proton 9.0/proton"; do
        [[ -f "$cand" ]] && proton="$cand" && break
    done
    if [[ -z "$proton" ]]; then
        log "START: no Proton found!"
        return 1
    fi

    nohup env \
        PROTON_NO_ESYNC=1 PROTON_NO_FSYNC=1 PROTON_USE_WINED3D=1 \
        DXVK_ASYNC=1 DXVK_LOG_LEVEL=none WINEDEBUG="-all" \
        STEAM_OVERLAY=0 STEAM_NETWORKING_SOCKETS=1 \
        __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia \
        DXVK_FILTER_DEVICE_NAME="$vkname" \
        "$proton" run "$GAME_EXE" >> "$LOG_FILE" 2>&1 &
}

xid_error() {
    local last
    last=$(dmesg 2>/dev/null | grep -i "NVRM: Xid" | tail -1)
    [[ -n "$last" && "$last" != "$(cat /tmp/gpu-xid-last 2>/dev/null)" ]]
}

failover_to_intel() {
    log "FAILOVER: NVIDIA problem detected -> Intel iGPU (state preserved)"
    GPU_MODE="intel"
    COOL_CYCLES=0
    stop_game
    reset_nvidia
    start_game intel
}

recover_to_nvidia() {
    log "RECOVER: NVIDIA cooled/stable -> resetting and returning to NVIDIA"
    GPU_MODE="nvidia"
    COOL_CYCLES=0
    stop_game
    reset_nvidia
    start_game nvidia
}

# --- Mode selection ------------------------------------------------------
select_mode() {
    if [[ "$GPU_MODE" == "auto" ]]; then
        echo "nvidia"
    else
        echo "$GPU_MODE"
    fi
}

# ==========================================================================
# MAIN
# ==========================================================================
case "${1:-start}" in
    stop)
        [[ -f "$PID_FILE" ]] && kill "$(cat "$PID_FILE")" 2>/dev/null
        rm -f "$PID_FILE"; rm -rf "$LOCK_FILE"
        echo "watchdog stopped"
        exit 0
        ;;
    status)
        if [[ -d "$LOCK_FILE" ]]; then
            echo "watchdog RUNNING (pid $(cat "$PID_FILE"))"
            echo "mode: $(cat "$LOG_FILE" 2>/dev/null | tail -5)"
        else
            echo "watchdog NOT running"
        fi
        exit 0
        ;;
    start) ;;&
    --daemon) ;;
    *)
        if [[ -n "${1:-}" && "${1:-}" != "start" ]]; then
            echo "usage: $0 [start|stop|status]" >&2; exit 1
        fi
        ;;
esac

acquire_lock
log "watchdog started (poll=${POLL_SECS}s high=${TEMP_HIGH}C crit=${TEMP_CRITICAL}C recover=${TEMP_RECOVER}C)"
GPU_MODE="$(select_mode)"
THROTTLED="no"
LAST_XID=""

while true; do
    if nvidia_alive; then
        TEMP=$(nvidia_temp)
        XID=$(dmesg 2>/dev/null | grep -c "NVRM: Xid")
    else
        TEMP=""
        XID="ERR"
    fi

    # XID errors = GPU crash/rest during game = failover
    if [[ "$XID" != "ERR" && -n "$XID" ]] && [[ "$LAST_XID" != "$XID" && "$XID" -gt 0 ]]; then
        LAST_XID="$XID"
        if game_running || [[ "$GPU_MODE" != "intel" ]]; then
            log "XID event #$XID detected"
            failover_to_intel
        fi
        sleep "$POLL_SECS"; continue
    fi

    if [[ "$GPU_MODE" == "nvidia" && -n "$TEMP" ]]; then
        if (( TEMP >= TEMP_CRITICAL )); then
            log "CRITICAL temp ${TEMP}C"
            failover_to_intel
        elif (( TEMP >= TEMP_HIGH )) && [[ "$THROTTLED" != "yes" ]]; then
            THROTTLED="yes"; throttle_nvidia
        elif (( TEMP < TEMP_HIGH - 5 )) && [[ "$THROTTLED" == "yes" ]]; then
            THROTTLED="no"; unthrottle_nvidia
        fi
    elif [[ "$GPU_MODE" == "intel" ]]; then
        # NVIDIA cooling down in background - count stable cycles
        if [[ -n "$TEMP" && "$TEMP" -lt "$TEMP_RECOVER" ]] || ! nvidia_alive; then
            if [[ -n "$TEMP" ]]; then COOL_CYCLES=$((COOL_CYCLES + 1)); fi
            if (( COOL_CYCLES >= STABLE_COOL_CYCLES )); then
                recover_to_nvidia
            fi
        else
            COOL_CYCLES=0
        fi
    fi

    sleep "$POLL_SECS"
done
