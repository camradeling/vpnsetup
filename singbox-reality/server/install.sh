#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

XRAY_VERSION="26.3.27"
SINGBOX_VERSION="1.13.16"

install_packages curl wget unzip tar jq uuid-runtime ca-certificates tcpdump iproute2 gettext-base

CURRENT_XRAY_VERSION="$(command -v xray >/dev/null 2>&1 && xray version 2>&1 | awk 'NR==1{print $2}' || true)"
if [[ "$CURRENT_XRAY_VERSION" != "$XRAY_VERSION" ]]; then
    log_info "Installing Xray v${XRAY_VERSION}..."
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version "$XRAY_VERSION"
else
    log_info "Xray already installed: v$CURRENT_XRAY_VERSION"
fi

CURRENT_SINGBOX_VERSION="$(command -v sing-box >/dev/null 2>&1 && sing-box version 2>&1 | awk 'NR==1{print $3}' || true)"
if [[ "$CURRENT_SINGBOX_VERSION" != "$SINGBOX_VERSION" ]]; then
    log_info "Installing sing-box v${SINGBOX_VERSION}..."
    bash -c "$(curl -fsSL https://sing-box.app/install.sh)" @ --version "$SINGBOX_VERSION"
else
    log_info "sing-box already installed: v$CURRENT_SINGBOX_VERSION"
fi

log_info "Server dependencies installed."
log_info "Next: run sudo singbox-reality/server/configure.sh"
