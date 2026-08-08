#!/usr/bin/env bash
# Adds a new named WireGuard client (peer) without disrupting existing
# connections: generates a keypair, allocates the next free IP in
# WG_VPN_CIDR, appends the peer to the server conf, applies it live via
# `wg set` (no interface restart), and writes the new client's config files.
# Run on the SERVER as root.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

GEN_DIR="$REPO_ROOT/wireguard/generated"
SERVER_CONF="$GEN_DIR/server_${WG_INTERFACE}.conf"

if [[ ! -f "$SERVER_CONF" ]]; then
    log_err "Server config not found: $SERVER_CONF"
    log_err "Run: sudo wireguard/server/configure.sh first."
    exit 1
fi

until [[ "${CLIENT:-}" =~ ^[a-zA-Z0-9_-]+$ ]]; do
    read -rp "Client name (alphanumeric, dash, underscore): " CLIENT
done

if grep -qE "^# ${CLIENT}\$" "$SERVER_CONF"; then
    log_err "Client '$CLIENT' already exists in $SERVER_CONF."
    exit 1
fi

if [[ "${WG_VPN_CIDR#*/}" != "24" ]]; then
    log_err "add-client.sh only supports /24 WireGuard subnets (WG_VPN_CIDR=$WG_VPN_CIDR)."
    log_err "Assign an IP by hand and extend this script for other prefixes."
    exit 1
fi

NET="${WG_VPN_CIDR%/*}"
BASE="${NET%.*}"
SERVER_HOST="${WG_SERVER_VPN_IP##*.}"
USED_HOSTS="$(grep -oP 'AllowedIPs = [\d.]+\.\K\d+(?=/32)' "$SERVER_CONF" || true)"

NEW_HOST=""
for h in $(seq 2 254); do
    [[ "$h" == "$SERVER_HOST" ]] && continue
    grep -qx "$h" <<< "$USED_HOSTS" && continue
    NEW_HOST="$h"
    break
done
if [[ -z "$NEW_HOST" ]]; then
    log_err "No free IPs left in $WG_VPN_CIDR"
    exit 1
fi
NEW_IP="${BASE}.${NEW_HOST}"

# Determine routing AllowedIPs for the client -- same logic as configure.sh
case "$WG_ROUTING_MODE" in
    1) CLIENT_ALLOWED_IPS="$WG_SERVER_VPN_IP/32" ;;
    2) CLIENT_ALLOWED_IPS="$WG_VPN_CIDR" ;;
    3) CLIENT_ALLOWED_IPS="0.0.0.0/0, ::/0" ;;
    4) CLIENT_ALLOWED_IPS="$WG_CLIENT_ALLOWED_IPS" ;;
    *) log_err "Unknown WG_ROUTING_MODE: $WG_ROUTING_MODE"; exit 1 ;;
esac

log_info "Generating keypair for '$CLIENT'..."
CLIENT_PRIV="$(wg genkey)"
CLIENT_PUB="$(printf '%s' "$CLIENT_PRIV" | wg pubkey)"
SERVER_PUB="$(grep '^PrivateKey' "$SERVER_CONF" | awk '{print $3}' | wg pubkey)"

PSK=""
if [[ "$WG_ENABLE_PSK" =~ ^[Yy] ]]; then
    PSK="$(wg genpsk)"
fi
PSK_LINE=""
[[ -n "$PSK" ]] && PSK_LINE="PresharedKey = $PSK"

{
    echo ""
    echo "[Peer]"
    echo "# $CLIENT"
    echo "PublicKey = $CLIENT_PUB"
    [[ -n "$PSK_LINE" ]] && echo "$PSK_LINE"
    echo "AllowedIPs = $NEW_IP/32"
} >> "$SERVER_CONF"
chmod 600 "$SERVER_CONF"

if [[ "$SERVER_CONF" != "$GEN_DIR/server_wg0.conf" ]]; then
    cp "$SERVER_CONF" "$GEN_DIR/server_wg0.conf"
fi

# Keep the applied system config in sync (for persistence across reboots).
DST="/etc/wireguard/${WG_INTERFACE}.conf"
if [[ -f "$DST" ]]; then
    install -m 600 "$SERVER_CONF" "$DST"
fi

# Apply live so currently-connected peers are never interrupted.
if ip link show "$WG_INTERFACE" &>/dev/null; then
    if [[ -n "$PSK" ]]; then
        wg set "$WG_INTERFACE" peer "$CLIENT_PUB" preshared-key <(printf '%s' "$PSK") allowed-ips "$NEW_IP/32"
    else
        wg set "$WG_INTERFACE" peer "$CLIENT_PUB" allowed-ips "$NEW_IP/32"
    fi
    log_info "Applied live to $WG_INTERFACE (no restart; existing peers unaffected)."
else
    log_info "$WG_INTERFACE is not currently up; peer added to config only."
fi

write_client_conf() {
    local dst="$1"
    {
        echo "[Interface]"
        echo "PrivateKey = $CLIENT_PRIV"
        echo "Address = $NEW_IP/32"
        [[ -n "$WG_DNS" ]] && echo "DNS = $WG_DNS"
        echo ""
        echo "[Peer]"
        echo "PublicKey = $SERVER_PUB"
        [[ -n "$PSK_LINE" ]] && echo "$PSK_LINE"
        echo "Endpoint = $SERVER_PUBLIC_IP:$WG_PORT"
        echo "AllowedIPs = $CLIENT_ALLOWED_IPS"
        echo "PersistentKeepalive = 25"
    } > "$dst"
    chmod 600 "$dst"
}

write_client_conf "$GEN_DIR/${CLIENT}_linux.conf"
write_client_conf "$GEN_DIR/${CLIENT}_android.conf"

if command -v qrencode >/dev/null 2>&1; then
    qrencode -o "$GEN_DIR/${CLIENT}_android.png" < "$GEN_DIR/${CLIENT}_android.conf"
    log_info "Android QR: $GEN_DIR/${CLIENT}_android.png"
fi

log_info "Client '$CLIENT' added at $NEW_IP/32"
log_info "  $GEN_DIR/${CLIENT}_linux.conf"
log_info "  $GEN_DIR/${CLIENT}_android.conf"
