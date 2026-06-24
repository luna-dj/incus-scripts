#!/usr/bin/env bash
# ct/git-pages.sh — git-pages static site server
# Generated for Incus
# Our wrapper code is MIT; upstream content retains its original license.
#
# Set INCUS_BASE to override the raw content provider:
#   INCUS_BASE=https://raw.githubusercontent.com/luna-dj/incus-scripts/main
#
# Set GIT_PAGES_WITH_CADDY=no to skip Caddy reverse proxy (default: yes)
# Set GIT_PAGES_DOMAIN=example.com to configure the Caddy vhost

INCUS_BASE="${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}"
export INCUS_BASE
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE}/common.sh?v=$(date +%s))"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE}/misc/incus-build.func?v=$(date +%s))"

APP="Git-Pages"
var_tags="${var_tags:-static-site,git-pages,caddy}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-10}"
var_os="${var_os:-ubuntu}"
var_version="${var_version:-24.04}"

header_info "$APP"
variables
check_existing_instance
create_instance

INSTALL_SCRIPT=$(curl -fsSL --http1.1 "${INCUS_BASE}/install/git-pages-install.sh?v=$(date +%s)" 2>/dev/null) || {
    log_error "Failed to fetch install script for git-pages"
    exit 1
}
printf '%s\n' "INCUS_BASE=${INCUS_BASE}" \
              "GIT_PAGES_WITH_CADDY=${GIT_PAGES_WITH_CADDY:-yes}" \
              "GIT_PAGES_DOMAIN=${GIT_PAGES_DOMAIN:-}" \
              "$INSTALL_SCRIPT" | incus_exec_stdin "$var_instance"

IP=$(get_instance_ip "$var_instance")
echo ""
echo -e "${GR}Git-Pages deployed on ${var_instance} (${IP})${NC}"
echo ""
echo -e "${BL}git-pages API:    http://${IP}:3000${NC}"
if [[ "${GIT_PAGES_WITH_CADDY:-yes}" != "no" ]]; then
    echo -e "${BL}Web (HTTP):      http://${IP}${NC}"
    if [[ -n "${GIT_PAGES_DOMAIN:-}" ]]; then
        echo -e "${BL}Web (HTTPS):     https://${GIT_PAGES_DOMAIN}${NC}"
    fi
fi
echo ""
echo -e "${YL}Publish a site:${NC}"
echo "  curl http://${IP}:3000/ -X PUT --data-binary @site.tar.gz"
echo "  curl http://${IP}:3000/ -X PUT --data https://github.com/user/repo.git"
echo ""
