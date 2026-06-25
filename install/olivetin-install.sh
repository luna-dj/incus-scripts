#!/usr/bin/env bash
# install/olivetin-install.sh — OliveTin (addon)
# Generated for Incus from upstream ProxmoxVE Community Scripts (tools/addon/)
# Our wrapper code is MIT; upstream content retains its original license.
#
# Addon scripts require Docker inside the container. Incus containers
# don't ship with Docker, so we install it before eval'ing the upstream.

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/incus-install-compat.func?v=$(date +%s))"

header_info "OliveTin"
setting_up_container
network_check
update_os

# Addon apps run as Docker containers. Install Docker first.
# Use setup_docker from compat shim (handles Debian/Ubuntu/Alpine).
if ! command -v docker &>/dev/null; then
  msg_info "Installing Docker (required for OliveTin addon)"
  setup_docker
  msg_ok "Docker installed"
fi

# Ensure TERM is set so upstream's `header_info` `clear` command works.
# Inside `incus exec ... bash -s` there is no TTY, so TERM is unset.
# Without TERM, `clear` errors and trips the upstream ERR trap.
TERM="${TERM:-xterm-256color}"
export TERM

# Ensure TERM is set so upstream header_info clear command works.
# Inside incus exec bash -s there is no TTY; TERM may be dumb or unset.
# dumb does not know clear, so unconditionally force a real terminal type.
TERM="xterm-256color"
export TERM
shopt -s expand_aliases
alias clear=true

msg_info "Loading upstream addon script for OliveTin"
UPSTREAM_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/olivetin.sh"
UPSTREAM_SCRIPT=$(curl -fsSL "${UPSTREAM_URL}?v=$(date +%s)" 2>/dev/null) || {
    msg_error "Failed to fetch upstream addon script"
    exit 1
}

# Remove upstream function sourcing (provided by incus-compat)
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/core.func)/: # (core.func)}"
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/tools.func)/: # (tools.func)}"
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/error_handler.func)/: # (error_handler.func)}"

# Auto-answer upstream interactive prompts. Addon scripts run inside
# `incus exec ... bash -s` so there is no TTY for `read -r`. Without this
# every prompt receives empty input and the addon exits with "Installation
# cancelled". Force-yes for install/uninstall, force-no for update (we're
# doing a fresh install, not an update).
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//read -r install_prompt/install_prompt=y}"
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//read -r install_docker_prompt/install_docker_prompt=y}"
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//read -r update_prompt/update_prompt=n}"
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//read -r uninstall_prompt/uninstall_prompt=n}"

# Disable 'set -u' around eval of upstream
set +u
eval "$UPSTREAM_SCRIPT"
set -u

echo ""
echo -e "${GR}OliveTin installation complete!${NC}"
echo ""
