#!/usr/bin/env bash
# install/mautrix-signal-install.sh — mautrix-signal
# Matrix bridge to Signal. Auth: scan QR with Signal mobile app (Settings → Linked Devices).
#
# Required env (set on host or in /etc/matrix-bridges.env):
#   HS_URL      e.g. https://matrix.femdev.nl
#   HS_DOMAIN   e.g. femdev.nl
# Optional:
#   BRIDGE_VERSION  default: latest from github

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/incus-install-compat.func?v=$(date +%s))"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/bridges/bridge-common.sh?v=$(date +%s))"

header_info "mautrix-signal"
setting_up_container
network_check
update_os

# Resolve homeserver (set on host by ct script, or hardcoded default)
: "${HS_URL:=http://synapse:8008}"
: "${HS_DOMAIN:=localhost}"
if [[ "${HS_URL}" == "http://synapse:8008" ]]; then
    msg_warn "HS_URL not set — using ${HS_URL}. After deploy, edit /etc/mautrix-signal/config.yaml"
fi

# Bridge-specific config
export BRIDGE_NAME="mautrix-signal"
export BRIDGE_DISPLAY="mautrix-signal"
export BRIDGE_BIN="/usr/local/bin/mautrix-signal"
export BRIDGE_CONFIG="/etc/mautrix-signal/config.yaml"
export BRIDGE_REGISTRATION="/etc/mautrix-signal/registration.yaml"
export BRIDGE_DATA_DIR="/var/lib/mautrix-signal"
export BRIDGE_USER="mautrix-signal"
export APPSERVICE_NS="signal"

msg_info "Installing mautrix-signal (Signal bridge)"
apt-get install -y -qq ca-certificates >/dev/null
fetch_and_deploy_gh_release "mautrix-signal" \
    "mautrix/signal" \
    binary \
    "${{BRIDGE_VERSION:-latest}}" \
    /opt/mautrix-signal \
    "*linux-amd64*"
ln -sf /opt/mautrix-signal/mautrix-signal /usr/local/bin/mautrix-signal

bridge_create_user_and_dirs
bridge_generate_registration

bridge_install_systemd_unit

msg_ok "mautrix-signal installed (not started — wire to synapse first)"
bridge_install_done_message
