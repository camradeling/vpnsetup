#!/usr/bin/env bash
# Shadowsocks has no per-client identity -- ss-server (as configured by this
# tool) uses a single shared password for every client; there's no per-user
# credential to mint without switching the daemon to ss-manager multi-user
# mode, which this repo doesn't set up. This script exists only so
# Shadowsocks fits the same add-client.sh interface as the other three
# protocols; it is a documented no-op.
# Run on the SERVER as root.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

until [[ "${CLIENT:-}" =~ ^[a-zA-Z0-9_-]+$ ]]; do
    read -rp "Client name (alphanumeric, dash, underscore): " CLIENT
done

log_info "Shadowsocks has no per-client identity: every client shares the same"
log_info "server password (SS_PASSWORD in config.env). Nothing to create for '$CLIENT'."
log_info "Each client renders its own local config from config.env via"
log_info "shadowsocks/client/configure.sh when client-install.sh runs there."
