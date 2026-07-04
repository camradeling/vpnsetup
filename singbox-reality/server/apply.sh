#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

SRC="$REPO_ROOT/singbox-reality/generated/xray-server.json"
DST="/usr/local/etc/xray/config.json"

if [[ ! -f "$SRC" ]]; then
    log_err "Server config not found: $SRC"
    log_err "Run: sudo singbox-reality/server/configure.sh"
    exit 1
fi

install -d -m 755 /usr/local/etc/xray
install -m 600 "$SRC" "$DST"
systemctl restart xray
systemctl status xray --no-pager

log_info "Xray config installed at $DST"
log_info "Check listener: sudo ss -lntp | grep :$(grep -o '\"port\": [0-9]*' "$SRC" | head -1 | awk '{print $2}')"
