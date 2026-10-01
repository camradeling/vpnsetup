#!/usr/bin/env bash
# Point systemd-resolved at the sing-box TUN so system DNS is hijacked by
# sing-box (route rule "hijack-dns") and resolved over DoT through the proxy.
#
# Without this, resolved keeps querying the network's own resolver; when
# that resolver is on the local subnet the queries never enter the TUN and
# come back poisoned on a censoring network.
#
# Any address routed into the TUN works since hijack-dns matches by
# protocol; 172.19.0.2 is the peer address of the TUN's 172.19.0.1/30.
#
# Self-contained so configure.sh can install it to /etc/sing-box/.
# Usage: dns-hook.sh up|down [iface]
set -u

IFACE="${2:-singtun0}"
DNS_IP="172.19.0.2"

case "${1:-}" in
    up)
        command -v resolvectl >/dev/null 2>&1 || { echo "dns-hook: resolvectl missing, DNS NOT routed through tunnel" >&2; exit 0; }
        # sing-box creates the TUN asynchronously after start
        for _ in $(seq 1 50); do
            ip link show "$IFACE" >/dev/null 2>&1 && break
            sleep 0.1
        done
        resolvectl dns "$IFACE" "$DNS_IP"
        resolvectl domain "$IFACE" '~.'
        resolvectl flush-caches
        echo "dns-hook: DNS on $IFACE -> $DNS_IP (exclusive)"
        ;;
    down)
        resolvectl revert "$IFACE" 2>/dev/null || true
        resolvectl flush-caches 2>/dev/null || true
        ;;
    *)
        echo "Usage: $0 up|down [iface]" >&2
        exit 1
        ;;
esac
