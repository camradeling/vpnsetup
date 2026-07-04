#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

EASYRSA_DIR="$REPO_ROOT/openvpn/easy-rsa"
EASYRSA_BIN="$EASYRSA_DIR/easyrsa --vars=$OVPN_WORKDIR/vars"

until [[ "${CLIENT:-}" =~ ^[a-zA-Z0-9_-]+$ ]]; do
    read -rp "Client name (alphanumeric, dash, underscore): " CLIENT
done

echo ""
echo "Protect the client config with a password?"
echo "  1) No password"
echo "  2) Password-protected private key"
until [[ "${PASS:-}" =~ ^[1-2]$ ]]; do
    read -rp "Option [1-2]: " -i 1 -e PASS
done

PKI_INDEX="$OVPN_WORKDIR/pki/index.txt"
if [[ -f "$PKI_INDEX" ]] && grep -qE "/CN=${CLIENT}$" "$PKI_INDEX"; then
    log_err "Client '$CLIENT' already exists in the PKI."
    exit 1
fi

case "$PASS" in
    1) $EASYRSA_BIN build-client-full "$CLIENT" nopass ;;
    2) $EASYRSA_BIN build-client-full "$CLIENT" ;;
esac

CCD="$OVPN_WORKDIR/ccd"
mkdir -p "$CCD"

# Determine TLS mode from actual server config
if grep -qs "^tls-crypt" "$OVPN_WORKDIR/$OVPN_SERVER_NAME.conf"; then
    TLS_MODE=1
else
    TLS_MODE=2
fi

OUTFILE="$CCD/$CLIENT.conf"
cp "$OVPN_WORKDIR/client.template" "$OUTFILE"

{
    echo "<ca>"
    cat "$OVPN_WORKDIR/pki/ca.crt"
    echo "</ca>"
    echo "<cert>"
    awk '/BEGIN/,/END/' "$OVPN_WORKDIR/pki/issued/$CLIENT.crt"
    echo "</cert>"
    echo "<key>"
    cat "$OVPN_WORKDIR/pki/private/$CLIENT.key"
    echo "</key>"
    case "$TLS_MODE" in
        1)
            echo "<tls-crypt>"
            cat "$OVPN_WORKDIR/tls-crypt.key"
            echo "</tls-crypt>"
            ;;
        2)
            echo "key-direction 1"
            echo "<tls-auth>"
            cat "$OVPN_WORKDIR/tls-auth.key"
            echo "</tls-auth>"
            ;;
    esac
} >> "$OUTFILE"

cp "$OUTFILE" "$CCD/$CLIENT.ovpn"
chmod 600 "$OUTFILE" "$CCD/$CLIENT.ovpn"

log_info "Client config: $CCD/$CLIENT.ovpn"
log_info "Copy this file to the client and import it into an OpenVPN client."
