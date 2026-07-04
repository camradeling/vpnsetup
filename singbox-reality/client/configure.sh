#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

GEN_DIR="$REPO_ROOT/singbox-reality/generated"
SECRETS="$GEN_DIR/secrets.env"

if [[ ! -f "$SECRETS" ]]; then
    log_err "Secrets file not found: $SECRETS"
    log_err "Run server configure first, then copy the generated/ directory here."
    exit 1
fi

# shellcheck disable=SC1090
source "$SECRETS"

export SERVER_PUBLIC_IP SB_PORT SB_UUID SB_SNI SB_REALITY_PUBLIC_KEY
export SB_SHORT_ID SB_LOG_LEVEL SB_TUN_MTU

render_template "$REPO_ROOT/singbox-reality/templates/singbox-android.json.tpl" \
    "$GEN_DIR/singbox-android.json" 600
render_template "$REPO_ROOT/singbox-reality/templates/singbox-ubuntu-client.json.tpl" \
    "$GEN_DIR/singbox-ubuntu-client.json" 600

if command -v jq >/dev/null 2>&1; then
    jq . "$GEN_DIR/singbox-android.json" >/dev/null
    jq . "$GEN_DIR/singbox-ubuntu-client.json" >/dev/null
fi

install -d -m 755 /etc/sing-box
install -m 600 "$GEN_DIR/singbox-ubuntu-client.json" /etc/sing-box/config.json

UNIT_SRC="$REPO_ROOT/singbox-reality/client/systemd/sing-box-client.service"
install -m 644 "$UNIT_SRC" /etc/systemd/system/sing-box-client.service
systemctl daemon-reload

log_info "Ubuntu client config: /etc/sing-box/config.json"
log_info "Android config:       $GEN_DIR/singbox-android.json"
log_info ""
log_info "Run:     sudo singbox-reality/client/run.sh"
log_info "Systemd: sudo systemctl enable --now sing-box-client"
