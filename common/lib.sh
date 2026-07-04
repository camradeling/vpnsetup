#!/usr/bin/env bash
# Shared utilities sourced by all protocol scripts.

require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        log_err "Run as root: sudo $0"
        exit 1
    fi
}

log_info() { echo "[*] $*"; }
log_err()  { echo "[!] $*" >&2; }

check_package() {
    local name="$1"
    apt-cache show "$name" >/dev/null 2>&1 || return 1
    dpkg -s "$name" >/dev/null 2>&1 && return 0 || return 1
}

install_package() {
    local name="$1"
    if check_package "$name"; then
        log_info "$name already installed"
    else
        log_info "Installing $name..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$name"
    fi
}

install_packages() {
    apt-get update -qq
    for pkg in "$@"; do
        install_package "$pkg"
    done
}

# Converts dotted-quad netmask to CIDR prefix length.
# Usage: netmask_to_cidr 255.255.255.0  →  24
netmask_to_cidr() {
    local mask="$1"
    local bits=0
    local IFS='.'
    read -ra octets <<< "$mask"
    for octet in "${octets[@]}"; do
        local bin
        bin=$(python3 -c "print(bin($octet).count('1'))" 2>/dev/null) || \
            bin=$(echo "obase=2; $octet" | bc | tr -cd '1' | wc -c | tr -d ' ')
        bits=$((bits + bin))
    done
    echo "$bits"
}

# Renders a template file by substituting __VAR__ placeholders
# with matching environment variables via envsubst.
# Usage: render_template src.tpl dst [chmod_mode]
render_template() {
    local src="$1" dst="$2" mode="${3:-644}"
    if [[ ! -f "$src" ]]; then
        log_err "Template not found: $src"
        return 1
    fi
    if ! command -v envsubst >/dev/null 2>&1; then
        log_err "envsubst not found. Install with: apt-get install -y gettext-base"
        return 1
    fi
    # __VAR__ → ${VAR}, then substitute from current environment
    sed 's/__\([A-Z0-9_]*\)__/${\1}/g' "$src" | envsubst > "$dst"
    chmod "$mode" "$dst"
}

# Source config.env from the repo root (two levels up from protocol/server/).
load_config() {
    local config="${REPO_ROOT}/config.env"
    if [[ ! -f "$config" ]]; then
        log_err "config.env not found. Run: ./configure.sh"
        exit 1
    fi
    # shellcheck disable=SC1090
    source "$config"
}
