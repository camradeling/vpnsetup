#!/usr/bin/env bash
# Uninstalls server-side components for all enabled protocols.
# Run on the VPS as root.
#
# Default: stops + disables each protocol's systemd service and removes the
# applied system config (systemd units, /etc files) -- reversible, since the
# generated/ material (keys, certs, the OpenVPN PKI) is left alone, so
# re-running install-server.sh brings it back using the same identities.
#
# --purge: additionally deletes each protocol's generated/ directory
# (private keys, certs, the OpenVPN PKI). This is NOT reversible -- any
# client using existing keys/certs will need reissued credentials
# afterward. Packages are never removed, even with --purge.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

PURGE=0
for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=1 ;;
        *) log_err "Unknown argument: $arg"; exit 1 ;;
    esac
done

CONFIG_ENV="$REPO_ROOT/config.env"
if [[ ! -f "$CONFIG_ENV" ]]; then
    log_err "config.env not found. Nothing to uninstall."
    exit 1
fi
source "$CONFIG_ENV"

if [[ -z "${ENABLED_PROTOCOLS:-}" ]]; then
    log_err "ENABLED_PROTOCOLS is empty. Nothing to uninstall."
    exit 1
fi

if [[ "$PURGE" -eq 1 ]]; then
    echo "This will PERMANENTLY delete keys/certs/PKI and remove packages for: $ENABLED_PROTOCOLS"
    read -rp "Type 'yes' to confirm: " CONFIRM
    [[ "$CONFIRM" == "yes" ]] || { log_err "Aborted."; exit 1; }
    export PURGE PURGE_CONFIRMED=1
else
    export PURGE
fi

log_info "Uninstalling server for protocols: $ENABLED_PROTOCOLS"

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
        openvpn)         run_step "openvpn/server/uninstall.sh" ;;
        shadowsocks)     run_step "shadowsocks/server/uninstall.sh" ;;
        wireguard)       run_step "wireguard/server/uninstall.sh" ;;
        singbox-reality) run_step "singbox-reality/server/uninstall.sh" ;;
        *) log_err "Unknown protocol: $proto" ;;
    esac
done

echo ""
log_info "Server uninstall complete. Packages were left installed."
if [[ "$PURGE" -eq 0 ]]; then
    log_info "generated/ (keys, certs) was also left in place. Re-run with --purge to remove it too."
fi
