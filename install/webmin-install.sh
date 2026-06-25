#!/usr/bin/env bash
# install/webmin-install.sh — Webmin (addon)
# Generated for Incus from upstream ProxmoxVE Community Scripts (tools/addon/)
# Our wrapper code is MIT; upstream content retains its original license.
#
# Addon scripts require Docker inside the container. Incus containers
# don't ship with Docker, so we install it before eval'ing the upstream.

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/incus-install-compat.func?v=$(date +%s))"

header_info "Webmin"
setting_up_container
network_check
update_os

# Addon apps run as Docker containers. Install Docker first.
# Use setup_docker from compat shim (handles Debian/Ubuntu/Alpine).
if ! command -v docker &>/dev/null; then
  msg_info "Installing Docker (required for Webmin addon)"
  setup_docker
  msg_ok "Docker installed"
fi

msg_info "Loading upstream addon script for Webmin"
UPSTREAM_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/webmin.sh"
UPSTREAM_SCRIPT=$(curl -fsSL "${UPSTREAM_URL}?v=$(date +%s)" 2>/dev/null) || {
    msg_error "Failed to fetch upstream addon script"
    exit 1
}

# Remove upstream function sourcing (provided by incus-compat)
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/core.func)/: # (core.func)}"
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/tools.func)/: # (tools.func)}"
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/error_handler.func)/: # (error_handler.func)}"

# Disable 'set -u' around eval of upstream
set +u
eval "$UPSTREAM_SCRIPT"
set -u

echo ""
echo -e "${GR}Webmin installation complete!${NC}"
echo ""
