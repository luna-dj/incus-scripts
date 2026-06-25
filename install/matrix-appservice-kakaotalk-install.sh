#!/usr/bin/env bash
# install/matrix-appservice-kakaotalk-install.sh — matrix-appservice-kakaotalk
# Matrix bridge to KakaoTalk. Auth: KakaoTalk login (KR region required).
#
# Required env (set on host or in /etc/matrix-bridges.env):
#   HS_URL      e.g. https://matrix.femdev.nl
#   HS_DOMAIN   e.g. femdev.nl
# Optional:
#   BRIDGE_VERSION  default: latest from github

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/incus-install-compat.func?v=$(date +%s))"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/bridges/bridge-common.sh?v=$(date +%s))"

header_info "matrix-appservice-kakaotalk"
setting_up_container
network_check
update_os

# Resolve homeserver (set on host by ct script, or hardcoded default)
: "${HS_URL:=http://synapse:8008}"
: "${HS_DOMAIN:=localhost}"
if [[ "${HS_URL}" == "http://synapse:8008" ]]; then
    msg_warn "HS_URL not set — using ${HS_URL}. After deploy, edit /etc/matrix-appservice-kakaotalk/config.yaml"
fi

# Bridge-specific config
export BRIDGE_NAME="matrix-appservice-kakaotalk"
export BRIDGE_DISPLAY="matrix-appservice-kakaotalk"
export BRIDGE_BIN="/usr/local/bin/matrix-appservice-kakaotalk"
export BRIDGE_CONFIG="/etc/matrix-appservice-kakaotalk/config.yaml"
export BRIDGE_REGISTRATION="/etc/matrix-appservice-kakaotalk/registration.yaml"
export BRIDGE_DATA_DIR="/var/lib/matrix-appservice-kakaotalk"
export BRIDGE_USER="matrix-appservice-kakaotalk"
export APPSERVICE_NS="kakaotalk"

msg_info "Installing matrix-appservice-kakaotalk"
            apt-get install -y -qq ca-certificates nodejs npm >/dev/null
            git clone https://github.com/blueimp/matrix-appservice-kakaotalk.git /opt/matrix-appservice-kakaotalk
            cd /opt/matrix-appservice-kakaotalk
            npm install --silent --omit=dev
            cat > /usr/local/bin/matrix-appservice-kakaotalk <<'WRAP'
#!/usr/bin/env node
require('/opt/matrix-appservice-kakaotalk/build/index.js');
WRAP
            chmod +x /usr/local/bin/matrix-appservice-kakaotalk

bridge_create_user_and_dirs
bridge_generate_registration

bridge_install_systemd_unit

msg_ok "matrix-appservice-kakaotalk installed (not started — wire to synapse first)"
bridge_install_done_message
