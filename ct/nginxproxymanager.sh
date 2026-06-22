#!/usr/bin/env bash
# ct/nginxproxymanager.sh — Nginxproxymanager
# Generated for Incus from ProxmoxVE Community Scripts
# License: MIT

source /dev/stdin <<<"$(curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/common.sh)"
source /dev/stdin <<<"$(curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/misc/incus-build.func)"

APP="Nginxproxymanager"
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

# Fetch the install script on the host, then push it to the container
# and run it via stdin. We use 'bash -s' (not 'bash -c') because
# upstream scripts start with '#!/usr/bin/env bash' which gets parsed
# as a command name when passed via -c.
INSTALL_SCRIPT=$(curl -fsSL "https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/install/nginxproxymanager-install.sh" 2>/dev/null) || {
    log_error "Failed to fetch install script for nginxproxymanager"
    exit 1
}
printf '%s\n' "$INSTALL_SCRIPT" | incus_exec_stdin "$var_instance"

IP=$(get_instance_ip "$var_instance")
echo ""
echo -e "${GR}Nginxproxymanager deployed on ${var_instance} (${IP})${NC}"
echo ""
