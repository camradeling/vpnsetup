#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

systemctl stop    "openvpn-$OVPN_SERVER_NAME"
systemctl disable "openvpn-$OVPN_SERVER_NAME"
