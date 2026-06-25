#!/usr/bin/env bash
# install/bifrost-install.sh — Bifrost (XMPP/Jabber)
# Matrix bridge to XMPP/Jabber. Auth: XMPP account credentials (username + password).
#
# Required env (set on host or in /etc/matrix-bridges.env):
#   HS_URL      e.g. https://matrix.femdev.nl
#   HS_DOMAIN   e.g. femdev.nl
# Optional:
#   BRIDGE_VERSION  default: latest from github

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/incus-install-compat.func?v=$(date +%s))"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/bridges/bridge-common.sh?v=$(date +%s))"

header_info "Bifrost (XMPP/Jabber)"
setting_up_container
network_check
update_os

# Resolve homeserver (set on host by ct script, or hardcoded default)
: "${HS_URL:=http://synapse:8008}"
: "${HS_DOMAIN:=localhost}"
if [[ "${HS_URL}" == "http://synapse:8008" ]]; then
    msg_warn "HS_URL not set — using ${HS_URL}. After deploy, edit /etc/bifrost/config.yaml"
fi

# Bridge-specific config
export BRIDGE_NAME="bifrost"
export BRIDGE_DISPLAY="Bifrost (XMPP/Jabber)"
export BRIDGE_BIN="/usr/local/bin/bifrost"
export BRIDGE_CONFIG="/etc/bifrost/config.yaml"
export BRIDGE_REGISTRATION="/etc/bifrost/registration.yaml"
export BRIDGE_DATA_DIR="/var/lib/bifrost"
export BRIDGE_USER="bifrost"
export APPSERVICE_NS="bifrost"

msg_info "Installing Bifrost (XMPP gateway)"
apt-get install -y -qq ca-certificates >/dev/null
fetch_and_deploy_gh_release "bifrost" \
    "matrix-org/bifrost" \
    binary \
    "${{BRIDGE_VERSION:-latest}}" \
    /opt/bifrost \
    "*linux-amd64*"
ln -sf /opt/bifrost/bifrost /usr/local/bin/bifrost

bridge_create_user_and_dirs
bridge_generate_registration

bridge_install_systemd_unit

msg_ok "Bifrost (XMPP/Jabber) installed (not started — wire to synapse first)"
bridge_install_done_message
