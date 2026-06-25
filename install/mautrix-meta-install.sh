#!/usr/bin/env bash
# install/mautrix-meta-install.sh — mautrix-meta (Messenger + Instagram)
# Matrix bridge to Messenger/Instagram. Auth: Facebook/Instagram cookies (browser DevTools).
#
# Required env (set on host or in /etc/matrix-bridges.env):
#   HS_URL      e.g. https://matrix.femdev.nl
#   HS_DOMAIN   e.g. femdev.nl
# Optional:
#   BRIDGE_VERSION  default: latest from github

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/incus-install-compat.func?v=$(date +%s))"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/bridges/bridge-common.sh?v=$(date +%s))"

header_info "mautrix-meta (Messenger + Instagram)"
setting_up_container
network_check
update_os

# Resolve homeserver (set on host by ct script, or hardcoded default)
: "${HS_URL:=http://synapse:8008}"
: "${HS_DOMAIN:=localhost}"
if [[ "${HS_URL}" == "http://synapse:8008" ]]; then
    msg_warn "HS_URL not set — using ${HS_URL}. After deploy, edit /etc/mautrix-meta/config.yaml"
fi

# Bridge-specific config
export BRIDGE_NAME="mautrix-meta"
export BRIDGE_DISPLAY="mautrix-meta (Messenger + Instagram)"
export BRIDGE_BIN="/usr/local/bin/mautrix-meta"
export BRIDGE_CONFIG="/etc/mautrix-meta/config.yaml"
export BRIDGE_REGISTRATION="/etc/mautrix-meta/registration.yaml"
export BRIDGE_DATA_DIR="/var/lib/mautrix-meta"
export BRIDGE_USER="mautrix-meta"
export APPSERVICE_NS="meta"

msg_info "Installing mautrix-meta (Messenger + Instagram bridge)"
apt-get install -y -qq ca-certificates >/dev/null
fetch_and_deploy_gh_release "mautrix-meta" \
    "mautrix/meta" \
    binary \
    "${{BRIDGE_VERSION:-latest}}" \
    /opt/mautrix-meta \
    "*linux-amd64*"
ln -sf /opt/mautrix-meta/mautrix-meta /usr/local/bin/mautrix-meta

bridge_create_user_and_dirs
bridge_generate_registration

bridge_install_systemd_unit

msg_ok "mautrix-meta (Messenger + Instagram) installed (not started — wire to synapse first)"
bridge_install_done_message
