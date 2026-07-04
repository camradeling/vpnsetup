# Shadowsocks Configuration Reference

| Variable | Default | Description |
|---|---|---|
| `SS_SERVER_PORT` | `8388` | Port `ss-server` listens on |
| `SS_PASSWORD` | auto-generated | Shared secret (auto-generated if left blank in configurator) |
| `SS_METHOD` | `chacha20-ietf-poly1305` | AEAD cipher (`chacha20-ietf-poly1305`, `aes-256-gcm`, `aes-128-gcm`) |
| `SS_TIMEOUT` | `300` | Connection idle timeout in seconds |
| `SS_LOCAL_PORT` | `1080` | Local SOCKS5 port for `ss-local` |
| `SS_REDIR_PORT` | `1081` | Local transparent redirect port for `ss-redir` |

`SERVER_PUBLIC_IP` (shared common variable) is used by client configs to reach the server.

## Template placeholders → config.env variables

| Template placeholder | Variable |
|---|---|
| `__SS_SERVER_PORT__` | `SS_SERVER_PORT` |
| `__SS_PASSWORD__` | `SS_PASSWORD` |
| `__SS_METHOD__` | `SS_METHOD` |
| `__SS_TIMEOUT__` | `SS_TIMEOUT` |
| `__SS_LOCAL_PORT__` | `SS_LOCAL_PORT` |
| `__SS_REDIR_PORT__` | `SS_REDIR_PORT` |
| `__SERVER_PUBLIC_IP__` | `SERVER_PUBLIC_IP` (shared) |

## Generated files

| File | Purpose |
|---|---|
| `shadowsocks/generated/server-config.json` | Installed to `/etc/shadowsocks-libev/config.json` |
| `shadowsocks/generated/client-socks.json` | Installed to `/etc/shadowsocks-libev/client.json` |
| `shadowsocks/generated/android-config.json` | Import into Shadowsocks Android app |
