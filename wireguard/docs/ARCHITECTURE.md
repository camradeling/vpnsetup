# WireGuard Architecture

## Routing modes

`WG_ROUTING_MODE` in `config.env` controls what traffic the client sends through WireGuard:

| Mode | Client AllowedIPs | Use case |
|---|---|---|
| 1 | `<server_vpn_ip>/32` | Reach the server only; no NAT needed |
| 2 | `<vpn_cidr>` | Access all peers on the VPN subnet |
| 3 | `0.0.0.0/0, ::/0` | Full tunnel — all internet via server |
| 4 | Custom CIDRs | Split tunnel to a subnet behind the server |

## Full tunnel (mode 3) traffic flow

```
Client app
  │
  ▼
wg0 (Curve25519 keypair, ChaCha20-Poly1305)
  │  UDP to SERVER_PUBLIC_IP:WG_PORT
  ▼
VPS wg0 interface
  │  iptables MASQUERADE (PostUp/PostDown in server config)
  ▼
Internet
```

## NAT configuration

When `WG_ENABLE_NAT=yes`, `configure.sh` writes `PostUp` and `PostDown` iptables lines directly into the server's `[Interface]` section:

```ini
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o <NIC> -j MASQUERADE
PostDown = iptables -D FORWARD ...
```

`%i` is expanded by `wg-quick` to the interface name at runtime.

## PresharedKey

When `WG_ENABLE_PSK=yes`, a symmetric pre-shared key is added to the `[Peer]` section of both server and client configs. This provides an additional layer of post-quantum resistance on top of Curve25519.

## Key locations

Private keys exist only in `wireguard/generated/server_<iface>.conf` and `wireguard/generated/<client>_linux.conf` — both `chmod 600` and in `.gitignore`. They are never written to `config.env`.
