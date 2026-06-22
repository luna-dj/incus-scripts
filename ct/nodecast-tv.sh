#!/usr/bin/env bash
# ct/nodecast-tv.sh — Nodecast Tv
# Generated for Incus from ProxmoxVE Community Scripts
# License: MIT

source /dev/stdin <<<"$(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/common.sh)"
source /dev/stdin <<<"$(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/misc/incus-build.func)"

APP="Nodecast Tv"
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

RUN_SCRIPT=$(cat <<'SCRIPT'
$(curl -fsSL "https://raw.githubusercontent.com/luna-dj/incus-scripts/main/common.sh")
$(curl -fsSL "https://raw.githubusercontent.com/luna-dj/incus-scripts/main/misc/incus-compat.func")
$(curl -fsSL "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/nodecast-tv-install.sh")
SCRIPT
)
incus_exec "$var_instance" -- bash -c "$RUN_SCRIPT"

IP=$(get_instance_ip "$var_instance")
echo ""
echo -e "${GR}Nodecast Tv deployed on ${var_instance} (${IP})${NC}"
echo ""
