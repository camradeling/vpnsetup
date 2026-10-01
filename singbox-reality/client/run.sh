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

HOOK="$REPO_ROOT/singbox-reality/client/dns-hook.sh"
SB_PID=""

cleanup() {
    if [[ -n "$SB_PID" ]] && kill -0 "$SB_PID" 2>/dev/null; then
        kill "$SB_PID" 2>/dev/null || true
        wait "$SB_PID" 2>/dev/null || true
    fi
    "$HOOK" down
}
trap cleanup EXIT INT TERM

log_info "Starting sing-box with $CONFIG"
log_info "Press Ctrl+C to stop."
sing-box run -c "$CONFIG" &
SB_PID=$!
"$HOOK" up
wait "$SB_PID"
