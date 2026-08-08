#!/usr/bin/env bash
# Adds a new named sing-box REALITY client: mints a UUID, appends it to the
# xray inbound's clients array, and restarts xray to apply.
#
# Note: this briefly interrupts any already-connected clients (REALITY has
# no hot-reload without enabling Xray's separate gRPC API, which is out of
# scope here) -- unlike wireguard/server/add-client.sh, which applies live.
#
# Run on the SERVER as root.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

GEN_DIR="$REPO_ROOT/singbox-reality/generated"
CONFIG_JSON="$GEN_DIR/xray-server.json"
SECRETS="$GEN_DIR/secrets.env"
LIVE_CONFIG="/usr/local/etc/xray/config.json"

if [[ ! -f "$CONFIG_JSON" ]] || [[ ! -f "$SECRETS" ]]; then
    log_err "Server config not found under $GEN_DIR"
    log_err "Run: sudo singbox-reality/server/configure.sh first."
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    log_err "jq is required. Run: sudo singbox-reality/server/install.sh"
    exit 1
fi

until [[ "${CLIENT:-}" =~ ^[a-zA-Z0-9_-]+$ ]]; do
    read -rp "Client name (alphanumeric, dash, underscore): " CLIENT
done

if jq -e --arg c "$CLIENT" '.inbounds[0].settings.clients[] | select(.email == $c)' "$CONFIG_JSON" >/dev/null; then
    log_err "Client '$CLIENT' already exists in $CONFIG_JSON."
    exit 1
fi

NEW_UUID="$(command -v uuidgen >/dev/null 2>&1 && uuidgen || cat /proc/sys/kernel/random/uuid)"

jq --arg id "$NEW_UUID" --arg email "$CLIENT" \
    '.inbounds[0].settings.clients += [{"id": $id, "flow": "xtls-rprx-vision", "email": $email}]' \
    "$CONFIG_JSON" > "$CONFIG_JSON.tmp"
mv "$CONFIG_JSON.tmp" "$CONFIG_JSON"
chmod 600 "$CONFIG_JSON"

install -o root -g nogroup -m 640 "$CONFIG_JSON" "$LIVE_CONFIG"
systemctl restart xray
systemctl status xray --no-pager

# shellcheck disable=SC1090
source "$SECRETS"
# SB_REALITY_PRIVATE_KEY intentionally excluded -- server-only secret.
cat > "$GEN_DIR/secrets-${CLIENT}.env" <<ENV
SB_UUID=$NEW_UUID
SB_SHORT_ID=$SB_SHORT_ID
SB_REALITY_PUBLIC_KEY=$SB_REALITY_PUBLIC_KEY
ENV
chmod 600 "$GEN_DIR/secrets-${CLIENT}.env"

log_info "Client '$CLIENT' added (UUID $NEW_UUID)"
log_info "  $GEN_DIR/secrets-${CLIENT}.env"
log_info "Note: xray was restarted to apply -- any already-connected clients had to reconnect."
