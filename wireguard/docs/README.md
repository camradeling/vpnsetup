# WireGuard

Modern, minimal VPN built into the Linux kernel. Uses Curve25519 keypairs and ChaCha20-Poly1305. Significantly simpler than OpenVPN with better performance and a much smaller attack surface. Does not obfuscate traffic.

## Server setup

```bash
./configure.sh                          # set WG_* variables
sudo wireguard/server/install.sh        # install wireguard-tools, qrencode
sudo wireguard/server/configure.sh      # generate keypairs, write configs to wireguard/generated/
sudo wireguard/server/apply.sh          # copy server config to /etc/wireguard/wg0.conf
sudo wireguard/server/start.sh          # wg-quick up + enable systemd service
sudo wireguard/server/status.sh         # show wg show + routes
```

## Client setup — Linux

Copy `wireguard/generated/client_linux.conf` to the client, then:

```bash
sudo wireguard/client/install.sh        # install wireguard-tools
sudo wireguard/client/configure.sh      # install /etc/wireguard/wg0.conf
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0      # autostart
```

## Client setup — Android

1. Install the official WireGuard app from Google Play.
2. Import via QR: scan `wireguard/generated/<client>_android.png`
   or import the `client_android.conf` file directly.

Regenerate QR from an existing config:
```bash
qrencode -o qr.png < wireguard/generated/client_android.conf
```

## Stop server

```bash
sudo wireguard/server/stop.sh
```

## Diagnostics

```bash
sudo wg show
ip addr show wg0
ip route show dev wg0
sudo journalctl -u wg-quick@wg0 -e
```

If `latest handshake` is absent, the client cannot reach the server — check the UDP port, public IP, and keypair consistency.
