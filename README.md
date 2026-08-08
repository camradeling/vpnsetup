# vpnsetup

A unified, multi-protocol VPN setup toolkit for Ubuntu/Debian servers.

## Supported protocols

| Protocol | DPI resistance | Transport | Server binary | Client binary |
|---|---|---|---|---|
| OpenVPN | Low | UDP or TCP | `openvpn` | OpenVPN client |
| Shadowsocks | Low–medium | TCP + UDP | `ss-server` | `ss-local` / `ss-redir` |
| WireGuard | Low | UDP | kernel | `wg-quick` |
| sing-box REALITY | High | TCP (port 443) | Xray | sing-box |

## Quickstart

### 1. Configure

```bash
./configure.sh
```

A menu-driven TUI (`whiptail`) walks through all settings for each enabled protocol and writes `config.env`.

The only required field is **Server public IP**. All other settings have sensible defaults.

### 2. Install server side (on the VPS)

```bash
sudo ./install-server.sh
```

Calls `install.sh → configure.sh → apply.sh → start.sh` for each enabled protocol in sequence.

### 3. Install client side (on client machines)

```bash
sudo ./client-install.sh --server <server-ip>
```

Fetches this client's config bundle from the server over SSH (key-based auth
only), then installs and configures the client side for every enabled
protocol. Requires key-based SSH access to the server as `root` (override
with `--user`/`--key`/`--remote-dir`; see `--help`).

## Protocol directories

```
openvpn/          shadowsocks/          wireguard/          singbox-reality/
├── server/       ├── server/           ├── server/         ├── server/
├── client/       ├── client/           ├── client/         ├── client/
├── templates/    ├── templates/        ├── templates/      ├── templates/
└── docs/         └── docs/             └── docs/           └── docs/
```

Each protocol has the same layout. See `<protocol>/docs/README.md` for usage details and `<protocol>/docs/CONFIG_REFERENCE.md` for all configuration variables.

## Common library

`common/lib.sh` — shared functions sourced by all scripts:
- `require_root` — exit if not root
- `install_packages` — idempotent apt install
- `render_template src dst [mode]` — `__VAR__` placeholder substitution via `envsubst`
- `netmask_to_cidr` — dotted-quad mask → CIDR prefix length
- `load_config` — source `config.env` from repo root

## Security notes

- `config.env` contains secrets (passwords, possibly UUIDs). It is `chmod 600` and gitignored.
- `*/generated/` directories contain private keys and are gitignored.
- WireGuard and sing-box REALITY private keys are never written to `config.env` — they live only in `*/generated/secrets.env` (chmod 600).
- sing-box REALITY is the only protocol here that actively resists deep packet inspection. The others are identifiable by traffic analysis.
