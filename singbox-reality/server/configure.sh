#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

GEN_DIR="$REPO_ROOT/singbox-reality/generated"
SECRETS="$GEN_DIR/secrets.env"
mkdir -p "$GEN_DIR"
chmod 700 "$GEN_DIR"

# Auto-generate UUID if not set
if [[ -z "${SB_UUID:-}" ]]; then
    if command -v uuidgen >/dev/null 2>&1; then
        SB_UUID="$(uuidgen)"
    else
        SB_UUID="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || openssl rand -hex 16 | sed 's/.\{8\}/&-/;s/.\{13\}/&-/;s/.\{18\}/&-/;s/.\{23\}/&-/')"
    fi
    log_info "Auto-generated UUID: $SB_UUID"
fi

# Auto-generate short_id if not set
if [[ -z "${SB_SHORT_ID:-}" ]]; then
    SB_SHORT_ID="$(openssl rand -hex 8)"
    log_info "Auto-generated short_id: $SB_SHORT_ID"
fi

# Generate REALITY x25519 keypair
if [[ -z "${SB_REALITY_PRIVATE_KEY:-}" ]] || [[ -z "${SB_REALITY_PUBLIC_KEY:-}" ]]; then
    if command -v xray >/dev/null 2>&1; then
        log_info "Generating REALITY x25519 keypair with xray..."
        KEY_OUT="$(xray x25519)"
        SB_REALITY_PRIVATE_KEY="$(printf '%s\n' "$KEY_OUT" | grep -i '^Private' | awk -F': ' '{print $2}')"
        SB_REALITY_PUBLIC_KEY="$(printf '%s\n' "$KEY_OUT" | grep -i 'Public' | awk -F': ' '{print $2}')"
    else
        log_err "SB_REALITY_PRIVATE_KEY / SB_REALITY_PUBLIC_KEY not set in config.env"
        log_err "and xray is not installed to auto-generate them."
        log_err "Run sudo singbox-reality/server/install.sh first."
        exit 1
    fi
fi

export SERVER_PUBLIC_IP SB_PORT SB_UUID SB_SNI SB_REALITY_PRIVATE_KEY SB_REALITY_PUBLIC_KEY
export SB_SHORT_ID SB_LOG_LEVEL SB_TUN_MTU

render_template "$REPO_ROOT/singbox-reality/templates/xray-server.json.tpl" \
    "$GEN_DIR/xray-server.json" 600

# Validate JSON
if command -v jq >/dev/null 2>&1; then
    jq . "$GEN_DIR/xray-server.json" >/dev/null
fi

# Save generated secrets for use by client/configure.sh
cat > "$SECRETS" <<ENV
SB_UUID=$SB_UUID
SB_SHORT_ID=$SB_SHORT_ID
SB_REALITY_PRIVATE_KEY=$SB_REALITY_PRIVATE_KEY
SB_REALITY_PUBLIC_KEY=$SB_REALITY_PUBLIC_KEY
ENV
chmod 600 "$SECRETS"

log_info "Xray server config: $GEN_DIR/xray-server.json"
log_info "Secrets saved to:   $SECRETS  (keep private)"
log_info "Next: sudo singbox-reality/server/apply.sh"
