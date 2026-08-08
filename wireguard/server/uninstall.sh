#!/usr/bin/env bash
# Uninstalls the WireGuard server: tears down the interface, disables the
# wg-quick unit, and removes the applied /etc/wireguard config + forwarding
# sysctl file. With PURGE=1, also permanently deletes generated/ (server +
# all peer keys) -- irreversible. Packages are never removed by this script.
# Run on the SERVER as root.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

if [[ "${PURGE:-0}" == "1" ]] && [[ "${PURGE_CONFIRMED:-0}" != "1" ]]; then
    echo "This will PERMANENTLY delete all WireGuard keys/peer configs in $REPO_ROOT/wireguard/generated."
    read -rp "Type 'yes' to confirm: " CONFIRM
    [[ "$CONFIRM" == "yes" ]] || { log_err "Aborted."; exit 1; }
fi

wg-quick down "$WG_INTERFACE" 2>/dev/null || true
systemctl disable "wg-quick@$WG_INTERFACE" 2>/dev/null || true
rm -f "/etc/wireguard/${WG_INTERFACE}.conf"
rm -f /etc/sysctl.d/99-wireguard-forwarding.conf
sysctl --system >/dev/null 2>&1 || true

log_info "WireGuard interface torn down, disabled, and applied config removed."

if [[ "${PURGE:-0}" == "1" ]]; then
    rm -rf "$REPO_ROOT/wireguard/generated"
    log_info "Purged: generated/ (keys, peer configs). (wireguard packages left installed.)"
else
    log_info "Left in place: generated/ (keys, peer configs). Use --purge to remove."
fi
