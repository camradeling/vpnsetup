#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

EASYRSA_DIR="$REPO_ROOT/openvpn/easy-rsa"
EASYRSA_BIN="$EASYRSA_DIR/easyrsa --vars=$OVPN_WORKDIR/vars"
TPL_DIR="$REPO_ROOT/openvpn/templates"

if [[ ! -f "$EASYRSA_DIR/easyrsa" ]]; then
    log_err "EasyRSA not found. Run: sudo openvpn/server/install.sh"
    exit 1
fi

# Detect the no-privileges group name
if grep -qs "^nogroup:" /etc/group; then
    OVPN_NOGROUP=nogroup
else
    OVPN_NOGROUP=nobody
fi
export OVPN_NOGROUP

# Detect public-facing NIC from default route
OVPN_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
if [[ -z "$OVPN_NIC" ]]; then
    log_err "Could not detect public network interface. Set a default route first."
    exit 1
fi
export OVPN_NIC

# Compute CIDR prefix from subnet mask
OVPN_VPN_CIDR="$(netmask_to_cidr "$OVPN_VPN_SUBNET_MASK")"
export OVPN_VPN_CIDR

# Compute composite parameters used in templates
if [[ "$OVPN_COMPRESSION_ENABLED" == "y" ]]; then
    export OVPN_COMPRESSION_PARAM="compress $OVPN_COMPRESSION_ALG"
else
    export OVPN_COMPRESSION_PARAM=""
fi

if [[ "$OVPN_DH_TYPE" == "ECDH" ]]; then
    export OVPN_DH_DEFINITION=$'dh none\necdh-curve '"$OVPN_DH_CURVE"
else
    export OVPN_DH_DEFINITION="dh dh.pem"
fi

case "$OVPN_TLS_SIG" in
    tls-crypt) export OVPN_TLS_PARAM="tls-crypt tls-crypt.key" ;;
    tls-auth)  export OVPN_TLS_PARAM="tls-auth tls-auth.key 0" ;;
esac

if [[ "$OVPN_PROTOCOL" == "udp" ]]; then
    export OVPN_PROTOCOL_PARAM=$'proto udp\nexplicit-exit-notify'
else
    export OVPN_PROTOCOL_PARAM="proto tcp-client"
fi

export OVPN_WORKDIR OVPN_SERVER_NAME SERVER_PUBLIC_IP
export OVPN_PORT OVPN_PROTOCOL OVPN_VPN_IP OVPN_VPN_SUBNET_MASK
export OVPN_DNS1 OVPN_DNS2 OVPN_CIPHER OVPN_CC_CIPHER OVPN_HMAC_ALG

mkdir -p "$OVPN_WORKDIR"

# Write EasyRSA vars file
case "$OVPN_CERT_TYPE" in
    ECDSA)
        printf 'set_var EASYRSA_ALGO ec\nset_var EASYRSA_CURVE %s\n' "$OVPN_CERT_CURVE" > "$OVPN_WORKDIR/vars"
        ;;
    RSA)
        printf 'set_var EASYRSA_KEY_SIZE %s\n' "$OVPN_RSA_KEY_SIZE" > "$OVPN_WORKDIR/vars"
        ;;
esac

SERVER_CN="cn_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
{
    printf 'set_var EASYRSA_REQ_CN %s\n' "$SERVER_CN"
    printf 'set_var EASYRSA_PKI %s/pki\n' "$OVPN_WORKDIR"
} >> "$OVPN_WORKDIR/vars"

log_info "Initialising PKI..."
$EASYRSA_BIN init-pki
$EASYRSA_BIN --batch build-ca nopass

if [[ "$OVPN_DH_TYPE" == "DH" ]]; then
    log_info "Generating DH parameters (this may take a while)..."
    openssl dhparam -out "$OVPN_WORKDIR/dh.pem" "$OVPN_DH_KEY_SIZE"
fi

$EASYRSA_BIN build-server-full "$OVPN_SERVER_NAME" nopass
EASYRSA_CRL_DAYS=3650 $EASYRSA_BIN gen-crl

case "$OVPN_TLS_SIG" in
    tls-crypt) openvpn --genkey --secret "$OVPN_WORKDIR/tls-crypt.key" ;;
    tls-auth)  openvpn --genkey --secret "$OVPN_WORKDIR/tls-auth.key" ;;
esac

# Gather certs into workdir root
cp "$OVPN_WORKDIR/pki/ca.crt" \
   "$OVPN_WORKDIR/pki/private/ca.key" \
   "$OVPN_WORKDIR/pki/issued/$OVPN_SERVER_NAME.crt" \
   "$OVPN_WORKDIR/pki/private/$OVPN_SERVER_NAME.key" \
   "$OVPN_WORKDIR/pki/crl.pem" \
   "$OVPN_WORKDIR/"
chmod 644 "$OVPN_WORKDIR/crl.pem"

# Enable IP forwarding
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-openvpn.conf
sysctl --system >/dev/null

mkdir -p "$OVPN_WORKDIR/logs" "$OVPN_WORKDIR/ccd"

# Render server config
render_template "$TPL_DIR/server.conf.tpl" "$OVPN_WORKDIR/$OVPN_SERVER_NAME.conf" 644

# Render client template (used by add-client.sh)
render_template "$TPL_DIR/client.conf.tpl" "$OVPN_WORKDIR/client.template" 644

# Render iptables scripts
render_template "$TPL_DIR/iptables-add.sh.tpl" "$OVPN_WORKDIR/iptables-add.sh" 755
render_template "$TPL_DIR/iptables-remove.sh.tpl" "$OVPN_WORKDIR/iptables-remove.sh" 755

# Render and install systemd unit
render_template "$TPL_DIR/openvpn.service.tpl" \
    "/etc/systemd/system/openvpn-$OVPN_SERVER_NAME.service" 644
systemctl daemon-reload

log_info "OpenVPN configured. Server files in $OVPN_WORKDIR"
log_info "Add clients with: sudo openvpn/server/add-client.sh"
