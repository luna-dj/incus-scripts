#!/usr/bin/env bash
# ct/nextcloud.sh — Nextcloud file sync
# Copyright (c) 2026 incus-helper-scripts
# License: MIT

source /dev/stdin <<<"$(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/common.sh)"
source /dev/stdin <<<"$(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/misc/incus-build.func)"

APP="Nextcloud"
var_tags="${var_tags:-cloud,file-sync,collaboration}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-20}"
var_os="${var_os:-ubuntu}"
var_version="${var_version:-24.04}"

header_info "$APP"
variables
check_existing_instance
create_instance

INSTALL_URL="https://raw.githubusercontent.com/luna-dj/incus-scripts/main/install/nextcloud-install.sh"
incus_exec "$var_instance" -- bash -c "$(curl -fsSL "$INSTALL_URL")"

IP=$(get_instance_ip "$var_instance")
echo ""
echo -e "${GR}Nextcloud: http://${IP}${NC}"
