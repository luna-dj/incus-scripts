#!/usr/bin/env bash
# ct/sqlserver2025.sh — Sqlserver2025
# Generated for Incus from ProxmoxVE Community Scripts
# License: MIT

source /dev/stdin <<<"$(curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/common.sh)"
source /dev/stdin <<<"$(curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/misc/incus-build.func)"

APP="Sqlserver2025"
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
INSTALL_SCRIPT=$(curl -fsSL "https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/install/sqlserver2025-install.sh" 2>/dev/null) || {
    log_error "Failed to fetch install script for sqlserver2025"
    exit 1
}
printf '%s\n' "$INSTALL_SCRIPT" | incus_exec_stdin "$var_instance"

IP=$(get_instance_ip "$var_instance")
echo ""
echo -e "${GR}Sqlserver2025 deployed on ${var_instance} (${IP})${NC}"
echo ""
