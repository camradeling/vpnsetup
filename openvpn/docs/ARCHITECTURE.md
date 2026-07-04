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
