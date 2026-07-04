#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

CHAIN_OUT="SS_REDIR_OUT"
iptables -t nat -D OUTPUT -p tcp -j "$CHAIN_OUT" 2>/dev/null || true
iptables -t nat -F "$CHAIN_OUT" 2>/dev/null || true
iptables -t nat -X "$CHAIN_OUT" 2>/dev/null || true
pkill -u shadowsocks ss-redir 2>/dev/null || true
log_info "Transparent proxy stopped and rules removed."
