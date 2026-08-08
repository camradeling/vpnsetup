#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

GEN_DIR="$REPO_ROOT/wireguard/generated"
mkdir -p "$GEN_DIR"
chmod 700 "$GEN_DIR"
umask 077

# Determine routing AllowedIPs for client based on mode
case "$WG_ROUTING_MODE" in
    1) WG_CLIENT_ALLOWED_IPS="$WG_SERVER_VPN_IP/32" ;;
    2) WG_CLIENT_ALLOWED_IPS="$WG_VPN_CIDR" ;;
    3) WG_CLIENT_ALLOWED_IPS="0.0.0.0/0, ::/0" ;;
    4) : ;;  # Use WG_CLIENT_ALLOWED_IPS as-is from config.env
    *) log_err "Unknown WG_ROUTING_MODE: $WG_ROUTING_MODE"; exit 1 ;;
esac

# Detect outbound interface
WG_OUT_IFACE="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
if [[ -z "$WG_OUT_IFACE" ]]; then
    log_err "Could not detect outbound interface from default route."
    exit 1
fi

SERVER_VPN_ADDR="$WG_SERVER_VPN_IP/${WG_VPN_CIDR#*/}"

# Generate keypairs
log_info "Generating WireGuard keypairs..."
SERVER_PRIV="$(wg genkey)"
SERVER_PUB="$(printf '%s' "$SERVER_PRIV" | wg pubkey)"
CLIENT_PRIV="$(wg genkey)"
CLIENT_PUB="$(printf '%s' "$CLIENT_PRIV" | wg pubkey)"
PSK=""
if [[ "$WG_ENABLE_PSK" =~ ^[Yy] ]]; then
    PSK="$(wg genpsk)"
fi

# Build optional PostUp/PostDown lines
POST_UP=""
POST_DOWN=""
if [[ "$WG_ENABLE_NAT" =~ ^[Yy] ]]; then
    POST_UP="PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${WG_OUT_IFACE} -j MASQUERADE"
    POST_DOWN="PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${WG_OUT_IFACE} -j MASQUERADE"
fi

PSK_LINE=""
if [[ -n "$PSK" ]]; then
    PSK_LINE="PresharedKey = $PSK"
fi

# Write server config
SERVER_CONF="$GEN_DIR/server_${WG_INTERFACE}.conf"
{
    echo "[Interface]"
    echo "Address = $SERVER_VPN_ADDR"
    echo "ListenPort = $WG_PORT"
    echo "PrivateKey = $SERVER_PRIV"
    [[ -n "$POST_UP" ]]   && echo "$POST_UP"
    [[ -n "$POST_DOWN" ]] && echo "$POST_DOWN"
    echo ""
    echo "[Peer]"
    echo "# $WG_CLIENT_NAME"
    echo "PublicKey = $CLIENT_PUB"
    [[ -n "$PSK_LINE" ]] && echo "$PSK_LINE"
    echo "AllowedIPs = $WG_CLIENT_IP/32"
} > "$SERVER_CONF"
chmod 600 "$SERVER_CONF"

# Write client configs (Linux and Android share the same content)
write_client_conf() {
    local dst="$1"
    {
        echo "[Interface]"
        echo "PrivateKey = $CLIENT_PRIV"
        echo "Address = $WG_CLIENT_IP/32"
        [[ -n "$WG_DNS" ]] && echo "DNS = $WG_DNS"
        echo ""
        echo "[Peer]"
        echo "PublicKey = $SERVER_PUB"
        [[ -n "$PSK_LINE" ]] && echo "$PSK_LINE"
        echo "Endpoint = $SERVER_PUBLIC_IP:$WG_PORT"
        echo "AllowedIPs = $WG_CLIENT_ALLOWED_IPS"
        echo "PersistentKeepalive = 25"
    } > "$dst"
    chmod 600 "$dst"
}

write_client_conf "$GEN_DIR/${WG_CLIENT_NAME}_linux.conf"
write_client_conf "$GEN_DIR/${WG_CLIENT_NAME}_android.conf"
# Canonical names used by client/configure.sh
cp "$GEN_DIR/${WG_CLIENT_NAME}_linux.conf"   "$GEN_DIR/client_linux.conf"
cp "$GEN_DIR/${WG_CLIENT_NAME}_android.conf" "$GEN_DIR/client_android.conf"
if [[ "$SERVER_CONF" != "$GEN_DIR/server_wg0.conf" ]]; then
    cp "$SERVER_CONF" "$GEN_DIR/server_wg0.conf"
fi

# QR code for Android
if command -v qrencode >/dev/null 2>&1; then
    qrencode -o "$GEN_DIR/${WG_CLIENT_NAME}_android.png" < "$GEN_DIR/${WG_CLIENT_NAME}_android.conf"
    log_info "Android QR: $GEN_DIR/${WG_CLIENT_NAME}_android.png"
fi

# Enable IP forwarding when NAT is needed
if [[ "$WG_ENABLE_NAT" =~ ^[Yy] ]]; then
    cat > /etc/sysctl.d/99-wireguard-forwarding.conf <<'EOF'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF
    sysctl --system >/dev/null
fi

log_info "Generated files:"
log_info "  $SERVER_CONF"
log_info "  $GEN_DIR/${WG_CLIENT_NAME}_linux.conf"
log_info "  $GEN_DIR/${WG_CLIENT_NAME}_android.conf"
log_info "Next: sudo wireguard/server/apply.sh"
