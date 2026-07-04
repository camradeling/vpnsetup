#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

wg-quick up "$WG_INTERFACE"
log_info "WireGuard client interface $WG_INTERFACE is up."
log_info "Test: ping $WG_SERVER_VPN_IP"
