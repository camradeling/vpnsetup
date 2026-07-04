#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root

EASYRSA_VERSION="3.0.7"
EASYRSA_DIR="$REPO_ROOT/openvpn/easy-rsa"

install_packages openvpn iptables openssl ca-certificates wget tar curl bc gettext-base

if [[ ! -f "$EASYRSA_DIR/easyrsa" ]]; then
    log_info "Downloading EasyRSA $EASYRSA_VERSION..."
    wget -q -O /tmp/easy-rsa.tgz \
        "https://github.com/OpenVPN/easy-rsa/releases/download/v${EASYRSA_VERSION}/EasyRSA-${EASYRSA_VERSION}.tgz"
    mkdir -p "$EASYRSA_DIR"
    tar xzf /tmp/easy-rsa.tgz --strip-components=1 --directory "$EASYRSA_DIR"
    rm -f /tmp/easy-rsa.tgz
    log_info "EasyRSA installed at $EASYRSA_DIR"
else
    log_info "EasyRSA already present at $EASYRSA_DIR"
fi
