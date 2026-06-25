#!/usr/bin/env bash
# install/matrix-appservice-email-install.sh — matrix-appservice-email
# Matrix bridge to Email (IMAP/SMTP). Auth: IMAP/SMTP credentials + Matrix admin token.
#
# Required env (set on host or in /etc/matrix-bridges.env):
#   HS_URL      e.g. https://matrix.femdev.nl
#   HS_DOMAIN   e.g. femdev.nl
# Optional:
#   BRIDGE_VERSION  default: latest from github

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/incus-install-compat.func?v=$(date +%s))"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/bridges/bridge-common.sh?v=$(date +%s))"

header_info "matrix-appservice-email"
setting_up_container
network_check
update_os

# Resolve homeserver (set on host by ct script, or hardcoded default)
: "${HS_URL:=http://synapse:8008}"
: "${HS_DOMAIN:=localhost}"
if [[ "${HS_URL}" == "http://synapse:8008" ]]; then
    msg_warn "HS_URL not set — using ${HS_URL}. After deploy, edit /etc/matrix-appservice-email/config.yaml"
fi

# Bridge-specific config
export BRIDGE_NAME="matrix-appservice-email"
export BRIDGE_DISPLAY="matrix-appservice-email"
export BRIDGE_BIN="/usr/local/bin/matrix-appservice-email"
export BRIDGE_CONFIG="/etc/matrix-appservice-email/config.yaml"
export BRIDGE_REGISTRATION="/etc/matrix-appservice-email/registration.yaml"
export BRIDGE_DATA_DIR="/var/lib/matrix-appservice-email"
export BRIDGE_USER="matrix-appservice-email"
export APPSERVICE_NS="email"

msg_info "Installing matrix-appservice-email"
apt-get install -y -qq ca-certificates nodejs npm >/dev/null
fetch_and_deploy_gh_release "matrix-appservice-email" \
    "matrix-org/matrix-appservice-email" \
    prebuild \
    "${{BRIDGE_VERSION:-latest}}" \
    /opt/matrix-appservice-email \
    "*.tar.gz"
ln -sf /opt/matrix-appservice-email/matrix-appservice-email /usr/local/bin/matrix-appservice-email

bridge_create_user_and_dirs
bridge_generate_registration

bridge_install_systemd_unit

msg_ok "matrix-appservice-email installed (not started — wire to synapse first)"
bridge_install_done_message
