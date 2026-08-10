#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

SS_USER="shadowsocks"
SS_CONFIG="/etc/shadowsocks-libev/client.json"
CHAIN_OUT="SS_REDIR_OUT"
SS_PID=""

if ! id "$SS_USER" >/dev/null 2>&1; then
    log_err "User $SS_USER not found. Run: sudo shadowsocks/client/install.sh"
    exit 1
fi
if [[ ! -f "$SS_CONFIG" ]]; then
    log_err "Config not found: $SS_CONFIG. Run: sudo shadowsocks/client/configure.sh"
    exit 1
fi

SS_UID="$(id -u "$SS_USER")"

cleanup() {
    echo ""
    log_info "Cleaning up transparent proxy rules..."
    iptables -t nat -D OUTPUT -p tcp -j "$CHAIN_OUT" 2>/dev/null || true
    iptables -t nat -F "$CHAIN_OUT" 2>/dev/null || true
    iptables -t nat -X "$CHAIN_OUT" 2>/dev/null || true
    if [[ -n "$SS_PID" ]] && kill -0 "$SS_PID" 2>/dev/null; then
        kill "$SS_PID" 2>/dev/null || true
        wait "$SS_PID" 2>/dev/null || true
    fi
    log_info "Normal routing restored."
}
trap cleanup EXIT INT TERM

# Remove stale chain from a previous interrupted run
iptables -t nat -D OUTPUT -p tcp -j "$CHAIN_OUT" 2>/dev/null || true
iptables -t nat -F "$CHAIN_OUT" 2>/dev/null || true
iptables -t nat -X "$CHAIN_OUT" 2>/dev/null || true

log_info "Starting ss-redir as $SS_USER on 127.0.0.1:$SS_REDIR_PORT..."
sudo -u "$SS_USER" ss-redir -c "$SS_CONFIG" -u -b 127.0.0.1 -l "$SS_REDIR_PORT" &
SS_PID=$!
sleep 1
if ! kill -0 "$SS_PID" 2>/dev/null; then
    log_err "ss-redir failed to start"
    exit 1
fi

log_info "Installing iptables nat chain: $CHAIN_OUT"
iptables -t nat -N "$CHAIN_OUT"

# Traffic from the ss-redir process itself must not be redirected (loop prevention)
iptables -t nat -A "$CHAIN_OUT" -m owner --uid-owner "$SS_UID" -j RETURN

# The Shadowsocks server's own IP must bypass the proxy too -- otherwise any
# other connection to it (SSH, another service, etc.) gets redirected through
# ss-redir and relayed back to the same server, a self-referential loop.
iptables -t nat -A "$CHAIN_OUT" -d "$SERVER_PUBLIC_IP" -j RETURN

# Private and reserved ranges bypass the proxy
for net in 0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 169.254.0.0/16 \
           172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4; do
    iptables -t nat -A "$CHAIN_OUT" -d "$net" -j RETURN
done

iptables -t nat -A "$CHAIN_OUT" -p tcp -j REDIRECT --to-ports "$SS_REDIR_PORT"
iptables -t nat -A OUTPUT -p tcp -j "$CHAIN_OUT"

log_info "Transparent TCP proxy active on port $SS_REDIR_PORT."
log_info "Test: curl -4 https://ifconfig.me"
log_info "Press Ctrl+C to stop and remove rules."
wait "$SS_PID"
