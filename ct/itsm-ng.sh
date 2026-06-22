#!/usr/bin/env bash
# ct/itsm-ng.sh — Itsm Ng
# Generated for Incus from upstream ProxmoxVE Community Scripts
# Our wrapper code is MIT; upstream content retains its original license.
#
# Set INCUS_BASE to override the raw content provider:
#   INCUS_BASE=https://raw.githubusercontent.com/luna-dj/incus-scripts/main

INCUS_BASE="${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}"
# Export so it survives subshells (pipes, incus_exec_stdin)
export INCUS_BASE
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE}/common.sh)"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE}/misc/incus-build.func)"

APP="Itsm Ng"
var_tags="${var_tags:-}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-10}"
var_os="${var_os:-ubuntu}"
var_version="${var_version:-24.04}"

header_info "$APP"
variables
check_existing_instance
create_instance

# Fetch the install script content on the host, then push it into the
# container and run it with 'bash -s' (which reads the script from stdin).
# We can't use 'bash -c' here because the upstream install scripts start
# with '#!/usr/bin/env bash' which would be treated as a command name.
INSTALL_SCRIPT=$(curl -fsSL --http1.1 "${INCUS_BASE}/install/itsm-ng-install.sh" 2>/dev/null) || {
    log_error "Failed to fetch install script for itsm-ng"
    exit 1
}
printf '%s\n' "$INSTALL_SCRIPT" | incus_exec_stdin "$var_instance"

IP=$(get_instance_ip "$var_instance")
echo ""
echo -e "${GR}Itsm Ng deployed on ${var_instance} (${IP})${NC}"
echo ""
