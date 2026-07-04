# OpenVPN

Full-featured TLS-based VPN using PKI certificates. Suitable for road-warrior setups where clients need individual certificates that can be revoked.

## Server setup

```bash
# From repo root:
./configure.sh                         # set OVPN_* variables
sudo openvpn/server/install.sh         # install openvpn, download EasyRSA
sudo openvpn/server/configure.sh       # init PKI, sign server cert, stamp configs
sudo openvpn/server/start.sh           # enable and start systemd service
```

## Add a client

```bash
sudo openvpn/server/add-client.sh
# Follow prompts → produces ccd/<CLIENT>.ovpn
```

Copy the `.ovpn` file to the client machine and import it into any OpenVPN client (official app, NetworkManager, Tunnelblick on macOS).

## Client config location

`$OVPN_WORKDIR/ccd/<client-name>.ovpn`

Default workdir: `/root/servers/<OVPN_SERVER_NAME>/`

## Stop / start

```bash
sudo openvpn/server/stop.sh
sudo openvpn/server/start.sh
```

## Diagnostics

```bash
systemctl status openvpn-<SERVER_NAME> --no-pager
journalctl -u openvpn-<SERVER_NAME> -e
tail -f /root/servers/<SERVER_NAME>/logs/status.log
```
