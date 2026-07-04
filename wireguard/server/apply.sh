#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

SRC="$REPO_ROOT/wireguard/generated/server_wg0.conf"
DST="/etc/wireguard/${WG_INTERFACE}.conf"

if [[ ! -f "$SRC" ]]; then
    log_err "Server config not found: $SRC"
    log_err "Run: sudo wireguard/server/configure.sh"
    exit 1
fi

install -m 600 "$SRC" "$DST"
log_info "Installed $SRC → $DST"
log_info "Start with: sudo wireguard/server/start.sh"
