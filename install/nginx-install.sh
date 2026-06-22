#!/usr/bin/env bash
# install/nginx-install.sh — Nginx installation script (runs inside container)
# Copyright (c) 2026 incus-helper-scripts
# License: MIT

source /dev/stdin <<<"$(curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/common.sh)"
source /dev/stdin <<<"$(curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/misc/incus-install.func)"

header_info "Nginx"
setting_up_container
network_check
configure_apt

msg_info "Installing Nginx"
install_packages nginx
msg_ok "Nginx installed"

msg_info "Enabling and starting Nginx"
enable_service nginx
msg_ok "Nginx service started"

open_port 80
open_port 443

print_completion "Nginx" "$(hostname -I | awk '{print $1}')" "80" "Default page: http://$(hostname -I | awk '{print $1}')"
