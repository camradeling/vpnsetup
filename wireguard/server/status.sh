#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

echo "=== wg show ==="
wg show "$WG_INTERFACE" 2>/dev/null || wg show
echo ""
echo "=== Interface address ==="
ip addr show "$WG_INTERFACE" 2>/dev/null || true
echo ""
echo "=== Routes ==="
ip route show dev "$WG_INTERFACE" 2>/dev/null || true
