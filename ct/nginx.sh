#!/usr/bin/env bash
# ct/nginx.sh — Nginx reverse proxy
# Copyright (c) 2026 incus-helper-scripts
# License: MIT

source /dev/stdin <<<"$(curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/common.sh)"
source /dev/stdin <<<"$(curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/misc/incus-build.func)"

APP="Nginx"
var_tags="${var_tags:-proxy,web}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-4}"
var_os="${var_os:-ubuntu}"
var_version="${var_version:-24.04}"

header_info "$APP"
variables
check_existing_instance
create_instance

log_info "Pushing install script..."
INSTALL_URL="https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/install/nginx-install.sh"
incus_exec "$var_instance" -- bash -c "$(curl -fsSL "$INSTALL_URL")"

IP=$(get_instance_ip "$var_instance")
print_completion "$APP" "$IP" "80" "Default page at http://${IP}"
