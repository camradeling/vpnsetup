# Client usage: running each protocol

This covers day-2 usage on the **client machine**, after `client-install.sh`
has already installed and configured whichever protocols are enabled.
Install/setup instructions live in `README.md` — this is about actually
turning each one on and off.

## Important: only run one full-tunnel protocol at a time

OpenVPN, WireGuard, and sing-box-reality are all configured as **full
tunnel** by default (they take over your default route so all traffic goes
through them). Bringing up more than one at once doesn't error, but they
compete for the default route — Linux resolves it silently by route/policy
priority, so one of them ends up carrying your traffic while the other(s)
sit connected but idle. Bring the current one down before starting another.

**Shadowsocks is the exception**, and splits into two cases:
- **SOCKS5 mode** doesn't touch system routing at all — it's an opt-in
  local proxy, apps must be pointed at it explicitly. Safe to run alongside
  any of the other three.
- **Transparent mode** intercepts via `iptables` before the routing
  decision. If a full-tunnel protocol is *also* up, your Shadowsocks
  traffic gets silently double-wrapped — routed to Shadowsocks first, then
  Shadowsocks's own outbound connection goes out through whichever tunnel
  currently owns the default route. Not broken, but unexpected nesting.

## OpenVPN

No systemd service is set up for the client by this repo — it's plain
`openvpn` CLI usage against the `.ovpn` file `client-install.sh` printed the
path to (also found under `openvpn/generated/<name>.ovpn`).

```bash
sudo apt-get install -y openvpn      # if not already installed
sudo openvpn --config openvpn/generated/client1.ovpn
```

- **Stop**: `Ctrl+C` (it runs in the foreground).
- **Status**: while running, check `ip addr show tun0` for the tunnel
  interface.
- **Verify**: `curl -4 https://ifconfig.me` should show the VPS's IP.

For persistence across reboots/backgrounding, copy the file to
`/etc/openvpn/client/<name>.conf` and use Ubuntu/Debian's built-in
`openvpn-client@<name>.service` template unit instead of running it by hand.

## WireGuard

```bash
sudo wireguard/client/apply.sh    # = wg-quick up wg0, plus a ping hint
```

- **Stop**: `sudo wg-quick down wg0`
- **Status**: `sudo wg show wg0`
- **Verify**: `ping <WG_SERVER_VPN_IP>` (printed by `apply.sh`), then
  `curl -4 https://ifconfig.me` should show the VPS's IP.

(`wg0` here is whatever `WG_INTERFACE` was set to in `config.env` — `wg0` by
default.)

For persistence across reboots: `sudo systemctl enable --now wg-quick@wg0`
instead of `apply.sh`.

## sing-box-reality

Two ways to run it — pick one:

```bash
sudo singbox-reality/client/run.sh          # foreground, Ctrl+C to stop
# or
sudo systemctl enable --now sing-box-client # background, survives reboot
```

- **Stop**: `Ctrl+C` (foreground mode) or `sudo systemctl stop sing-box-client`
  (service mode — add `disable` too if you don't want it starting on boot).
- **Status**: `sudo systemctl status sing-box-client`, or check
  `ip addr show singtun0` for the TUN interface.
- **Verify**: `curl -4 https://ifconfig.me` should show the VPS's IP.

## Shadowsocks

**SOCKS5 mode** (safe to combine with anything — apps must opt in):

```bash
sudo shadowsocks/client/start-socks.sh
```
- **Stop**: `sudo shadowsocks/client/stop-socks.sh`
- **Status**: `sudo systemctl status shadowsocks-client.service`
- **Verify**: `curl -4 --socks5 127.0.0.1:1080 https://ifconfig.me` should
  show the VPS's IP (port is `SS_LOCAL_PORT` from `config.env`, `1080` by
  default). Point individual apps/browsers at this SOCKS5 proxy to route
  just their traffic.

**Transparent mode** (system-wide TCP interception via `iptables` — see the
full-tunnel warning above):

```bash
sudo shadowsocks/client/start-transparent.sh   # foreground, Ctrl+C to stop
```
- **Stop**: `Ctrl+C`, or `sudo shadowsocks/client/stop-transparent.sh` if it
  was backgrounded/killed abruptly and the `iptables` rules were left behind.
- **Verify**: `curl -4 https://ifconfig.me` should show the VPS's IP
  directly, no proxy flag needed.

## Quick reference

| Protocol | Start | Stop | Full tunnel? |
|---|---|---|---|
| OpenVPN | `sudo openvpn --config <file>` | `Ctrl+C` | Yes |
| WireGuard | `sudo wireguard/client/apply.sh` | `sudo wg-quick down wg0` | Yes |
| sing-box-reality | `sudo singbox-reality/client/run.sh` | `Ctrl+C` | Yes |
| Shadowsocks (SOCKS5) | `sudo shadowsocks/client/start-socks.sh` | `sudo shadowsocks/client/stop-socks.sh` | No (opt-in per app) |
| Shadowsocks (transparent) | `sudo shadowsocks/client/start-transparent.sh` | `Ctrl+C` | Yes (via iptables) |
