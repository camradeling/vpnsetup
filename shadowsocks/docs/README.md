# Shadowsocks

Pure Shadowsocks-libev (`ss-server` / `ss-local` / `ss-redir`) with AEAD encryption. No obfuscation layer — traffic is distinguishable by deep packet inspection, but the payload is encrypted. Best used where simple blocking is the concern, not active DPI.

## Server setup

```bash
./configure.sh                           # set SS_* variables
sudo shadowsocks/server/install.sh       # apt-install shadowsocks-libev
sudo shadowsocks/server/configure.sh     # render config, install systemd unit
sudo shadowsocks/server/start.sh         # start service
```

Verify:
```bash
systemctl status shadowsocks --no-pager
ss -lunpt | grep $SS_SERVER_PORT
```

## Client setup (Ubuntu)

```bash
sudo shadowsocks/client/install.sh       # install ss-local/ss-redir, create user
sudo shadowsocks/client/configure.sh     # render client config, install systemd unit
```

### SOCKS5 mode (per-app proxy)

```bash
sudo shadowsocks/client/start-socks.sh
curl --socks5 127.0.0.1:$SS_LOCAL_PORT https://ifconfig.me
```

### Transparent TCP mode (system-wide)

Redirects all outgoing TCP through ss-redir via iptables nat OUTPUT. Loop prevention: traffic from the `shadowsocks` UID is returned directly.

```bash
sudo shadowsocks/client/start-transparent.sh
# runs in foreground; press Ctrl+C to stop and restore rules
```

Emergency rule removal (if the foreground process was killed):
```bash
sudo shadowsocks/client/stop-transparent.sh
```

## Android

Import `shadowsocks/generated/android-config.json` into the Shadowsocks Android app, or enter the server/port/password/method manually.
