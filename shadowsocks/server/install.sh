#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

install_packages shadowsocks-libev curl jq iproute2 tcpdump gettext-base

install -d -m 755 /etc/shadowsocks-libev
log_info "Shadowsocks-libev server dependencies installed."
log_info "Next: run sudo shadowsocks/server/configure.sh"
