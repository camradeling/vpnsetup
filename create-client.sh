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

if [[ -t 1 ]]; then
    echo "Refusing to write a tar archive to your terminal." >&2
    echo "Redirect to a file or pipe it, e.g.:" >&2
    echo "  sudo $0 > client1-bundle.tar.gz" >&2
    exit 1
fi

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

# CLIENT selects which client identity to bundle. Defaults to the baseline
# client created by each protocol's own server/configure.sh. Any other name
# must already exist -- created via the protocol's own server/add-client.sh
# -- this script only bundles, it doesn't mint new WireGuard/sing-box
# identities (OpenVPN is the exception: it always could look up an arbitrary
# name, so it keeps auto-creating on first bundle for convenience).
BASELINE_NAME="${WG_CLIENT_NAME:-client1}"
CLIENT_NAME="${CLIENT:-$BASELINE_NAME}"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Marker so a bundle's client identity is recoverable after extraction --
# none of the per-protocol files carry a consistent name across all four
# protocols (WireGuard/sing-box are renamed to generic canonical filenames).
echo "$CLIENT_NAME" > "$STAGE/CLIENT_NAME"

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
            WG_LINUX="$GEN/${CLIENT_NAME}_linux.conf"
            WG_ANDROID="$GEN/${CLIENT_NAME}_android.conf"
            if [[ ! -f "$WG_LINUX" ]]; then
                log_err "No WireGuard client named '$CLIENT_NAME'."
                log_err "Run: sudo CLIENT=$CLIENT_NAME wireguard/server/add-client.sh"
                exit 1
            fi
            mkdir -p "$STAGE/wireguard/generated"
            # server_wg0.conf (server private key) intentionally excluded.
            # Renamed to the canonical names client/configure.sh expects.
            cp "$WG_LINUX" "$STAGE/wireguard/generated/client_linux.conf"
            cp "$WG_ANDROID" "$STAGE/wireguard/generated/client_android.conf"
            if [[ -f "$GEN/${CLIENT_NAME}_android.png" ]]; then
                cp "$GEN/${CLIENT_NAME}_android.png" "$STAGE/wireguard/generated/client_android.png"
            fi
            ;;
        singbox-reality)
            GEN="$REPO_ROOT/singbox-reality/generated"
            SECRETS="$GEN/secrets.env"
            if [[ "$CLIENT_NAME" != "$BASELINE_NAME" ]]; then
                SECRETS="$GEN/secrets-${CLIENT_NAME}.env"
            fi
            if [[ ! -f "$SECRETS" ]]; then
                log_err "No sing-box-reality client named '$CLIENT_NAME'."
                log_err "Run: sudo CLIENT=$CLIENT_NAME singbox-reality/server/add-client.sh"
                exit 1
            fi
            mkdir -p "$STAGE/singbox-reality/generated"
            # shellcheck disable=SC1090
            source "$SECRETS"
            # SB_REALITY_PRIVATE_KEY intentionally excluded -- server-only secret.
            # Renamed to the canonical secrets.env client/configure.sh expects.
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
