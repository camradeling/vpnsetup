#!/usr/bin/env bash
# Installs and configures server-side components for all enabled protocols.
# Run on the VPS as root after running ./configure.sh.
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

log_info "Installing server for protocols: $ENABLED_PROTOCOLS"

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
            run_step "openvpn/server/install.sh"
            run_step "openvpn/server/configure.sh"
            run_step "openvpn/server/start.sh"
            ;;
        shadowsocks)
            run_step "shadowsocks/server/install.sh"
            run_step "shadowsocks/server/configure.sh"
            run_step "shadowsocks/server/start.sh"
            ;;
        wireguard)
            run_step "wireguard/server/install.sh"
            run_step "wireguard/server/configure.sh"
            run_step "wireguard/server/apply.sh"
            run_step "wireguard/server/start.sh"
            ;;
        singbox-reality)
            run_step "singbox-reality/server/install.sh"
            run_step "singbox-reality/server/configure.sh"
            run_step "singbox-reality/server/apply.sh"
            run_step "singbox-reality/server/start.sh"
            ;;
        *)
            log_err "Unknown protocol: $proto"
            ;;
    esac
done

echo ""
log_info "Server installation complete."
log_info "For OpenVPN clients, run: sudo openvpn/server/add-client.sh"
log_info "For WireGuard clients, distribute: wireguard/generated/client_linux.conf or client_android.png"
log_info "For sing-box clients, distribute: singbox-reality/generated/singbox-android.json"
