#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

systemctl daemon-reload
systemctl enable "openvpn-$OVPN_SERVER_NAME"
systemctl start  "openvpn-$OVPN_SERVER_NAME"
systemctl status "openvpn-$OVPN_SERVER_NAME" --no-pager
