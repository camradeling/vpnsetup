#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

CONFIG="${1:-/etc/sing-box/config.json}"
if [[ ! -f "$CONFIG" ]]; then
    log_err "Config not found: $CONFIG"
    log_err "Run: sudo singbox-reality/client/configure.sh"
    exit 1
fi

log_info "Starting sing-box with $CONFIG"
log_info "Press Ctrl+C to stop."
exec sing-box run -c "$CONFIG"
