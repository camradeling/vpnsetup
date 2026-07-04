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

## UDP

`ss-redir -u` is started in transparent mode, but full transparent UDP proxying requires TPROXY/policy routing which is not included. UDP works for SOCKS5 mode via `ss-local`.

## Systemd units

- Server: `shadowsocks.service` — runs `ss-server` as `nobody:nogroup`
- Client SOCKS5: `shadowsocks-client.service` — runs `ss-local` as `shadowsocks:shadowsocks`
