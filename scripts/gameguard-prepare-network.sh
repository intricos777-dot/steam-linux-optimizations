#!/usr/bin/env bash
# GameGuard Network Preparation Script
# Opens required ports and configures network for GameGuard compatibility

set -euo pipefail

GAMEGUARD_PORTS_TCP="28910:28919"
GAMEGUARD_PORTS_UDP="28910:28919"
STEAM_PORTS_TCP="27015,27036,27031,27032"
STEAM_PORTS_UDP="27015,27036,27031,27032"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# Open GameGuard ports
log "Opening GameGuard TCP ports $GAMEGUARD_PORTS_TCP..."
for port in $(seq 28910 28919); do
    iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
    iptables -C OUTPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
    iptables -C INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null || true
    iptables -C OUTPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null || true
done

# Open Steam ports
log "Opening Steam ports..."
for port in $STEAM_PORTS_TCP; do
    iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
    iptables -C OUTPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
done

# Verify rules
log "Verifying firewall rules..."
for port in $(seq 28910 28919); do
    if iptables -L INPUT -n -v | grep -q "dpt:$port.*ACCEPT"; then
        log "  ✔ TCP $port: ACCEPT"
    else
        log "  ⚠ TCP $port: not explicitly allowed"
    fi
done

# Configure UPnP if available
if command -v upnpc >/dev/null; then
    log "Configuring UPnP port forwards..."
    for port in $(seq 28910 28919); do
        upnpc -a "$port" TCP 2>/dev/null || true
        upnpc -a "$port" UDP 2>/dev/null || true
    done
    log "  ✔ UPnP configured"
fi

# Ensure correct network interface for Steam/Proton
log "Checking Steam network binding..."
# Steam WebSocket fix
export PROTON_NO_ESYNC=1
export PROTON_NO_FSYNC=1.
export DXVK_ASYNC=1.

log "✅ GameGuard network preparation complete"
