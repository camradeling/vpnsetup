# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A unified, multi-protocol VPN setup toolkit for Ubuntu/Debian. Supports four protocols: OpenVPN, Shadowsocks-libev, WireGuard, and sing-box+Xray REALITY. All are driven by a single kconfig-style TUI configurator.

## Quickstart

```bash
./configure.sh          # whiptail TUI → writes config.env
sudo ./install-server.sh   # installs & starts enabled protocols on the VPS
sudo ./client-install.sh --server <server-ip>   # on the CLIENT: fetches config over SSH + installs
```

`client-install.sh` runs on the client machine, SSHes to the server (key-based
auth only) to run `create-client.sh` remotely, streams the resulting tarball
straight into `tar x` locally, then runs the per-protocol client
install/configure steps — one command instead of manually copying
`config.env` and the `generated/` directories over. `--bundle <path>` skips
SSH entirely and installs a tarball built ahead of time on the server via
`sudo ./create-client.sh > name.tar.gz` (optionally with `CLIENT=name`) --
useful for delivering bundles by any channel, not just live SSH. Every
bundle carries a `CLIENT_NAME` marker file at its root, since none of the
per-protocol files consistently identify which client they belong to
otherwise (WireGuard/sing-box are renamed to generic canonical filenames on
bundling).

Each protocol except Shadowsocks (always one shared password, no per-client
identity possible) has a `server/add-client.sh` for minting additional named
clients beyond the baseline one `configure.sh` creates:
```bash
sudo CLIENT=client2 openvpn/server/add-client.sh          # interactive PASS prompt; issues cert, writes ccd/<name>.ovpn
sudo CLIENT=client2 wireguard/server/add-client.sh        # new keypair+IP, applies live via `wg set`, existing peers unaffected
sudo CLIENT=client2 singbox-reality/server/add-client.sh  # new UUID appended to xray inbound, restarts xray to apply
```
`create-client.sh`'s own `CLIENT=name` selects which already-created client
to bundle (falls back to the baseline `WG_CLIENT_NAME`/`client1` identity);
for OpenVPN specifically it also auto-creates the cert on first bundle if
missing, since that lookup already generalizes to any name.

`sudo ./uninstall-server.sh` tears a server back down: stops/disables
services and removes applied `/etc` config, but leaves packages and
`generated/` (keys, certs, the OpenVPN PKI) in place so `install-server.sh`
can rebuild from the same identities. `--purge` additionally deletes
`generated/`/the PKI (irreversible) -- it still never removes packages.

## Directory structure

```
configure.sh            # kconfig-style TUI; writes config.env (chmod 600)
install-server.sh       # loops over ENABLED_PROTOCOLS, calls protocol/server/ scripts
uninstall-server.sh     # loops over ENABLED_PROTOCOLS, calls protocol/server/uninstall.sh
client-install.sh       # (client) fetches config over SSH from create-client.sh, or
                         # installs a pre-built bundle via --bundle, then loops over
                         # ENABLED_PROTOCOLS, calls protocol/client/ scripts
create-client.sh        # (server) bundles a given CLIENT's config across protocols into
                         # a tar stream on stdout; invoked remotely by client-install.sh
                         # or run directly to build a bundle file ahead of time
config.env              # generated; gitignored; sourced by all scripts
common/
  lib.sh                # shared: require_root, install_packages, render_template, load_config
openvpn/
  server/               # install.sh, configure.sh, add-client.sh, uninstall.sh, start.sh, stop.sh
  templates/            # server.conf.tpl, client.conf.tpl, iptables-{add,remove}.sh.tpl, openvpn.service.tpl
  docs/                 # README.md, ARCHITECTURE.md, CONFIG_REFERENCE.md
shadowsocks/
  server/               # install.sh, configure.sh, add-client.sh (no-op stub), uninstall.sh, start.sh, stop.sh, systemd/
  client/               # install.sh, configure.sh, start-socks.sh, stop-socks.sh, start-transparent.sh, stop-transparent.sh, systemd/
  templates/            # server-config.json.tpl, client-socks.json.tpl, android-config.json.tpl
  docs/
wireguard/
  server/               # install.sh, configure.sh, add-client.sh, apply.sh, uninstall.sh, start.sh, stop.sh, status.sh
  client/               # install.sh, configure.sh, apply.sh
  templates/            # server.conf.tpl, client.conf.tpl (documentation examples)
  docs/
singbox-reality/
  server/               # install.sh, configure.sh, add-client.sh, apply.sh, uninstall.sh, start.sh, stop.sh
  client/               # install.sh, configure.sh, run.sh, systemd/sing-box-client.service
  templates/            # xray-server.json.tpl, singbox-android.json.tpl, singbox-ubuntu-client.json.tpl
  docs/
```

The old top-level `vpn.sh`, `utils.sh`, and `templates/` remain for backward compatibility but are superseded by the protocol directories.

## Architecture

**Config flow:** `configure.sh` (TUI) → `config.env` → sourced by every script via `load_config` from `common/lib.sh`.

**Template system:** All templates use `__VAR__` placeholders. `render_template src dst [mode]` in `lib.sh` converts `__VAR__` to `${VAR}` then runs `envsubst` (from `gettext-base`). Variables must be `export`ed before calling `render_template`.

**Per-protocol flow:**
- `install.sh` — apt packages + any binary downloads (EasyRSA, Xray, sing-box)
- `configure.sh` — sources `config.env`, generates crypto material, stamps templates → `<protocol>/generated/`
- `apply.sh` — copies generated configs to system paths (`/etc/`, `/usr/local/etc/`)
- `start.sh` / `stop.sh` — systemd wrappers

**WireGuard exception:** `configure.sh` generates configs programmatically (here-docs) rather than from templates, because WireGuard configs have optional lines (PostUp/PostDown, PresharedKey) that can't be conditionally omitted with simple placeholder substitution. Templates in `wireguard/templates/` serve as documentation examples only.

**Secret handling:**
- `config.env` — contains passwords (SS_PASSWORD) and some optional UUIDs; chmod 600, gitignored
- `*/generated/` — all generated files including private keys; chmod 600 or 700, gitignored
- WireGuard private keys and sing-box REALITY keypair are **never** written to `config.env` — they are generated at `server/configure.sh` time and saved to `<protocol>/generated/secrets.env`

## Config variable prefixes

| Prefix | Protocol |
|---|---|
| (none) | Shared: `SERVER_PUBLIC_IP`, `ENABLED_PROTOCOLS` |
| `OVPN_` | OpenVPN |
| `SS_` | Shadowsocks |
| `WG_` | WireGuard |
| `SB_` | sing-box REALITY |

See `<protocol>/docs/CONFIG_REFERENCE.md` for full variable tables.

## Key constraints

- `envsubst` (from `gettext-base`) is required for template rendering — `common/lib.sh` will exit with a clear error if missing.
- OpenVPN: EasyRSA 3.0.7 is downloaded from GitHub at `openvpn/server/install.sh` time into `openvpn/easy-rsa/`.
- sing-box REALITY: `xray x25519` is used to auto-generate the REALITY keypair; if xray is not installed when `server/configure.sh` runs, the keys must be provided manually in `config.env` as `SB_REALITY_PRIVATE_KEY` / `SB_REALITY_PUBLIC_KEY`.
- WireGuard: IP forwarding is written to `/etc/sysctl.d/99-wireguard-forwarding.conf` only when `WG_ENABLE_NAT=yes`.
- Shadowsocks transparent mode runs `ss-redir` as the `shadowsocks` system user (created by `client/install.sh`); UID-based iptables owner matching prevents forwarding loops.
