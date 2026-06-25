#!/usr/bin/env bash
# ct/bifrost.sh — Bifrost (XMPP/Jabber)
# Matrix bridge to XMPP/Jabber.
# Our wrapper code is MIT; upstream content retains its original license.
#
# Set INCUS_BASE to override the raw content provider:
#   INCUS_BASE=https://raw.githubusercontent.com/luna-dj/incus-scripts/main
# Set HS_URL and HS_DOMAIN to wire the bridge to your homeserver at deploy time:
#   HS_URL=https://matrix.femdev.nl HS_DOMAIN=femdev.nl bash <(curl ... ct/bifrost.sh)

INCUS_BASE="${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}"
export INCUS_BASE
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE}/common.sh?v=$(date +%s))"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE}/misc/incus-build.func?v=$(date +%s))"

APP="Bifrost (XMPP/Jabber)"
var_tags="${var_tags:-matrix;bridge;xmpp}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-4}"
var_os="${var_os:-ubuntu}"
var_version="${var_version:-24.04}"

header_info "$APP"
variables
check_existing_instance
create_instance

INSTALL_SCRIPT=$(curl -fsSL --http1.1 "${INCUS_BASE}/install/bifrost-install.sh" 2>/dev/null) || {
    log_error "Failed to fetch install script for bifrost"
    exit 1
}

# Inject homeserver env vars (if set) so the in-container script knows
# where to register the appservice.
printf '%s\n' \
    "INCUS_BASE=${INCUS_BASE}" \
    "HS_URL=${HS_URL:-}" \
    "HS_DOMAIN=${HS_DOMAIN:-}" \
    "$INSTALL_SCRIPT" | incus_exec_stdin "$var_instance"

IP=$(get_instance_ip "$var_instance")
echo ""
echo -e "${GR}Bifrost (XMPP/Jabber) deployed on ${var_instance} (${IP})${NC}"
echo ""
