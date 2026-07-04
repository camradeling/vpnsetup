# sing-box + Xray VLESS REALITY

The most DPI-resistant protocol in this repo. The server runs **Xray** with VLESS + REALITY + `xtls-rprx-vision`. The connection mimics TLS 1.3 to a real external host (the SNI), making it indistinguishable from normal HTTPS at the transport layer. Clients run **sing-box** with a TUN inbound for system-wide proxying.

## Server setup

```bash
./configure.sh                                # set SB_* variables
sudo singbox-reality/server/install.sh        # install Xray + sing-box
sudo singbox-reality/server/configure.sh      # generate UUID/keys, stamp xray config
sudo singbox-reality/server/apply.sh          # deploy to /usr/local/etc/xray/config.json
sudo singbox-reality/server/start.sh          # start xray service
```

Verify:
```bash
sudo ss -lntp | grep :$SB_PORT
sudo journalctl -u xray -e --no-pager
```

## Ubuntu client setup

```bash
sudo singbox-reality/client/install.sh       # install sing-box
sudo singbox-reality/client/configure.sh     # stamp client config, install systemd unit

# Run manually (foreground):
sudo singbox-reality/client/run.sh

# Or as persistent service:
sudo systemctl enable --now sing-box-client
```

Test:
```bash
curl https://ifconfig.me   # should return the server's IP
```

## Android client

Import `singbox-reality/generated/singbox-android.json` into **SFA (sing-box for Android)** and press Play. The VPN key icon should appear.

## DNS fix (critical for Android)

The `route.rules` section must have `sniff` **before** `hijack-dns`. Without `sniff`, DNS queries to the TUN's internal DNS address (e.g. `172.19.0.2:53`) are forwarded as plain UDP through VLESS instead of being intercepted, causing `EOF` errors and broken DNS.

```json
"rules": [
  { "action": "sniff" },
  { "protocol": "dns", "action": "hijack-dns" },
  { "ip_cidr": ["<server_ip>/32"], "outbound": "direct" }
]
```

This is already correct in the templates.

## Stop server

```bash
sudo singbox-reality/server/stop.sh
```
