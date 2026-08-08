#!/usr/bin/env bash
# Uninstalls the sing-box-reality server: stops/disables xray and removes
# the applied /usr/local/etc/xray config. With PURGE=1, also permanently
# deletes generated/ (REALITY keypair, all client UUIDs/secrets) --
# irreversible. The xray/sing-box binaries are never removed by this script.
# Run on the SERVER as root.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

if [[ "${PURGE:-0}" == "1" ]] && [[ "${PURGE_CONFIRMED:-0}" != "1" ]]; then
    echo "This will PERMANENTLY delete the REALITY keypair and all client UUIDs/secrets."
    read -rp "Type 'yes' to confirm: " CONFIRM
    [[ "$CONFIRM" == "yes" ]] || { log_err "Aborted."; exit 1; }
fi

systemctl stop    xray 2>/dev/null || true
systemctl disable xray 2>/dev/null || true
rm -f /usr/local/etc/xray/config.json

log_info "Xray service stopped, disabled, and applied config removed."

if [[ "${PURGE:-0}" == "1" ]]; then
    rm -rf "$REPO_ROOT/singbox-reality/generated"
    log_info "Purged: generated/ (REALITY keys, client secrets). (xray/sing-box binaries left installed.)"
else
    log_info "Left in place: generated/ (REALITY keys, client secrets). Use --purge to remove."
fi
