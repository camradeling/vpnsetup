#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

install_packages curl wget tar jq ca-certificates gettext-base

if ! command -v sing-box >/dev/null 2>&1; then
    log_info "Installing sing-box..."
    bash -c "$(curl -fsSL https://sing-box.app/install.sh)"
else
    log_info "sing-box already installed: $(sing-box version 2>&1 | head -1)"
fi

log_info "Client dependencies installed."
log_info "Next: run sudo singbox-reality/client/configure.sh"
