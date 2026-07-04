#!/usr/bin/env bash
# Copies the generated client config to /etc/wireguard/ on the client machine.
# Run this on the CLIENT host, not the server.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

GEN_DIR="$REPO_ROOT/wireguard/generated"
SRC="$GEN_DIR/client_linux.conf"

if [[ ! -f "$SRC" ]]; then
    log_err "Client config not found: $SRC"
    log_err "Run configure.sh on the SERVER first, then copy the generated/ directory here."
    exit 1
fi

install -m 600 "$SRC" "/etc/wireguard/${WG_INTERFACE}.conf"
log_info "Client config installed at /etc/wireguard/${WG_INTERFACE}.conf"
log_info "Start with: sudo wg-quick up $WG_INTERFACE"
log_info "Autostart:  sudo systemctl enable wg-quick@$WG_INTERFACE"
