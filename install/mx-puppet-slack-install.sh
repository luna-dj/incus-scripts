#!/usr/bin/env bash
# install/mx-puppet-slack-install.sh — mx-puppet-slack (alt)
# Matrix bridge to Slack (alt bridge). Auth: Slack user OAuth token.
#
# Required env (set on host or in /etc/matrix-bridges.env):
#   HS_URL      e.g. https://matrix.femdev.nl
#   HS_DOMAIN   e.g. femdev.nl
# Optional:
#   BRIDGE_VERSION  default: latest from github

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/incus-install-compat.func?v=$(date +%s))"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/bridges/bridge-common.sh?v=$(date +%s))"

header_info "mx-puppet-slack (alt)"
setting_up_container
network_check
update_os

# Resolve homeserver (set on host by ct script, or hardcoded default)
: "${HS_URL:=http://synapse:8008}"
: "${HS_DOMAIN:=localhost}"
if [[ "${HS_URL}" == "http://synapse:8008" ]]; then
    msg_warn "HS_URL not set — using ${HS_URL}. After deploy, edit /etc/mx-puppet-slack/config.yaml"
fi

# Bridge-specific config
export BRIDGE_NAME="mx-puppet-slack"
export BRIDGE_DISPLAY="mx-puppet-slack (alt)"
export BRIDGE_BIN="/usr/local/bin/mx-puppet-slack"
export BRIDGE_CONFIG="/etc/mx-puppet-slack/config.yaml"
export BRIDGE_REGISTRATION="/etc/mx-puppet-slack/registration.yaml"
export BRIDGE_DATA_DIR="/var/lib/mx-puppet-slack"
export BRIDGE_USER="mx-puppet-slack"
export APPSERVICE_NS="slack"

msg_info "Installing mx-puppet-slack (alternative Slack bridge)"
            apt-get install -y -qq ca-certificates nodejs npm >/dev/null
            git clone https://github.com/matrix-org/mx-puppet-slack.git /opt/mx-puppet-slack
            cd /opt/mx-puppet-slack
            npm install --silent --omit=dev
            cat > /usr/local/bin/mx-puppet-slack <<'WRAP'
#!/usr/bin/env node
require('/opt/mx-puppet-slack/build/index.js');
WRAP
            chmod +x /usr/local/bin/mx-puppet-slack

bridge_create_user_and_dirs
bridge_generate_registration

bridge_install_systemd_unit

msg_ok "mx-puppet-slack (alt) installed (not started — wire to synapse first)"
bridge_install_done_message
