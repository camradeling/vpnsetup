#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

systemctl restart shadowsocks-client.service
systemctl status shadowsocks-client.service --no-pager

source "$REPO_ROOT/config.env"
log_info "SOCKS5 proxy at 127.0.0.1:$SS_LOCAL_PORT"
log_info "Test: curl --socks5 127.0.0.1:$SS_LOCAL_PORT https://ifconfig.me"
