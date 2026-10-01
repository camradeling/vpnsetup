# Shared helpers for start-transparent.sh / stop-transparent.sh.
# Sourced, not executed. Expects common/lib.sh to be sourced already.
#
# Transparent mode only redirects IPv4 TCP. Two things leak around it:
#   - DNS: plain UDP/53 to the network's resolver goes direct, so a
#     censoring/poisoning resolver hands out fake IPs and the (tunneled)
#     connection goes to the wrong host.
#   - IPv6: there are no ip6tables rules, so any AAAA destination bypasses
#     the proxy entirely via the native v6 route.
# DNS is fixed by switching systemd-resolved to DNS-over-TLS (TCP/853,
# which the IPv4 REDIRECT rule tunnels); IPv6 by rejecting non-local
# outbound v6 so clients fall back to v4 immediately.

CHAIN_OUT6="SS_REDIR_OUT6"
DNS_STATE_FILE="/run/ss-transparent-dns.state"
SS_TRANSPARENT_DNS="${SS_TRANSPARENT_DNS:-1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google}"

ipv6_block_remove() {
    command -v ip6tables >/dev/null 2>&1 || return 0
    ip6tables -D OUTPUT -j "$CHAIN_OUT6" 2>/dev/null || true
    ip6tables -F "$CHAIN_OUT6" 2>/dev/null || true
    ip6tables -X "$CHAIN_OUT6" 2>/dev/null || true
}

ipv6_block_install() {
    if ! command -v ip6tables >/dev/null 2>&1; then
        log_warn "ip6tables not found -- IPv6 traffic will bypass the proxy"
        return 0
    fi
    ipv6_block_remove
    ip6tables -N "$CHAIN_OUT6"
    ip6tables -A "$CHAIN_OUT6" -o lo -j RETURN
    # NDP/RA and other ICMPv6 control traffic must keep working
    ip6tables -A "$CHAIN_OUT6" -p ipv6-icmp -j RETURN
    for net in fe80::/10 fc00::/7 ff00::/8; do
        ip6tables -A "$CHAIN_OUT6" -d "$net" -j RETURN
    done
    ip6tables -A "$CHAIN_OUT6" -p tcp -j REJECT --reject-with tcp-reset
    ip6tables -A "$CHAIN_OUT6" -j REJECT --reject-with icmp6-adm-prohibited
    ip6tables -I OUTPUT -j "$CHAIN_OUT6"
}

resolved_active() {
    command -v resolvectl >/dev/null 2>&1 && systemctl is-active --quiet systemd-resolved
}

# Links that currently have per-link DNS servers, one ifname per line.
dns_links() {
    resolvectl dns | sed -nE 's/^Link [0-9]+ \(([^)]+)\):\s*(\S.*)$/\1/p'
}

dns_tunnel_install() {
    if ! resolved_active; then
        log_warn "systemd-resolved not active -- DNS is NOT tunneled and may be poisoned"
        return 0
    fi
    # A leftover state file means a previous run never restored; keep the
    # original settings it holds rather than overwriting them with ours.
    if [[ ! -f "$DNS_STATE_FILE" ]]; then
        local link servers dot
        : > "$DNS_STATE_FILE"
        chmod 600 "$DNS_STATE_FILE"
        while read -r link; do
            servers="$(resolvectl dns "$link" | sed -E 's/^[^:]*:\s*//')"
            dot="$(resolvectl dnsovertls "$link" | sed -E 's/^[^:]*:\s*//')"
            printf '%s\t%s\t%s\n' "$link" "$dot" "$servers" >> "$DNS_STATE_FILE"
        done < <(dns_links)
    fi
    local link
    while IFS=$'\t' read -r link _ _; do
        # shellcheck disable=SC2086
        resolvectl dns "$link" $SS_TRANSPARENT_DNS
        resolvectl dnsovertls "$link" yes
        log_info "DNS on $link -> DoT via tunnel ($SS_TRANSPARENT_DNS)"
    done < "$DNS_STATE_FILE"
    # resolved (at least v249) remembers each server's negotiated feature
    # level and does not re-evaluate it when DoT is toggled at runtime, so a
    # server already used over plain UDP keeps being queried that way (and
    # gets poisoned answers). Force renegotiation.
    resolvectl reset-server-features
    resolvectl flush-caches
}

dns_tunnel_remove() {
    [[ -f "$DNS_STATE_FILE" ]] || return 0
    if resolved_active; then
        local link dot servers
        while IFS=$'\t' read -r link dot servers; do
            # shellcheck disable=SC2086
            resolvectl dns "$link" $servers 2>/dev/null || true
            resolvectl dnsovertls "$link" "$dot" 2>/dev/null || true
        done < "$DNS_STATE_FILE"
        resolvectl reset-server-features || true
        resolvectl flush-caches || true
    fi
    rm -f "$DNS_STATE_FILE"
}
