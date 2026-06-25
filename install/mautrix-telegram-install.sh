#!/usr/bin/env bash
# install/mautrix-telegram-install.sh — mautrix-telegram
# Matrix bridge to Telegram. Auth: log in via QR/phone (interactive at first start).
#
# Required env (set on host or in /etc/matrix-bridges.env):
#   HS_URL      e.g. https://matrix.femdev.nl
#   HS_DOMAIN   e.g. femdev.nl
# Optional:
#   BRIDGE_VERSION  default: latest from github

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/incus-install-compat.func?v=$(date +%s))"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/bridges/bridge-common.sh?v=$(date +%s))"

header_info "mautrix-telegram"
setting_up_container
network_check
update_os

# Resolve homeserver (set on host by ct script, or hardcoded default)
: "${HS_URL:=http://synapse:8008}"
: "${HS_DOMAIN:=localhost}"
if [[ "${HS_URL}" == "http://synapse:8008" ]]; then
    msg_warn "HS_URL not set — using ${HS_URL}. After deploy, edit /etc/mautrix-telegram/config.yaml"
fi

# Bridge-specific config
export BRIDGE_NAME="mautrix-telegram"
export BRIDGE_DISPLAY="mautrix-telegram"
export BRIDGE_BIN="/usr/local/bin/mautrix-telegram"
export BRIDGE_CONFIG="/etc/mautrix-telegram/config.yaml"
export BRIDGE_REGISTRATION="/etc/mautrix-telegram/registration.yaml"
export BRIDGE_DATA_DIR="/var/lib/mautrix-telegram"
export BRIDGE_USER="mautrix-telegram"
export APPSERVICE_NS="telegram"

msg_info "Installing mautrix-telegram (Telegram bridge)"
apt-get install -y -qq ca-certificates >/dev/null
fetch_and_deploy_gh_release "mautrix-telegram" \
    "mautrix/telegramgo" \
    binary \
    "${{BRIDGE_VERSION:-latest}}" \
    /opt/mautrix-telegram \
    "*linux-amd64*"
ln -sf /opt/mautrix-telegram/mautrix-telegram /usr/local/bin/mautrix-telegram

bridge_create_user_and_dirs
bridge_generate_registration

bridge_install_systemd_unit

msg_ok "mautrix-telegram installed (not started — wire to synapse first)"
bridge_install_done_message
