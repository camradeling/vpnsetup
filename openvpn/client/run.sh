#!/usr/bin/env bash
# Run the OpenVPN client in the foreground with the Linux DNS/IPv6 hook
# (see dns-hook.sh). Ctrl+C to stop.
#
# Usage: sudo openvpn/client/run.sh [CLIENT=<name>]
# Defaults to whichever single .ovpn file was bundled into openvpn/generated/.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

GEN_DIR="$REPO_ROOT/openvpn/generated"
HOOK="$REPO_ROOT/openvpn/client/dns-hook.sh"

if [[ -n "${CLIENT:-}" ]]; then
    OVPN_FILE="$GEN_DIR/$CLIENT.ovpn"
else
    OVPN_FILE="$(find "$GEN_DIR" -maxdepth 1 -name '*.ovpn' 2>/dev/null | head -1)"
fi
[[ -n "$OVPN_FILE" && -f "$OVPN_FILE" ]] || { log_err "No .ovpn file found in $GEN_DIR. Run client-install.sh first, or set CLIENT=<name>."; exit 1; }

command -v openvpn >/dev/null 2>&1 || install_packages openvpn

log_info "Starting OpenVPN with $OVPN_FILE (Ctrl+C to stop)"
exec openvpn --config "$OVPN_FILE" \
    --script-security 2 --up "$HOOK" --down "$HOOK" --down-pre
