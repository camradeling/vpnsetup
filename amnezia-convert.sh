#!/usr/bin/env bash
# Converts a client bundle produced by create-client.sh into artifacts that
# the unmodified AmneziaVPN app (amnezia-vpn/amnezia-client) can import
# directly via its "Add existing server" / self-hosted import flow:
#   - WireGuard / OpenVPN: already native formats, just copied through as-is
#   - sing-box-reality:    converted to a vless:// URI
#   - Shadowsocks:         converted to an ss:// URI
#
# Standalone by design: does not modify or depend on the internals of
# create-client.sh / client-install.sh, only on the bundle layout they
# already produce. Safe to run anywhere, no root required.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_ROOT/common/lib.sh"

BUNDLE=""
DIR=""
OUT="./amnezia-import"

usage() {
    cat <<EOF
Usage: $0 --bundle <path/to/client-bundle.tar.gz> [--out <dir>]
       $0 --dir <path/to/already-extracted-bundle> [--out <dir>]

Reads a client bundle (as produced by create-client.sh) and writes, per
enabled protocol, an artifact ready to import into AmneziaVPN:
  wireguard.conf         (copied as-is; already Amnezia's native format)
  <name>.ovpn             (copied as-is; already Amnezia's native format)
  singbox-reality.txt    (vless:// URI)
  shadowsocks.txt        (ss:// URI)

Options:
  --bundle <path>   Tarball to extract and read from
  --dir <path>      Already-extracted bundle directory to read from
  --out <dir>       Output directory (default: ./amnezia-import)
  -h, --help        Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bundle) BUNDLE="$2"; shift 2 ;;
        --dir) DIR="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) log_err "Unknown argument: $1"; usage; exit 1 ;;
    esac
done

if [[ -n "$BUNDLE" && -n "$DIR" ]]; then
    log_err "Pass only one of --bundle or --dir."
    exit 1
fi
if [[ -z "$BUNDLE" && -z "$DIR" ]]; then
    log_err "--bundle or --dir is required."
    usage
    exit 1
fi

BUNDLE_DIR=""
if [[ -n "$BUNDLE" ]]; then
    if [[ ! -f "$BUNDLE" ]]; then
        log_err "Bundle not found: $BUNDLE"
        exit 1
    fi
    BUNDLE_DIR="$(mktemp -d)"
    trap 'rm -rf "$BUNDLE_DIR"' EXIT
    tar xzf "$BUNDLE" -C "$BUNDLE_DIR"
else
    if [[ ! -d "$DIR" ]]; then
        log_err "Directory not found: $DIR"
        exit 1
    fi
    BUNDLE_DIR="$DIR"
fi

CONFIG_ENV="$BUNDLE_DIR/config.env"
if [[ ! -f "$CONFIG_ENV" ]]; then
    log_err "config.env not found in bundle. Is this a bundle produced by create-client.sh?"
    exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG_ENV"

if [[ -z "${ENABLED_PROTOCOLS:-}" ]]; then
    log_err "ENABLED_PROTOCOLS is empty in the bundle's config.env."
    exit 1
fi

CLIENT_NAME="client"
if [[ -f "$BUNDLE_DIR/CLIENT_NAME" ]]; then
    CLIENT_NAME="$(cat "$BUNDLE_DIR/CLIENT_NAME")"
fi
# Used as a URI fragment label below; keep it to characters that never need
# percent-encoding regardless of source.
LABEL="$(echo "$CLIENT_NAME" | tr -cd 'A-Za-z0-9_-')"
[[ -z "$LABEL" ]] && LABEL="client"

mkdir -p "$OUT"
CONVERTED=()
SKIPPED=()

qr_if_available() {
    local text="$1" png="$2"
    if command -v qrencode >/dev/null 2>&1; then
        qrencode -o "$png" <<<"$text"
    fi
}

for proto in $ENABLED_PROTOCOLS; do
    case "$proto" in
        wireguard)
            SRC="$BUNDLE_DIR/wireguard/generated/client_linux.conf"
            if [[ -f "$SRC" ]]; then
                cp "$SRC" "$OUT/wireguard.conf"
                CONVERTED+=("wireguard  -> $OUT/wireguard.conf (import as-is: native WireGuard format)")
            else
                log_err "wireguard: $SRC not found, skipping"
                SKIPPED+=("wireguard")
            fi
            ;;
        openvpn)
            SRC="$(find "$BUNDLE_DIR/openvpn/generated" -maxdepth 1 -name '*.ovpn' 2>/dev/null | head -1)"
            if [[ -n "$SRC" ]]; then
                cp "$SRC" "$OUT/$(basename "$SRC")"
                CONVERTED+=("openvpn    -> $OUT/$(basename "$SRC") (import as-is: native OpenVPN format)")
            else
                log_err "openvpn: no .ovpn file found under $BUNDLE_DIR/openvpn/generated, skipping"
                SKIPPED+=("openvpn")
            fi
            ;;
        singbox-reality)
            SECRETS="$BUNDLE_DIR/singbox-reality/generated/secrets.env"
            if [[ -f "$SECRETS" ]]; then
                # shellcheck disable=SC1090
                source "$SECRETS"
                if [[ -z "${SB_UUID:-}" || -z "${SB_REALITY_PUBLIC_KEY:-}" || -z "${SB_SHORT_ID:-}" \
                      || -z "${SERVER_PUBLIC_IP:-}" || -z "${SB_PORT:-}" || -z "${SB_SNI:-}" ]]; then
                    log_err "singbox-reality: required fields missing (secrets.env/config.env), skipping"
                    SKIPPED+=("singbox-reality")
                else
                    URI="vless://${SB_UUID}@${SERVER_PUBLIC_IP}:${SB_PORT}?encryption=none&security=reality&pbk=${SB_REALITY_PUBLIC_KEY}&fp=chrome&sni=${SB_SNI}&sid=${SB_SHORT_ID}&type=tcp&flow=xtls-rprx-vision#${LABEL}"
                    echo "$URI" > "$OUT/singbox-reality.txt"
                    qr_if_available "$URI" "$OUT/singbox-reality.png"
                    CONVERTED+=("singbox-reality -> $OUT/singbox-reality.txt (vless:// URI, paste into Amnezia's import dialog)")
                fi
            else
                log_err "singbox-reality: $SECRETS not found, skipping"
                SKIPPED+=("singbox-reality")
            fi
            ;;
        shadowsocks)
            if [[ -z "${SS_METHOD:-}" || -z "${SS_PASSWORD:-}" || -z "${SERVER_PUBLIC_IP:-}" || -z "${SS_SERVER_PORT:-}" ]]; then
                log_err "shadowsocks: required fields missing in config.env, skipping"
                SKIPPED+=("shadowsocks")
            else
                USERINFO="$(printf '%s:%s' "$SS_METHOD" "$SS_PASSWORD" | base64 -w0)"
                URI="ss://${USERINFO}@${SERVER_PUBLIC_IP}:${SS_SERVER_PORT}#${LABEL}"
                echo "$URI" > "$OUT/shadowsocks.txt"
                qr_if_available "$URI" "$OUT/shadowsocks.png"
                CONVERTED+=("shadowsocks -> $OUT/shadowsocks.txt (ss:// URI, paste into Amnezia's import dialog)")
            fi
            ;;
        *)
            log_err "Unknown protocol: $proto, skipping"
            SKIPPED+=("$proto")
            ;;
    esac
done

echo ""
log_info "Converted for client '$CLIENT_NAME':"
for line in "${CONVERTED[@]:-}"; do
    [[ -n "$line" ]] && log_info "  $line"
done
if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    log_err "Skipped: ${SKIPPED[*]}"
fi
echo ""
log_info "In AmneziaVPN: Add server -> add existing server / self-hosted -> import the"
log_info ".conf/.ovpn file directly, or paste the .txt file's content (vless://... or"
log_info "ss://...) into the import dialog. QR PNGs (if qrencode was available) can be"
log_info "scanned from the mobile app instead."
