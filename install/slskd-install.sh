#!/usr/bin/env bash
# install/slskd-install.sh — Slskd
# Generated for Incus from ProxmoxVE Community Scripts
# License: MIT

source /dev/stdin <<<"$(curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/common.sh)"
source /dev/stdin <<<"$(curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/misc/incus-compat.func)"

header_info "Slskd"
setting_up_container
network_check
update_os

msg_info "Loading upstream install script for Slskd"
UPSTREAM_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/slskd-install.sh"
UPSTREAM_SCRIPT=$(curl -fsSL "$UPSTREAM_URL" 2>/dev/null) || {
    msg_error "Failed to fetch upstream install script"
    exit 1
}

# Remove upstream function sourcing (provided by incus-compat)
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source \/dev\/stdin <<<\"\$FUNCTIONS_FILE_PATH\"/: # (functions provided by incus-compat)}"
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source <(curl -fsSL https:\/\/codeberg.org\/community-scripts\/ProxmoxVE\/main\/misc\/core.func)/: # (core.func)}"
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source <(curl -fsSL https:\/\/codeberg.org\/community-scripts\/ProxmoxVE\/main\/misc\/error_handler.func)/: # (error_handler.func)}"

eval "$UPSTREAM_SCRIPT"

echo ""
echo -e "${GR}Slskd installation complete!${NC}"
echo ""
