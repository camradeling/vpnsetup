#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

wg-quick up "$WG_INTERFACE"
systemctl enable "wg-quick@$WG_INTERFACE"
log_info "WireGuard interface $WG_INTERFACE is up."
