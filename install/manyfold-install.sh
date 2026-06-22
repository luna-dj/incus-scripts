#!/usr/bin/env bash
# install/manyfold-install.sh — Manyfold
# Generated for Incus from upstream ProxmoxVE Community Scripts
# Our wrapper code is MIT; upstream content retains its original license.

source /dev/stdin <<<"$(curl -fsSL --http1.1 https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/misc/incus-install-compat.func)"

header_info "Manyfold"
setting_up_container
network_check
update_os

msg_info "Loading upstream install script for Manyfold"
UPSTREAM_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/manyfold-install.sh"
UPSTREAM_SCRIPT=$(curl -fsSL "$UPSTREAM_URL" 2>/dev/null) || {
    msg_error "Failed to fetch upstream install script"
    exit 1
}

# Remove upstream function sourcing (provided by incus-compat)
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source \/dev\/stdin <<<\"\$FUNCTIONS_FILE_PATH\"/: # (functions provided by incus-compat)}"
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/core.func)/: # (core.func)}"
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/error_handler.func)/: # (error_handler.func)}"

# Disable 'set -u' around eval of upstream: the upstream scripts
# use various bash features that may not be safe under strict
# unset-variable mode.
set +u
eval "$UPSTREAM_SCRIPT"
set -u

echo ""
echo -e "${GR}Manyfold installation complete!${NC}"
echo ""
