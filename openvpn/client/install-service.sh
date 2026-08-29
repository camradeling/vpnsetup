#!/usr/bin/env bash
# Optional: run the OpenVPN client as a persistent systemd service instead
# of the plain `openvpn --config ...` foreground usage described in
# USAGE.md. Not run automatically by client-install.sh.
#
# Usage: sudo openvpn/client/install-service.sh [CLIENT=<name>]
# Defaults to whichever single .ovpn file was bundled into openvpn/generated/.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

GEN_DIR="$REPO_ROOT/openvpn/generated"
CLIENT_NAME="${CLIENT:-}"

if [[ -z "$CLIENT_NAME" ]]; then
    OVPN_FILE="$(find "$GEN_DIR" -maxdepth 1 -name '*.ovpn' 2>/dev/null | head -1)"
    [[ -n "$OVPN_FILE" ]] || { log_err "No .ovpn file found in $GEN_DIR. Run client-install.sh first, or set CLIENT=<name>."; exit 1; }
    CLIENT_NAME="$(basename "$OVPN_FILE" .ovpn)"
else
    OVPN_FILE="$GEN_DIR/$CLIENT_NAME.ovpn"
fi

[[ -f "$OVPN_FILE" ]] || { log_err "Client config not found: $OVPN_FILE"; exit 1; }

command -v openvpn >/dev/null 2>&1 || install_packages openvpn

install -d -m 755 /etc/openvpn/client
install -m 600 "$OVPN_FILE" "/etc/openvpn/client/$CLIENT_NAME.conf"

export OVPN_CLIENT_NAME="$CLIENT_NAME"
UNIT_NAME="openvpn-client-$CLIENT_NAME"
render_template "$REPO_ROOT/openvpn/templates/openvpn-client.service.tpl" \
    "/etc/systemd/system/$UNIT_NAME.service" 644
systemctl daemon-reload

log_info "Installed: /etc/openvpn/client/$CLIENT_NAME.conf"
log_info "Enable + start now:  sudo systemctl enable --now $UNIT_NAME"
log_info "Status:              sudo systemctl status $UNIT_NAME"
log_info "Stop:                sudo systemctl stop $UNIT_NAME"
