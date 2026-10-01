# Shadowsocks Architecture

## Server

`ss-server` listens on all interfaces and proxies outbound TCP/UDP:

```
Internet ──► VPS:SS_SERVER_PORT ──► ss-server ──► freedom outbound
```

## Ubuntu client — SOCKS5 mode

`ss-local` creates a local SOCKS5 proxy. Applications that support SOCKS5 connect to it directly:

```
App ──► 127.0.0.1:SS_LOCAL_PORT (ss-local) ──► VPS:ss-server ──► Internet
```

## Ubuntu client — transparent TCP mode

`ss-redir` listens locally. iptables nat OUTPUT redirects all outgoing TCP to it:

```
App TCP ──► iptables nat OUTPUT ──► SS_REDIR_OUT chain
               │
               ├─ RETURN: traffic from UID shadowsocks (loop prevention)
               ├─ RETURN: private/reserved CIDRs (10/8, 192.168/16, etc.)
               └─ REDIRECT → 127.0.0.1:SS_REDIR_PORT (ss-redir) ──► VPS ──► Internet
```

The iptables chain `SS_REDIR_OUT` is created on start and removed on stop/exit (via `trap`).

### DNS and IPv6 leaks

Only IPv4 TCP is redirected, so two things would otherwise bypass the tunnel:

- **DNS** — plain UDP/53 goes straight to the network's resolver. On a
  censored network that resolver returns poisoned answers (e.g.
  `www.youtube.com` → a Facebook IP), and the tunneled connection then goes to
  the wrong host. While transparent mode is active, every systemd-resolved link
  that has DNS servers is switched to DNS-over-TLS against
  `SS_TRANSPARENT_DNS` (default `1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google`).
  DoT is TCP/853, so it is caught by the REDIRECT rule and resolved through the
  tunnel. The original per-link servers/DoT mode are saved to
  `/run/ss-transparent-dns.state` and restored on stop. Without
  systemd-resolved a warning is printed and DNS is left untouched.
- **IPv6** — there is no IPv6 redirect, so any AAAA destination would go out the
  native v6 route. The filter chain `SS_REDIR_OUT6` (ip6tables OUTPUT) rejects
  non-local outbound IPv6 (TCP with RST, other with ICMPv6 admin-prohibited) so
  clients fall back to IPv4 immediately. Loopback, link-local, ULA, multicast
  and ICMPv6 (NDP) are left alone.

## UDP

`ss-redir -u` is started in transparent mode, but full transparent UDP proxying requires TPROXY/policy routing which is not included. UDP works for SOCKS5 mode via `ss-local`.

## Systemd units

- Server: `shadowsocks.service` — runs `ss-server` as `nobody:nogroup`
- Client SOCKS5: `shadowsocks-client.service` — runs `ss-local` as `shadowsocks:shadowsocks`
