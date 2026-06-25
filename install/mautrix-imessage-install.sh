#!/usr/bin/env bash
# install/mautrix-imessage-install.sh — mautrix-imessage (macOS only)
# Matrix bridge to iMessage. Auth: Apple ID + 2FA. REQUIRES macOS host (won't work on incus).
#
# Required env (set on host or in /etc/matrix-bridges.env):
#   HS_URL      e.g. https://matrix.femdev.nl
#   HS_DOMAIN   e.g. femdev.nl
# Optional:
#   BRIDGE_VERSION  default: latest from github

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/incus-install-compat.func?v=$(date +%s))"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/bridges/bridge-common.sh?v=$(date +%s))"

header_info "mautrix-imessage (macOS only)"
setting_up_container
network_check
update_os

# Resolve homeserver (set on host by ct script, or hardcoded default)
: "${HS_URL:=http://synapse:8008}"
: "${HS_DOMAIN:=localhost}"
if [[ "${HS_URL}" == "http://synapse:8008" ]]; then
    msg_warn "HS_URL not set — using ${HS_URL}. After deploy, edit /etc/mautrix-imessage/config.yaml"
fi

# Bridge-specific config
export BRIDGE_NAME="mautrix-imessage"
export BRIDGE_DISPLAY="mautrix-imessage (macOS only)"
export BRIDGE_BIN="/usr/local/bin/mautrix-imessage"
export BRIDGE_CONFIG="/etc/mautrix-imessage/config.yaml"
export BRIDGE_REGISTRATION="/etc/mautrix-imessage/registration.yaml"
export BRIDGE_DATA_DIR="/var/lib/mautrix-imessage"
export BRIDGE_USER="mautrix-imessage"
export APPSERVICE_NS="imessage"

msg_warn "mautrix-imessage requires a macOS host (uses private CoreFoundation APIs)"
msg_warn "This container can't run it — deploy on a Mac with 'brew install mautrix-imessage'"
msg_info "Generating config files anyway so you can copy them to your Mac"
apt-get install -y -qq ca-certificates >/dev/null

bridge_create_user_and_dirs
bridge_generate_registration

bridge_install_systemd_unit

msg_ok "mautrix-imessage (macOS only) installed (not started — wire to synapse first)"
bridge_install_done_message
