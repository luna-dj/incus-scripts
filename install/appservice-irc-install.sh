#!/usr/bin/env bash
# install/appservice-irc-install.sh — matrix-appservice-irc
# Matrix bridge to IRC (legacy). Auth: bot connects to IRC server with configured nick.
#
# Required env (set on host or in /etc/matrix-bridges.env):
#   HS_URL      e.g. https://matrix.femdev.nl
#   HS_DOMAIN   e.g. femdev.nl
# Optional:
#   BRIDGE_VERSION  default: latest from github

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/incus-install-compat.func?v=$(date +%s))"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/bridges/bridge-common.sh?v=$(date +%s))"

header_info "matrix-appservice-irc"
setting_up_container
network_check
update_os

# Resolve homeserver (set on host by ct script, or hardcoded default)
: "${HS_URL:=http://synapse:8008}"
: "${HS_DOMAIN:=localhost}"
if [[ "${HS_URL}" == "http://synapse:8008" ]]; then
    msg_warn "HS_URL not set — using ${HS_URL}. After deploy, edit /etc/appservice-irc/config.yaml"
fi

# Bridge-specific config
export BRIDGE_NAME="appservice-irc"
export BRIDGE_DISPLAY="matrix-appservice-irc"
export BRIDGE_BIN="/usr/local/bin/matrix-appservice-irc"
export BRIDGE_CONFIG="/etc/appservice-irc/config.yaml"
export BRIDGE_REGISTRATION="/etc/appservice-irc/registration.yaml"
export BRIDGE_DATA_DIR="/var/lib/appservice-irc"
export BRIDGE_USER="appservice-irc"
export APPSERVICE_NS="irc"

msg_info "Installing matrix-appservice-irc (legacy IRC bridge)"
apt-get install -y -qq ca-certificates nodejs npm >/dev/null
fetch_and_deploy_gh_release "matrix-appservice-irc" \
    "matrix-org/matrix-appservice-irc" \
    prebuild \
    "${{BRIDGE_VERSION:-latest}}" \
    /opt/matrix-appservice-irc \
    "*.tar.gz"
ln -sf /opt/matrix-appservice-irc/matrix-appservice-irc /usr/local/bin/matrix-appservice-irc

bridge_create_user_and_dirs
bridge_generate_registration

bridge_install_systemd_unit

msg_ok "matrix-appservice-irc installed (not started — wire to synapse first)"
bridge_install_done_message
