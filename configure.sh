#!/usr/bin/env bash
# kconfig-style interactive configurator.
# Uses whiptail (part of newt, pre-installed on Ubuntu) to provide
# a menu-driven TUI for setting all VPN parameters.
# Writes config.env to the repo root when saved.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ENV="$REPO_ROOT/config.env"

if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail not found. Install with: sudo apt-get install -y whiptail" >&2
    exit 1
fi

# Load existing config so re-runs preserve prior choices
if [[ -f "$CONFIG_ENV" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_ENV"
fi

# ── Defaults ──────────────────────────────────────────────────────────────────
SERVER_PUBLIC_IP="${SERVER_PUBLIC_IP:-}"
ENABLED_PROTOCOLS="${ENABLED_PROTOCOLS:-openvpn shadowsocks wireguard singbox-reality}"

OVPN_SERVER_NAME="${OVPN_SERVER_NAME:-myvpnserver}"
OVPN_WORKDIR="${OVPN_WORKDIR:-/root/servers/myvpnserver}"
OVPN_PORT="${OVPN_PORT:-1194}"
OVPN_PROTOCOL="${OVPN_PROTOCOL:-udp}"
OVPN_VPN_IP="${OVPN_VPN_IP:-10.9.0.0}"
OVPN_VPN_SUBNET_MASK="${OVPN_VPN_SUBNET_MASK:-255.255.255.0}"
OVPN_DNS1="${OVPN_DNS1:-8.8.8.8}"
OVPN_DNS2="${OVPN_DNS2:-4.4.4.4}"
OVPN_CIPHER="${OVPN_CIPHER:-AES-128-GCM}"
OVPN_CERT_TYPE="${OVPN_CERT_TYPE:-ECDSA}"
OVPN_CERT_CURVE="${OVPN_CERT_CURVE:-prime256v1}"
OVPN_RSA_KEY_SIZE="${OVPN_RSA_KEY_SIZE:-2048}"
OVPN_CC_CIPHER="${OVPN_CC_CIPHER:-TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256}"
OVPN_DH_TYPE="${OVPN_DH_TYPE:-ECDH}"
OVPN_DH_CURVE="${OVPN_DH_CURVE:-prime256v1}"
OVPN_DH_KEY_SIZE="${OVPN_DH_KEY_SIZE:-2048}"
OVPN_HMAC_ALG="${OVPN_HMAC_ALG:-SHA256}"
OVPN_TLS_SIG="${OVPN_TLS_SIG:-tls-crypt}"
OVPN_COMPRESSION_ENABLED="${OVPN_COMPRESSION_ENABLED:-n}"
OVPN_COMPRESSION_ALG="${OVPN_COMPRESSION_ALG:-lz4-v2}"

SS_SERVER_PORT="${SS_SERVER_PORT:-8388}"
SS_PASSWORD="${SS_PASSWORD:-}"
SS_METHOD="${SS_METHOD:-chacha20-ietf-poly1305}"
SS_TIMEOUT="${SS_TIMEOUT:-300}"
SS_LOCAL_PORT="${SS_LOCAL_PORT:-1080}"
SS_REDIR_PORT="${SS_REDIR_PORT:-1081}"

WG_INTERFACE="${WG_INTERFACE:-wg0}"
WG_PORT="${WG_PORT:-51820}"
WG_VPN_CIDR="${WG_VPN_CIDR:-10.66.66.0/24}"
WG_SERVER_VPN_IP="${WG_SERVER_VPN_IP:-10.66.66.1}"
WG_CLIENT_NAME="${WG_CLIENT_NAME:-client1}"
WG_CLIENT_IP="${WG_CLIENT_IP:-10.66.66.2}"
WG_DNS="${WG_DNS:-1.1.1.1, 8.8.8.8}"
WG_ROUTING_MODE="${WG_ROUTING_MODE:-3}"
WG_CLIENT_ALLOWED_IPS="${WG_CLIENT_ALLOWED_IPS:-0.0.0.0/0, ::/0}"
WG_ENABLE_NAT="${WG_ENABLE_NAT:-yes}"
WG_ENABLE_PSK="${WG_ENABLE_PSK:-yes}"

SB_PORT="${SB_PORT:-443}"
SB_SNI="${SB_SNI:-www.cloudflare.com}"
SB_UUID="${SB_UUID:-}"
SB_SHORT_ID="${SB_SHORT_ID:-}"
SB_LOG_LEVEL="${SB_LOG_LEVEL:-info}"
SB_TUN_MTU="${SB_TUN_MTU:-1400}"

# ── Helpers ───────────────────────────────────────────────────────────────────
wt_input() {
    # wt_input VAR "prompt" height width
    local var="$1" prompt="$2" h="${3:-8}" w="${4:-70}"
    local cur="${!var}"
    local val
    val=$(whiptail --title "VPN Configuration" --inputbox "$prompt" "$h" "$w" "$cur" \
        3>&1 1>&2 2>&3) || return 0
    printf -v "$var" '%s' "$val"
}

wt_radio() {
    # wt_radio VAR "prompt" option1 desc1 option2 desc2 ...
    local var="$1" prompt="$2"; shift 2
    local cur="${!var}"
    local args=()
    while [[ $# -ge 2 ]]; do
        local opt="$1" desc="$2"; shift 2
        args+=("$opt" "$desc" "$([[ "$cur" == "$opt" ]] && echo ON || echo OFF)")
    done
    local val
    val=$(whiptail --title "VPN Configuration" --radiolist "$prompt" 20 70 10 \
        "${args[@]}" 3>&1 1>&2 2>&3) || return 0
    printf -v "$var" '%s' "$val"
}

wt_yesno() {
    local var="$1" prompt="$2"
    local cur="${!var}"
    local default_btn="--defaultno"
    [[ "$cur" =~ ^[Yy] ]] && default_btn=""
    if whiptail --title "VPN Configuration" $default_btn --yesno "$prompt" 8 70 \
        3>&1 1>&2 2>&3; then
        printf -v "$var" '%s' "yes"
    else
        printf -v "$var" '%s' "no"
    fi
}

proto_enabled() { echo "$ENABLED_PROTOCOLS" | grep -qw "$1"; }
toggle_state()  { proto_enabled "$1" && echo ON || echo OFF; }

# ── Section configurators ─────────────────────────────────────────────────────
configure_common() {
    wt_input SERVER_PUBLIC_IP "Server public IPv4 address (required by all client configs):"

    local choices
    choices=$(whiptail --title "VPN Configuration" \
        --checklist "Select protocols to install:" 14 72 4 \
        "openvpn"        "OpenVPN (TLS, PKI, UDP/TCP)"                   "$(toggle_state openvpn)" \
        "shadowsocks"    "Shadowsocks-libev (AEAD encrypted SOCKS proxy)" "$(toggle_state shadowsocks)" \
        "wireguard"      "WireGuard (modern UDP tunnel)"                  "$(toggle_state wireguard)" \
        "singbox-reality" "sing-box + Xray VLESS REALITY (DPI evasion)"   "$(toggle_state singbox-reality)" \
        3>&1 1>&2 2>&3) || return 0
    ENABLED_PROTOCOLS="$(echo "$choices" | tr -d '"')"
}

configure_openvpn() {
    wt_input OVPN_SERVER_NAME "Server name (used for certs and service name):"
    OVPN_WORKDIR="/root/servers/$OVPN_SERVER_NAME"
    wt_input OVPN_PORT "Listen port:"
    wt_radio OVPN_PROTOCOL "Transport protocol:" \
        udp "UDP  (recommended — lower latency)" \
        tcp "TCP  (use if UDP is blocked)"
    wt_input OVPN_VPN_IP "VPN tunnel subnet base IP (e.g. 10.9.0.0):"
    wt_input OVPN_VPN_SUBNET_MASK "VPN subnet mask (e.g. 255.255.255.0):"
    wt_input OVPN_DNS1 "Primary DNS pushed to clients:"
    wt_input OVPN_DNS2 "Secondary DNS pushed to clients:"
    wt_radio OVPN_CIPHER "Data channel cipher:" \
        AES-128-GCM "AES-128-GCM (recommended)" \
        AES-256-GCM "AES-256-GCM" \
        AES-128-CBC "AES-128-CBC (legacy)" \
        AES-256-CBC "AES-256-CBC (legacy)"
    wt_radio OVPN_CERT_TYPE "Certificate type:" \
        ECDSA "ECDSA (recommended)" \
        RSA   "RSA"
    if [[ "$OVPN_CERT_TYPE" == "ECDSA" ]]; then
        wt_radio OVPN_CERT_CURVE "ECDSA curve:" \
            prime256v1 "prime256v1 (recommended)" \
            secp384r1  "secp384r1" \
            secp521r1  "secp521r1"
        # Keep CC_CIPHER aligned with cert type
        wt_radio OVPN_CC_CIPHER "Control channel cipher:" \
            TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256 "ECDHE-ECDSA-AES-128-GCM-SHA256 (recommended)" \
            TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384 "ECDHE-ECDSA-AES-256-GCM-SHA384"
    else
        wt_radio OVPN_RSA_KEY_SIZE "RSA key size:" \
            2048 "2048 bits (recommended)" \
            3072 "3072 bits" \
            4096 "4096 bits"
        wt_radio OVPN_CC_CIPHER "Control channel cipher:" \
            TLS-ECDHE-RSA-WITH-AES-128-GCM-SHA256 "ECDHE-RSA-AES-128-GCM-SHA256 (recommended)" \
            TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384 "ECDHE-RSA-AES-256-GCM-SHA384"
    fi
    wt_radio OVPN_DH_TYPE "Diffie-Hellman type:" \
        ECDH "ECDH (recommended — ephemeral, no file)" \
        DH   "DH   (classic, generates dh.pem)"
    if [[ "$OVPN_DH_TYPE" == "ECDH" ]]; then
        wt_radio OVPN_DH_CURVE "ECDH curve:" \
            prime256v1 "prime256v1 (recommended)" \
            secp384r1  "secp384r1" \
            secp521r1  "secp521r1"
    else
        wt_radio OVPN_DH_KEY_SIZE "DH key size (bits):" \
            2048 "2048 (recommended)" \
            3072 "3072" \
            4096 "4096"
    fi
    wt_radio OVPN_HMAC_ALG "HMAC digest algorithm:" \
        SHA256 "SHA256 (recommended)" \
        SHA384 "SHA384" \
        SHA512 "SHA512"
    wt_radio OVPN_TLS_SIG "Additional TLS protection:" \
        tls-crypt "tls-crypt  (recommended — authenticates + encrypts control channel)" \
        tls-auth  "tls-auth   (authenticates control channel only)"
    wt_yesno OVPN_COMPRESSION_ENABLED "Enable compression? (not recommended — VORACLE attack risk)"
    if [[ "$OVPN_COMPRESSION_ENABLED" =~ ^[Yy] ]]; then
        wt_radio OVPN_COMPRESSION_ALG "Compression algorithm:" \
            lz4-v2 "lz4-v2 (fastest)" \
            lz4    "lz4" \
            lzo    "lzo"
    fi
}

configure_shadowsocks() {
    wt_input SS_SERVER_PORT "Server listen port:"
    if whiptail --title "Shadowsocks" --yesno \
        "Auto-generate a random password?" 8 50 3>&1 1>&2 2>&3; then
        SS_PASSWORD="$(openssl rand -base64 32 | tr -d '\n')"
        whiptail --title "Shadowsocks" --msgbox \
            "Generated password:\n\n$SS_PASSWORD\n\n(will be saved to config.env)" 12 70 \
            3>&1 1>&2 2>&3 || true
    else
        wt_input SS_PASSWORD "Password:"
    fi
    wt_radio SS_METHOD "Cipher method:" \
        chacha20-ietf-poly1305 "chacha20-ietf-poly1305 (recommended)" \
        aes-256-gcm            "aes-256-gcm" \
        aes-128-gcm            "aes-128-gcm"
    wt_input SS_TIMEOUT "Connection timeout (seconds):"
    wt_input SS_LOCAL_PORT "Local SOCKS5 port (ss-local, for client):"
    wt_input SS_REDIR_PORT "Local transparent redir port (ss-redir, for client):"
}

configure_wireguard() {
    wt_input WG_INTERFACE "WireGuard interface name:"
    wt_input WG_PORT      "UDP listen port:"
    wt_input WG_VPN_CIDR  "VPN network CIDR (e.g. 10.66.66.0/24):"
    wt_input WG_SERVER_VPN_IP "Server VPN IP (e.g. 10.66.66.1):"
    wt_input WG_CLIENT_NAME   "Client name:"
    wt_input WG_CLIENT_IP     "Client VPN IP (e.g. 10.66.66.2):"
    wt_input WG_DNS           "Client DNS servers (comma-separated):"
    wt_radio WG_ROUTING_MODE "Client routing mode:" \
        1 "Server VPN IP only  (AllowedIPs = server/32)" \
        2 "Whole VPN subnet    (AllowedIPs = VPN CIDR)" \
        3 "Full tunnel         (AllowedIPs = 0.0.0.0/0 — all traffic via server)" \
        4 "Custom AllowedIPs   (enter manually below)"
    if [[ "$WG_ROUTING_MODE" == "4" ]]; then
        wt_input WG_CLIENT_ALLOWED_IPS "Custom AllowedIPs (comma-separated CIDRs):"
    fi
    wt_yesno WG_ENABLE_NAT "Enable server-side IPv4 NAT? (required for full-tunnel mode)"
    wt_yesno WG_ENABLE_PSK "Use a PresharedKey between server and client? (extra symmetric layer)"
}

configure_singbox() {
    wt_input SB_PORT "Xray listen port (usually 443 to blend with HTTPS):"
    wt_input SB_SNI  "REALITY SNI / destination host (must be a real TLS 1.3 site, e.g. www.cloudflare.com):"
    if whiptail --title "sing-box REALITY" --yesno \
        "Auto-generate VLESS UUID?" 8 50 3>&1 1>&2 2>&3; then
        SB_UUID=""   # configure.sh will generate at runtime
        whiptail --title "sing-box REALITY" --msgbox \
            "UUID will be auto-generated when you run singbox-reality/server/configure.sh" \
            8 70 3>&1 1>&2 2>&3 || true
    else
        wt_input SB_UUID "VLESS UUID:"
    fi
    if whiptail --title "sing-box REALITY" --yesno \
        "Auto-generate REALITY short_id and x25519 keypair?\n(Requires xray to be installed on the server)" \
        10 70 3>&1 1>&2 2>&3; then
        SB_SHORT_ID=""  # generated at configure time
    else
        wt_input SB_SHORT_ID "REALITY short_id (hex, e.g. 0123456789abcdef):"
    fi
    wt_radio SB_LOG_LEVEL "sing-box client log level:" \
        info    "info    (default)" \
        debug   "debug   (verbose)" \
        warning "warning (quiet)" \
        error   "error   (errors only)"
    wt_input SB_TUN_MTU "TUN MTU (default 1400):"
}

# ── Save ──────────────────────────────────────────────────────────────────────
save_config() {
    cat > "$CONFIG_ENV" <<CONFIG
# Generated by configure.sh on $(date)
# Run ./configure.sh to modify. Do NOT commit this file (it contains secrets).

SERVER_PUBLIC_IP='${SERVER_PUBLIC_IP}'
ENABLED_PROTOCOLS='${ENABLED_PROTOCOLS}'

# ── OpenVPN ──────────────────────────────────────────────────────────────────
OVPN_SERVER_NAME='${OVPN_SERVER_NAME}'
OVPN_WORKDIR='${OVPN_WORKDIR}'
OVPN_PORT='${OVPN_PORT}'
OVPN_PROTOCOL='${OVPN_PROTOCOL}'
OVPN_VPN_IP='${OVPN_VPN_IP}'
OVPN_VPN_SUBNET_MASK='${OVPN_VPN_SUBNET_MASK}'
OVPN_DNS1='${OVPN_DNS1}'
OVPN_DNS2='${OVPN_DNS2}'
OVPN_CIPHER='${OVPN_CIPHER}'
OVPN_CERT_TYPE='${OVPN_CERT_TYPE}'
OVPN_CERT_CURVE='${OVPN_CERT_CURVE}'
OVPN_RSA_KEY_SIZE='${OVPN_RSA_KEY_SIZE}'
OVPN_CC_CIPHER='${OVPN_CC_CIPHER}'
OVPN_DH_TYPE='${OVPN_DH_TYPE}'
OVPN_DH_CURVE='${OVPN_DH_CURVE}'
OVPN_DH_KEY_SIZE='${OVPN_DH_KEY_SIZE}'
OVPN_HMAC_ALG='${OVPN_HMAC_ALG}'
OVPN_TLS_SIG='${OVPN_TLS_SIG}'
OVPN_COMPRESSION_ENABLED='${OVPN_COMPRESSION_ENABLED}'
OVPN_COMPRESSION_ALG='${OVPN_COMPRESSION_ALG}'

# ── Shadowsocks ───────────────────────────────────────────────────────────────
SS_SERVER_PORT='${SS_SERVER_PORT}'
SS_PASSWORD='${SS_PASSWORD}'
SS_METHOD='${SS_METHOD}'
SS_TIMEOUT='${SS_TIMEOUT}'
SS_LOCAL_PORT='${SS_LOCAL_PORT}'
SS_REDIR_PORT='${SS_REDIR_PORT}'

# ── WireGuard ─────────────────────────────────────────────────────────────────
WG_INTERFACE='${WG_INTERFACE}'
WG_PORT='${WG_PORT}'
WG_VPN_CIDR='${WG_VPN_CIDR}'
WG_SERVER_VPN_IP='${WG_SERVER_VPN_IP}'
WG_CLIENT_NAME='${WG_CLIENT_NAME}'
WG_CLIENT_IP='${WG_CLIENT_IP}'
WG_DNS='${WG_DNS}'
WG_ROUTING_MODE='${WG_ROUTING_MODE}'
WG_CLIENT_ALLOWED_IPS='${WG_CLIENT_ALLOWED_IPS}'
WG_ENABLE_NAT='${WG_ENABLE_NAT}'
WG_ENABLE_PSK='${WG_ENABLE_PSK}'

# ── sing-box REALITY ──────────────────────────────────────────────────────────
SB_PORT='${SB_PORT}'
SB_SNI='${SB_SNI}'
SB_UUID='${SB_UUID}'
SB_SHORT_ID='${SB_SHORT_ID}'
SB_LOG_LEVEL='${SB_LOG_LEVEL}'
SB_TUN_MTU='${SB_TUN_MTU}'
CONFIG
    chmod 600 "$CONFIG_ENV"

    whiptail --title "Saved" --msgbox \
        "Configuration saved to:\n$CONFIG_ENV\n\nEnabled protocols: $ENABLED_PROTOCOLS\n\nRun ./install-server.sh  (on the VPS)\nor  ./install-client.sh  (on client machines)." \
        14 70 3>&1 1>&2 2>&3 || true
}

# ── Main menu loop ────────────────────────────────────────────────────────────
while true; do
    CHOICE=$(whiptail --title "VPN Setup — Configuration" \
        --menu "Navigate to a section. Changes take effect when you Save." \
        20 72 8 \
        "1" "Common settings       (server IP, enabled protocols)" \
        "2" "OpenVPN settings" \
        "3" "Shadowsocks settings" \
        "4" "WireGuard settings" \
        "5" "sing-box REALITY settings" \
        "6" "Save & exit" \
        "7" "Exit without saving" \
        3>&1 1>&2 2>&3) || break

    case "$CHOICE" in
        1) configure_common ;;
        2) configure_openvpn ;;
        3) configure_shadowsocks ;;
        4) configure_wireguard ;;
        5) configure_singbox ;;
        6) save_config; exit 0 ;;
        7) exit 0 ;;
    esac
done
