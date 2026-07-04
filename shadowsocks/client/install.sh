#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

install_packages shadowsocks-libev iptables iproute2 curl jq tcpdump gettext-base

# Create dedicated unprivileged user for ss-local / ss-redir
if ! id shadowsocks >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin shadowsocks
    log_info "Created system user: shadowsocks"
fi

install -d -m 755 /etc/shadowsocks-libev
log_info "Shadowsocks client dependencies installed."
log_info "Next: run sudo shadowsocks/client/configure.sh"
