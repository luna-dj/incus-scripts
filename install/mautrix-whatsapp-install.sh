#!/usr/bin/env bash
# install/mautrix-whatsapp-install.sh — mautrix-whatsapp
# Matrix bridge to WhatsApp. Auth: scan QR with WhatsApp mobile app (Linked Devices → Multi-device).
#
# Required env (set on host or in /etc/matrix-bridges.env):
#   HS_URL      e.g. https://matrix.femdev.nl
#   HS_DOMAIN   e.g. femdev.nl
# Optional:
#   BRIDGE_VERSION  default: latest from github

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/incus-install-compat.func?v=$(date +%s))"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/bridges/bridge-common.sh?v=$(date +%s))"

header_info "mautrix-whatsapp"
setting_up_container
network_check
update_os

# Resolve homeserver (set on host by ct script, or hardcoded default)
: "${HS_URL:=http://synapse:8008}"
: "${HS_DOMAIN:=localhost}"
if [[ "${HS_URL}" == "http://synapse:8008" ]]; then
    msg_warn "HS_URL not set — using ${HS_URL}. After deploy, edit /etc/mautrix-whatsapp/config.yaml"
fi

# Bridge-specific config
export BRIDGE_NAME="mautrix-whatsapp"
export BRIDGE_DISPLAY="mautrix-whatsapp"
export BRIDGE_BIN="/usr/local/bin/mautrix-whatsapp"
export BRIDGE_CONFIG="/etc/mautrix-whatsapp/config.yaml"
export BRIDGE_REGISTRATION="/etc/mautrix-whatsapp/registration.yaml"
export BRIDGE_DATA_DIR="/var/lib/mautrix-whatsapp"
export BRIDGE_USER="mautrix-whatsapp"
export APPSERVICE_NS="whatsapp"

msg_info "Installing mautrix-whatsapp (WhatsApp bridge)"
apt-get install -y -qq ca-certificates >/dev/null
# WhatsApp bridge needs specific mautrix/go build pattern.
# Latest tag from git ls-remote to avoid API rate limits.
fetch_and_deploy_gh_release "mautrix-whatsapp" \
    "mautrix/whatsapp" \
    prebuild \
    "${{BRIDGE_VERSION:-latest}}" \
    /opt/mautrix-whatsapp \
    "*multi-device-linux-amd64*"
ln -sf /opt/mautrix-whatsapp/mautrix-whatsapp /usr/local/bin/mautrix-whatsapp

bridge_create_user_and_dirs
bridge_generate_registration

bridge_install_systemd_unit

msg_ok "mautrix-whatsapp installed (not started — wire to synapse first)"
bridge_install_done_message
