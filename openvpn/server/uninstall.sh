#!/usr/bin/env bash
# Uninstalls the OpenVPN server: stops/disables the service and removes the
# installed systemd unit + sysctl file. With PURGE=1, also removes the
# openvpn package and permanently deletes the PKI (CA, server + all client
# certs) at OVPN_WORKDIR -- irreversible.
# Run on the SERVER as root.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/common/lib.sh"
require_root
load_config

if [[ "${PURGE:-0}" == "1" ]] && [[ "${PURGE_CONFIRMED:-0}" != "1" ]]; then
    echo "This will PERMANENTLY delete the OpenVPN PKI (CA, server + all client certs) at $OVPN_WORKDIR."
    read -rp "Type 'yes' to confirm: " CONFIRM
    [[ "$CONFIRM" == "yes" ]] || { log_err "Aborted."; exit 1; }
fi

systemctl stop    "openvpn-$OVPN_SERVER_NAME" 2>/dev/null || true
systemctl disable "openvpn-$OVPN_SERVER_NAME" 2>/dev/null || true
rm -f "/etc/systemd/system/openvpn-$OVPN_SERVER_NAME.service"
rm -f /etc/sysctl.d/99-openvpn.conf
systemctl daemon-reload

log_info "OpenVPN service stopped, disabled, and unit removed."

if [[ "${PURGE:-0}" == "1" ]]; then
    apt-get purge -y openvpn 2>/dev/null || true
    rm -rf "$OVPN_WORKDIR"
    rm -rf "$REPO_ROOT/openvpn/easy-rsa"
    log_info "Purged: openvpn package, $OVPN_WORKDIR (PKI/certs), easy-rsa."
else
    log_info "Left in place: openvpn package, $OVPN_WORKDIR (PKI/certs). Use --purge to remove."
fi
