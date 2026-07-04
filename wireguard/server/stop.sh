#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

wg-quick down "$WG_INTERFACE"
systemctl disable "wg-quick@$WG_INTERFACE"
