#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

GEN_DIR="$REPO_ROOT/shadowsocks/generated"
mkdir -p "$GEN_DIR"

export SERVER_PUBLIC_IP SS_SERVER_PORT SS_PASSWORD SS_METHOD SS_TIMEOUT SS_LOCAL_PORT SS_REDIR_PORT

render_template "$REPO_ROOT/shadowsocks/templates/client-socks.json.tpl" \
    "$GEN_DIR/client-socks.json" 600
render_template "$REPO_ROOT/shadowsocks/templates/android-config.json.tpl" \
    "$GEN_DIR/android-config.json" 600

install -m 600 "$GEN_DIR/client-socks.json" /etc/shadowsocks-libev/client.json

UNIT_SRC="$REPO_ROOT/shadowsocks/client/systemd/shadowsocks-client.service"
install -m 644 "$UNIT_SRC" /etc/systemd/system/shadowsocks-client.service
systemctl daemon-reload

log_info "Client config installed at /etc/shadowsocks-libev/client.json"
log_info "Android config: $GEN_DIR/android-config.json"
log_info ""
log_info "SOCKS5 mode: sudo shadowsocks/client/start-socks.sh"
log_info "Transparent: sudo shadowsocks/client/start-transparent.sh"
