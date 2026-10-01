#!/usr/bin/env bash
# OpenVPN --up/--down hook for Linux clients (systemd-resolved).
#
# OpenVPN on Linux ignores pushed "dhcp-option DNS" without a script, so the
# network's own resolver keeps answering -- and on a censoring network it
# hands out poisoned IPs. redirect-gateway also only covers IPv4, so IPv6
# would bypass the tunnel entirely.
#
# up:   point the tun link at the pushed DNS servers (fallback 1.1.1.1 8.8.8.8)
#       with routing domain "~." so resolved uses ONLY the tunnel for DNS;
#       reject non-local outbound IPv6 so clients fall back to IPv4.
# down: undo both.
#
# Self-contained (no repo sourcing) so install-service.sh can copy it to /etc.
# Usage: openvpn --config X.ovpn --script-security 2 \
#            --up dns-hook.sh --down dns-hook.sh --down-pre
set -u

CHAIN6="OVPN_CLIENT_OUT6"
FALLBACK_DNS="1.1.1.1 8.8.8.8"
DEV="${dev:-${1:-}}"

ipv6_block_remove() {
    command -v ip6tables >/dev/null 2>&1 || return 0
    ip6tables -D OUTPUT -j "$CHAIN6" 2>/dev/null || true
    ip6tables -F "$CHAIN6" 2>/dev/null || true
    ip6tables -X "$CHAIN6" 2>/dev/null || true
}

ipv6_block_install() {
    command -v ip6tables >/dev/null 2>&1 || { echo "dns-hook: ip6tables missing, IPv6 not blocked" >&2; return 0; }
    ipv6_block_remove
    ip6tables -N "$CHAIN6"
    ip6tables -A "$CHAIN6" -o lo -j RETURN
    ip6tables -A "$CHAIN6" -p ipv6-icmp -j RETURN
    for net in fe80::/10 fc00::/7 ff00::/8; do
        ip6tables -A "$CHAIN6" -d "$net" -j RETURN
    done
    ip6tables -A "$CHAIN6" -p tcp -j REJECT --reject-with tcp-reset
    ip6tables -A "$CHAIN6" -j REJECT --reject-with icmp6-adm-prohibited
    ip6tables -I OUTPUT -j "$CHAIN6"
}

pushed_dns() {
    local i var opt out=""
    for ((i = 1; ; i++)); do
        var="foreign_option_$i"
        opt="${!var:-}"
        [[ -n "$opt" ]] || break
        [[ "$opt" == "dhcp-option DNS "* ]] && out+=" ${opt#dhcp-option DNS }"
    done
    echo "${out# }"
}

case "${script_type:-}" in
    up)
        dns="$(pushed_dns)"
        [[ -n "$dns" ]] || dns="$FALLBACK_DNS"
        if command -v resolvectl >/dev/null 2>&1; then
            # shellcheck disable=SC2086
            resolvectl dns "$DEV" $dns
            resolvectl domain "$DEV" '~.'
            resolvectl flush-caches
            echo "dns-hook: DNS on $DEV -> $dns (exclusive)"
        else
            echo "dns-hook: resolvectl missing, DNS NOT routed through tunnel" >&2
        fi
        ipv6_block_install
        ;;
    down)
        ipv6_block_remove
        resolvectl revert "$DEV" 2>/dev/null || true
        resolvectl flush-caches 2>/dev/null || true
        ;;
    *)
        echo "dns-hook: must be run by openvpn as --up/--down script" >&2
        exit 1
        ;;
esac
exit 0
