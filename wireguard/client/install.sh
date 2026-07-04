#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

install_packages wireguard wireguard-tools iproute2 qrencode gettext-base
apt-get install -y resolvconf 2>/dev/null || apt-get install -y openresolv 2>/dev/null || true

install -d -m 700 /etc/wireguard
log_info "WireGuard client dependencies installed."
