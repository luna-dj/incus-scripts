#!/usr/bin/env bash
# install/heisenbridge-install.sh — Heisenbridge (IRC)
# Matrix bridge to IRC. Auth: bot is puppeted — use 'heisenbridge - <server>' command from Matrix client.
#
# Required env (set on host or in /etc/matrix-bridges.env):
#   HS_URL      e.g. https://matrix.femdev.nl
#   HS_DOMAIN   e.g. femdev.nl
# Optional:
#   BRIDGE_VERSION  default: latest from github

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/incus-install-compat.func?v=$(date +%s))"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/bridges/bridge-common.sh?v=$(date +%s))"

header_info "Heisenbridge (IRC)"
setting_up_container
network_check
update_os

# Resolve homeserver (set on host by ct script, or hardcoded default)
: "${HS_URL:=http://synapse:8008}"
: "${HS_DOMAIN:=localhost}"
if [[ "${HS_URL}" == "http://synapse:8008" ]]; then
    msg_warn "HS_URL not set — using ${HS_URL}. After deploy, edit /etc/heisenbridge/config.yaml"
fi

# Bridge-specific config
export BRIDGE_NAME="heisenbridge"
export BRIDGE_DISPLAY="Heisenbridge (IRC)"
export BRIDGE_BIN="/usr/local/bin/heisenbridge"
export BRIDGE_CONFIG="/etc/heisenbridge/config.yaml"
export BRIDGE_REGISTRATION="/etc/heisenbridge/registration.yaml"
export BRIDGE_DATA_DIR="/var/lib/heisenbridge"
export BRIDGE_USER="heisenbridge"
export APPSERVICE_NS="heisenbridge"

msg_info "Installing Heisenbridge (IRC bouncer-style bridge)"
apt-get install -y -qq python3-pip python3-venv >/dev/null
python3 -m venv /opt/heisenbridge
/opt/heisenbridge/bin/pip install --quiet --upgrade heisenbridge
ln -sf /opt/heisenbridge/bin/heisenbridge /usr/local/bin/heisenbridge

bridge_create_user_and_dirs
bridge_generate_registration

bridge_install_systemd_unit

msg_ok "Heisenbridge (IRC) installed (not started — wire to synapse first)"
bridge_install_done_message
