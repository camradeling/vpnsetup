#!/usr/bin/env bash
# Copies the generated client config to /etc/wireguard/ on the client machine.
# Run this on the CLIENT host, not the server.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

GEN_DIR="$REPO_ROOT/wireguard/generated"
SRC="$GEN_DIR/client_linux.conf"

if [[ ! -f "$SRC" ]]; then
    log_err "Client config not found: $SRC"
    log_err "Run configure.sh on the SERVER first, then copy the generated/ directory here."
    exit 1
fi

DST="/etc/wireguard/${WG_INTERFACE}.conf"

# Full-tunnel only: route DNS and block IPv6 explicitly.
#  - wg-quick hands "DNS =" to resolvconf, which neither guarantees the
#    tunnel servers are used exclusively under systemd-resolved nor stops
#    queries to an on-link ISP resolver going out directly (poisoned on a
#    censoring network). Set the servers on the wg link with routing domain
#    "~." instead, so resolved uses only them.
#  - The client has no IPv6 tunnel address, so ::/0 traffic is silently
#    dropped by the server; reject it locally so apps fall back to IPv4
#    immediately instead of timing out.
if grep -qE '^[[:space:]]*AllowedIPs[[:space:]]*=.*0\.0\.0\.0/0' "$SRC" && command -v resolvectl >/dev/null 2>&1; then
    DNS_SERVERS="$(sed -nE 's/^[[:space:]]*DNS[[:space:]]*=[[:space:]]*//p' "$SRC" | tr ',' ' ' | xargs)"
    [[ -n "$DNS_SERVERS" ]] || DNS_SERVERS="1.1.1.1 8.8.8.8"
    BLOCK6=0
    if grep -qE '^[[:space:]]*AllowedIPs[[:space:]]*=.*::/0' "$SRC" \
        && ! grep -qE '^[[:space:]]*Address[[:space:]]*=.*:' "$SRC"; then
        BLOCK6=1
    fi
    TMP="$(mktemp)"
    awk -v dns="$DNS_SERVERS" -v block6="$BLOCK6" '
        /^[ \t]*DNS[ \t]*=/ { next }
        { print }
        /^[ \t]*Address[ \t]*=/ && !done {
            print "PostUp = resolvectl dns %i " dns "; resolvectl domain %i \"~.\"; resolvectl flush-caches"
            if (block6) {
                print "PostUp = ip6tables -I OUTPUT -o %i -j REJECT"
                print "PostDown = ip6tables -D OUTPUT -o %i -j REJECT || true"
            }
            print "PostDown = resolvectl flush-caches || true"
            done = 1
        }
    ' "$SRC" > "$TMP"
    install -m 600 "$TMP" "$DST"
    rm -f "$TMP"
    log_info "Full tunnel: DNS $DNS_SERVERS routed exclusively via $WG_INTERFACE$([[ $BLOCK6 == 1 ]] && echo ", IPv6 rejected")"
else
    install -m 600 "$SRC" "$DST"
fi
log_info "Client config installed at $DST"
log_info "Start with: sudo wg-quick up $WG_INTERFACE"
log_info "Autostart:  sudo systemctl enable wg-quick@$WG_INTERFACE"
