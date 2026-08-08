#!/usr/bin/env bash
# Bundles this client's per-protocol config files into a tar stream on stdout.
# Run on the SERVER as root -- normally invoked remotely (over SSH) by
# client-install.sh, which pipes this script's stdout straight into `tar x`.
#
# Only client-safe material is included. Server-side secrets (the WireGuard
# server private key in wireguard/generated/server_wg0.conf, the sing-box
# REALITY private key) are never staged into the bundle.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# fd 1 is reserved for the tar stream below; send all logging to fd 2 so
# nothing but tar bytes ever hits real stdout.
exec 3>&1
exec 1>&2

source "$REPO_ROOT/common/lib.sh"
require_root
load_config

if [[ -z "${ENABLED_PROTOCOLS:-}" ]]; then
    log_err "ENABLED_PROTOCOLS is empty. Run: ./configure.sh"
    exit 1
fi

CLIENT_NAME="${WG_CLIENT_NAME:-client1}"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp "$REPO_ROOT/config.env" "$STAGE/config.env"

for proto in $ENABLED_PROTOCOLS; do
    case "$proto" in
        openvpn)
            CCD="$OVPN_WORKDIR/ccd"
            if [[ ! -f "$CCD/$CLIENT_NAME.ovpn" ]]; then
                log_info "No OpenVPN client named '$CLIENT_NAME' yet; creating it..."
                CLIENT="$CLIENT_NAME" PASS=1 bash "$REPO_ROOT/openvpn/server/add-client.sh"
            fi
            mkdir -p "$STAGE/openvpn/generated"
            cp "$CCD/$CLIENT_NAME.ovpn" "$STAGE/openvpn/generated/"
            ;;
        wireguard)
            GEN="$REPO_ROOT/wireguard/generated"
            if [[ ! -f "$GEN/client_linux.conf" ]]; then
                log_err "WireGuard not configured yet. Run: sudo wireguard/server/configure.sh"
                exit 1
            fi
            mkdir -p "$STAGE/wireguard/generated"
            # server_wg0.conf (server private key) intentionally excluded.
            cp "$GEN/client_linux.conf" "$GEN/client_android.conf" "$STAGE/wireguard/generated/"
            if [[ -f "$GEN/${WG_CLIENT_NAME}_android.png" ]]; then
                cp "$GEN/${WG_CLIENT_NAME}_android.png" "$STAGE/wireguard/generated/client_android.png"
            fi
            ;;
        singbox-reality)
            SECRETS="$REPO_ROOT/singbox-reality/generated/secrets.env"
            if [[ ! -f "$SECRETS" ]]; then
                log_err "sing-box-reality not configured yet. Run: sudo singbox-reality/server/configure.sh"
                exit 1
            fi
            mkdir -p "$STAGE/singbox-reality/generated"
            # shellcheck disable=SC1090
            source "$SECRETS"
            # SB_REALITY_PRIVATE_KEY intentionally excluded -- server-only secret.
            cat > "$STAGE/singbox-reality/generated/secrets.env" <<ENV
SB_UUID=$SB_UUID
SB_SHORT_ID=$SB_SHORT_ID
SB_REALITY_PUBLIC_KEY=$SB_REALITY_PUBLIC_KEY
ENV
            ;;
        shadowsocks)
            : # shares config.env only; nothing per-client to stage
            ;;
        *)
            log_err "Unknown protocol: $proto"
            ;;
    esac
done

log_info "Bundle staged for client '$CLIENT_NAME': $(du -sh "$STAGE" | cut -f1)"

tar czf - -C "$STAGE" . >&3
