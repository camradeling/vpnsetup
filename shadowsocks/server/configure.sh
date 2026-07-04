#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

UNIT_SRC="$REPO_ROOT/shadowsocks/server/systemd/shadowsocks.service"
GEN_DIR="$REPO_ROOT/shadowsocks/generated"
mkdir -p "$GEN_DIR"

export SERVER_PUBLIC_IP SS_SERVER_PORT SS_PASSWORD SS_METHOD SS_TIMEOUT SS_LOCAL_PORT SS_REDIR_PORT

render_template "$REPO_ROOT/shadowsocks/templates/server-config.json.tpl" \
    "$GEN_DIR/server-config.json" 600

install -m 600 "$GEN_DIR/server-config.json" /etc/shadowsocks-libev/config.json
install -m 644 "$UNIT_SRC" /etc/systemd/system/shadowsocks.service
systemctl daemon-reload
systemctl enable shadowsocks.service

# Open port if UFW is active
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow "${SS_SERVER_PORT}/tcp"
    ufw allow "${SS_SERVER_PORT}/udp"
fi

log_info "Shadowsocks server configured."
log_info "Check: systemctl status shadowsocks --no-pager"
