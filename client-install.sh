#!/usr/bin/env bash
# Bootstraps a VPN client machine against a vpnsetup server, end to end:
# obtains this client's config bundle (either by SSHing to the server and
# running create-client.sh remotely, or from a bundle file built ahead of
# time -- see --bundle), extracts it into this repo, then installs and
# configures the client side for every enabled protocol.
# Run on the CLIENT as root.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

SSH_USER="root"
SSH_KEY=""
REMOTE_DIR=""
SERVER=""
CLIENT_NAME=""
BUNDLE=""

usage() {
    cat <<EOF
Usage: sudo $0 --server <ip-or-host> [options]
       sudo $0 --bundle <path> [--server <ip-or-host>]

Obtains this client's config bundle and installs it, then runs the
per-protocol client install/configure steps.

By default, fetches the bundle live over SSH (key-based auth only) by
running create-client.sh on the server. With --bundle, skips SSH entirely
and installs a bundle file built ahead of time on the server via:
  sudo ./create-client.sh > client1-bundle.tar.gz
  # or for a specific client: sudo CLIENT=client2 ./create-client.sh > client2-bundle.tar.gz

Options:
  --server <host>      Server IP or SSH host (required unless --bundle is given)
  --bundle <path>      Install from a pre-built tarball instead of SSH-fetching
  --client <name>      Client identity to request from create-client.sh
                        (default: the protocols' baseline client)
  --user <name>        SSH user on the server (default: root)
  --key <path>          SSH private key to use (default: ssh-agent/default keys)
  --remote-dir <path>  Path to the vpnsetup repo on the server
                        (default: auto-discovered under the SSH user's home dir)
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --server) SERVER="$2"; shift 2 ;;
        --bundle) BUNDLE="$2"; shift 2 ;;
        --client) CLIENT_NAME="$2"; shift 2 ;;
        --user) SSH_USER="$2"; shift 2 ;;
        --key) SSH_KEY="$2"; shift 2 ;;
        --remote-dir) REMOTE_DIR="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) log_err "Unknown argument: $1"; usage; exit 1 ;;
    esac
done

if [[ -n "$CLIENT_NAME" ]] && [[ ! "$CLIENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_err "--client must be alphanumeric, dash, or underscore only."
    exit 1
fi

if [[ -n "$BUNDLE" ]]; then
    install_packages tar
    if [[ ! -f "$BUNDLE" ]]; then
        log_err "Bundle not found: $BUNDLE"
        exit 1
    fi
    tar xzf "$BUNDLE" -C "$REPO_ROOT"
    log_info "Client bundle installed under $REPO_ROOT from $BUNDLE"
else
    if [[ -z "$SERVER" ]]; then
        log_err "--server or --bundle is required."
        usage
        exit 1
    fi

    install_packages openssh-client tar

    # BatchMode=yes: fail fast instead of prompting for a password. Key-based
    # auth only -- an SSH password would end up in argv/shell history.
    SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new)
    [[ -n "$SSH_KEY" ]] && SSH_OPTS+=(-i "$SSH_KEY")

    if [[ -z "$REMOTE_DIR" ]]; then
        log_info "Locating vpnsetup repo on $SERVER..."
        REMOTE_DIR="$(ssh "${SSH_OPTS[@]}" "$SSH_USER@$SERVER" \
            'find "$HOME" -maxdepth 4 -name create-client.sh 2>/dev/null | head -1 | xargs -r dirname')"
        if [[ -z "$REMOTE_DIR" ]]; then
            log_err "Could not reach $SSH_USER@$SERVER via key-based SSH, or couldn't find"
            log_err "create-client.sh under $SSH_USER's home dir there."
            log_err "Set up an SSH key (ssh-copy-id) and/or pass --remote-dir explicitly."
            exit 1
        fi
        log_info "Found repo at $SERVER:$REMOTE_DIR"
    fi

    log_info "Fetching client bundle from $SERVER..."
    REMOTE_CMD="bash '$REMOTE_DIR/create-client.sh'"
    [[ -n "$CLIENT_NAME" ]] && REMOTE_CMD="CLIENT='$CLIENT_NAME' $REMOTE_CMD"
    ssh "${SSH_OPTS[@]}" "$SSH_USER@$SERVER" "$REMOTE_CMD" | tar xzf - -C "$REPO_ROOT"
    log_info "Client bundle installed under $REPO_ROOT"
fi

if [[ -f "$REPO_ROOT/CLIENT_NAME" ]]; then
    log_info "Bundle is for client: $(cat "$REPO_ROOT/CLIENT_NAME")"
fi

CONFIG_ENV="$REPO_ROOT/config.env"
if [[ ! -f "$CONFIG_ENV" ]]; then
    log_err "config.env not found after extraction. Something went wrong with the bundle."
    exit 1
fi
source "$CONFIG_ENV"

if [[ -z "${ENABLED_PROTOCOLS:-}" ]]; then
    log_err "ENABLED_PROTOCOLS is empty in the fetched config.env."
    exit 1
fi

log_info "Installing client for protocols: $ENABLED_PROTOCOLS"

run_step() {
    local script="$1"
    if [[ -f "$REPO_ROOT/$script" ]]; then
        log_info ">>> $script"
        bash "$REPO_ROOT/$script"
    else
        log_err "Script not found: $script (skipping)"
    fi
}

for proto in $ENABLED_PROTOCOLS; do
    echo ""
    log_info "━━━ $proto ━━━"
    case "$proto" in
        openvpn)
            OVPN_FILE="$(find "$REPO_ROOT/openvpn/generated" -maxdepth 1 -name '*.ovpn' 2>/dev/null | head -1)"
            log_info "OpenVPN client: install the openvpn package and import the .ovpn file"
            log_info "  sudo apt-get install -y openvpn"
            [[ -n "$OVPN_FILE" ]] && log_info "  sudo openvpn --config $OVPN_FILE"
            ;;
        shadowsocks)
            run_step "shadowsocks/client/install.sh"
            run_step "shadowsocks/client/configure.sh"
            log_info "Start SOCKS5:      sudo shadowsocks/client/start-socks.sh"
            log_info "Start transparent: sudo shadowsocks/client/start-transparent.sh"
            ;;
        wireguard)
            run_step "wireguard/client/install.sh"
            run_step "wireguard/client/configure.sh"
            log_info "Bring up tunnel: sudo wg-quick up $WG_INTERFACE"
            ;;
        singbox-reality)
            run_step "singbox-reality/client/install.sh"
            run_step "singbox-reality/client/configure.sh"
            log_info "Run manually:  sudo singbox-reality/client/run.sh"
            log_info "Or as service: sudo systemctl enable --now sing-box-client"
            ;;
        *)
            log_err "Unknown protocol: $proto"
            ;;
    esac
done

echo ""
log_info "Client installation complete."
