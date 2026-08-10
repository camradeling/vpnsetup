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

**Option A — live fetch over SSH** (needs key-based SSH access to the server as `root`):

```bash
sudo ./client-install.sh --server <server-ip>
```

SSHes to the server, runs `create-client.sh` there, streams the resulting
tarball straight into this repo, then installs and configures the client
side for every enabled protocol. Override the SSH user/key/remote repo path
with `--user`/`--key`/`--remote-dir` if needed.

**Option B — pre-built bundle** (no SSH needed on the client machine):

On the server:

```bash
sudo ./create-client.sh > client1-bundle.tar.gz
```

Deliver `client1-bundle.tar.gz` to the client machine by whatever means
(scp, USB, etc.), then on the client:

```bash
sudo ./client-install.sh --bundle client1-bundle.tar.gz
```

### 4. Add more clients (on the VPS)

OpenVPN, WireGuard, and sing-box-reality each support real per-client
identities (Shadowsocks is always a single shared password — nothing to add
there). To mint a new named client:

```bash
sudo CLIENT=client2 openvpn/server/add-client.sh
sudo CLIENT=client2 wireguard/server/add-client.sh          # applies live, existing peers unaffected
sudo CLIENT=client2 singbox-reality/server/add-client.sh    # restarts xray to apply
```

`create-client.sh` doesn't run these for you uniformly: for WireGuard and
sing-box-reality it requires the named client to already exist and errors
out with the command above if not, so run all three before bundling a new
name. OpenVPN is the one exception — `create-client.sh` auto-creates the
cert on first bundle if it's missing, so that step is optional (skipping it
just means the cert gets minted implicitly by the next command instead).

Then bundle that client specifically (works with either install option above):

```bash
sudo CLIENT=client2 ./create-client.sh > client2-bundle.tar.gz
# or, for the live-fetch flow from the client machine:
sudo ./client-install.sh --server <server-ip> --client client2
```

Every bundle contains a `CLIENT_NAME` marker file at its root recording
which client it was built for — check `cat CLIENT_NAME` in the repo after
installing to confirm.

### 5. Uninstall server side (on the VPS)

```bash
sudo ./uninstall-server.sh            # stop/disable services, remove applied /etc config (reversible)
sudo ./uninstall-server.sh --purge    # also permanently delete generated/ keys, certs, the OpenVPN PKI
```

Packages are never removed by either mode. Without `--purge`, re-running
`install-server.sh` restores the same identities from `generated/`. With
`--purge`, a later `install-server.sh` run generates entirely new
keys/certs and every existing client config becomes invalid.

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
