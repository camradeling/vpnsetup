#!/usr/bin/env bash
# Installs and configures client-side components for all enabled protocols.
# Run on the CLIENT machine as root after running ./configure.sh.
# The wireguard/generated/ and singbox-reality/generated/ directories must be
# present (copy them from the server after running install-server.sh).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

CONFIG_ENV="$REPO_ROOT/config.env"
if [[ ! -f "$CONFIG_ENV" ]]; then
    log_err "config.env not found. Run: ./configure.sh"
    exit 1
fi
source "$CONFIG_ENV"

if [[ -z "${ENABLED_PROTOCOLS:-}" ]]; then
    log_err "ENABLED_PROTOCOLS is empty. Run: ./configure.sh"
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
            # OpenVPN client config is the .ovpn file from add-client.sh.
            # Install the OpenVPN package so the client can import it.
            log_info "OpenVPN client: install the openvpn package and import the .ovpn file"
            log_info "  sudo apt-get install -y openvpn"
            log_info "  sudo openvpn --config <client>.ovpn"
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
