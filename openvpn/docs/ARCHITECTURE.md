# OpenVPN Architecture

## Traffic flow (full tunnel)

```
Client app
  │
  ▼
OpenVPN client (tun interface)
  │  encrypted TLS stream (port OVPN_PORT/OVPN_PROTOCOL)
  ▼
VPS — openvpn process (tun0)
  │  iptables MASQUERADE
  ▼
Internet
```

## PKI structure

EasyRSA manages a two-level PKI:

```
$OVPN_WORKDIR/pki/
├── ca.crt          CA certificate (distributed to all clients)
├── private/ca.key  CA private key  (never leaves server)
├── issued/         Server and client certificates
│   └── <SERVER_NAME>.crt
├── private/        Private keys
│   └── <SERVER_NAME>.key
└── crl.pem         Certificate Revocation List
```

Copied to workdir root for OpenVPN's working directory:
- `ca.crt`, `ca.key`, `<SERVER_NAME>.crt`, `<SERVER_NAME>.key`, `crl.pem`
- `tls-crypt.key` or `tls-auth.key`

## Systemd service

`openvpn-<SERVER_NAME>.service` in `/etc/systemd/system/` calls:
- `ExecStartPost` → `iptables-add.sh` (MASQUERADE + INPUT/FORWARD rules)
- `ExecStopPost`  → `iptables-remove.sh`

## Client config generation

`add-client.sh` builds a self-contained inline `.ovpn` file by appending:
1. `<ca>` block (CA cert)
2. `<cert>` block (client cert, cert portion only)
3. `<key>` block (client private key)
4. `<tls-crypt>` or `<tls-auth>` block

No separate files needed on the client.

## Linux client: DNS and IPv6

OpenVPN on Linux ignores pushed `dhcp-option DNS` unless an `--up` script
applies it, and `redirect-gateway def1` only covers IPv4. Without help the
network's own resolver keeps answering (poisoned on a censoring network) and
IPv6 bypasses the tunnel.

`client/dns-hook.sh` is that script. On `up` it sets the pushed DNS servers
(fallback `1.1.1.1 8.8.8.8`) on the tun link with routing domain `~.` —
the only DNS route in systemd-resolved — and installs an `ip6tables` chain
(`OVPN_CLIENT_OUT6`) rejecting non-local outbound IPv6 so clients fall back
to IPv4. `down` (with `--down-pre`) reverts both.

It is passed on the command line rather than embedded in the `.ovpn`, so the
same `.ovpn` still imports cleanly on Android/Windows/macOS clients:
`client/run.sh` (foreground) and the unit from `install-service.sh` (which
copies the hook to `/etc/openvpn/client/vpnsetup-dns-hook.sh`) both add
`--script-security 2 --up … --down … --down-pre`.
