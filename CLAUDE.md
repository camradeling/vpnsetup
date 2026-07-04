# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Bash-based OpenVPN server setup tool for Debian/Ubuntu systems. It automates PKI generation (via EasyRSA), server/client config creation, iptables rules, and systemd service management.

## Usage workflow

```bash
cp templates/config.template ./config   # create local config
# edit ./config — set PUBLIC_IP and VPN_IP at minimum
sudo ./vpn.sh install      # apt-installs openvpn, openssl, bc, etc. + downloads EasyRSA 3.0.7
sudo ./vpn.sh configure    # builds PKI, generates server config, iptables scripts, systemd unit
sudo ./vpn.sh start        # enables and starts openvpn-<SERVER_NAME>.service
sudo ./vpn.sh add          # interactive: creates a client cert and writes <CLIENT>.ovpn to $WORKDIR/ccd/
sudo ./vpn.sh stop         # disables and stops the service
```

Must be run as root. Requires `/dev/net/tun`.

## Architecture

**Entry point:** `vpn.sh` — sources `./config` and `./utils.sh`, then dispatches to a function based on `$1`.

**All logic lives in `utils.sh`** — the five main functions:
- `install_prerequisites` — checks/installs apt packages and downloads EasyRSA from GitHub
- `configure_openvpn_server` — builds the PKI, generates all config files by stamping templates
- `start_vpnserver` / `stop_vpnserver` — systemd wrappers
- `add_client` — generates a client cert and assembles an inline `.ovpn` file (certs embedded)

**Template system:** `templates/` holds `.template` files with `%%%VAR%%%` placeholders. `configure_openvpn_server` and `create_client_template` copy templates to `$WORKDIR` and stamp them with `sed -i`. All generated runtime files go into `$WORKDIR` (default: `/root/servers/<SERVER_NAME>`).

**Config file (`./config`, copied from `templates/config.template`):** shell variables sourced directly into the scripts. The two required variables are `PUBLIC_IP` and `VPN_IP`. Everything else has safe defaults.

**Generated file layout under `$WORKDIR`:**
- `<SERVER_NAME>.conf` — OpenVPN server config
- `client.template` — base client config (certs appended per-client by `add_client`)
- `ccd/<CLIENT>.ovpn` and `ccd/<CLIENT>.conf` — client configs to distribute
- `pki/` — EasyRSA PKI directory
- `iptables_add_rules.sh` / `iptables_remove_rules.sh` — called by the systemd unit's `ExecStartPost`/`ExecStopPost`
- `logs/` — OpenVPN status log

**Systemd unit** is written to `/etc/systemd/system/openvpn-<SERVER_NAME>.service` and calls the iptables scripts on start/stop.

## Key constraints

- EasyRSA is pinned to version 3.0.7 and downloaded from GitHub at configure time if not present locally.
- Template substitution uses `%%%VAR%%%` as the delimiter — keep this convention when adding new placeholders.
- `add_client` reads `$EASYRSA_PATH/pki/index.txt` (not `$WORKDIR/pki`) to check for duplicate CNs — both paths must be consistent.
