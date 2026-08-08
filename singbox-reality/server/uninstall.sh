#!/usr/bin/env bash
# Uninstalls the sing-box-reality server: stops/disables xray and removes
# the applied /usr/local/etc/xray config. With PURGE=1, also removes xray
# (via its own uninstaller) and the sing-box package, and permanently
# deletes generated/ (REALITY keypair, all client UUIDs/secrets) --
# irreversible.
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
    if command -v xray >/dev/null 2>&1; then
        bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge 2>/dev/null || true
    fi
    if dpkg -s sing-box >/dev/null 2>&1; then
        apt-get purge -y sing-box 2>/dev/null || true
    fi
    rm -rf "$REPO_ROOT/singbox-reality/generated"
    log_info "Purged: xray, sing-box package, generated/ (REALITY keys, client secrets)."
else
    log_info "Left in place: xray/sing-box binaries, generated/ (REALITY keys, client secrets). Use --purge to remove."
fi
