#!/usr/bin/env bash
# Uninstalls the Shadowsocks server: stops/disables the service and removes
# the installed systemd unit + /etc/shadowsocks-libev config. With PURGE=1,
# also permanently deletes generated/ -- irreversible. Packages are never
# removed by this script.
# Run on the SERVER as root.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

if [[ "${PURGE:-0}" == "1" ]] && [[ "${PURGE_CONFIRMED:-0}" != "1" ]]; then
    echo "This will PERMANENTLY delete the Shadowsocks server password/config."
    read -rp "Type 'yes' to confirm: " CONFIRM
    [[ "$CONFIRM" == "yes" ]] || { log_err "Aborted."; exit 1; }
fi

systemctl stop    shadowsocks 2>/dev/null || true
systemctl disable shadowsocks 2>/dev/null || true
rm -f /etc/systemd/system/shadowsocks.service
systemctl daemon-reload
rm -rf /etc/shadowsocks-libev

log_info "Shadowsocks service stopped, disabled, unit and /etc config removed."

if [[ "${PURGE:-0}" == "1" ]]; then
    rm -rf "$REPO_ROOT/shadowsocks/generated"
    log_info "Purged: generated/. (shadowsocks-libev package left installed.)"
else
    log_info "Left in place: generated/. Use --purge to remove."
fi
