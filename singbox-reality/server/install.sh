#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

install_packages curl wget unzip tar jq uuid-runtime ca-certificates tcpdump iproute2 gettext-base

if ! command -v xray >/dev/null 2>&1; then
    log_info "Installing Xray..."
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
else
    log_info "Xray already installed: $(xray version 2>&1 | head -1)"
fi

if ! command -v sing-box >/dev/null 2>&1; then
    log_info "Installing sing-box..."
    bash -c "$(curl -fsSL https://sing-box.app/install.sh)"
else
    log_info "sing-box already installed: $(sing-box version 2>&1 | head -1)"
fi

log_info "Server dependencies installed."
log_info "Next: run sudo singbox-reality/server/configure.sh"
