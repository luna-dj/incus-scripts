#!/usr/bin/env bash
# gen_all.sh — Generate all 504 app templates for Incus
# Reads app names from /tmp/ihs/apps.txt
# Produces ct/<app>.sh and install/<app>-install.sh

set -euo pipefail

APPS_FILE="/tmp/ihs/apps.txt"
CT_DIR="$(cd "$(dirname "$0")" && pwd)/ct"
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)/install"
COMMON_URL="https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/common.sh"
BUILD_FUNC_URL="https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/misc/incus-build.func"
COMPAT_FUNC_URL="https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/misc/incus-compat.func"
INSTALL_BASE_URL="https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/install"
UPSTREAM_BASE="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install"

mkdir -p "$CT_DIR" "$INSTALL_DIR"

slug_to_display() {
  echo "$1" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1'
}

count=0
while IFS= read -r app; do
  # Skip excludes
  case "$app" in
    alpine|ubuntu|debian|headers) continue ;;
    pve-scripts*) continue ;;
  esac

  display=$(slug_to_display "$app")

  # ── ct/<app>.sh ──────────────────────────
  cat > "${CT_DIR}/${app}.sh" <<CTEOF
#!/usr/bin/env bash
# ct/${app}.sh — ${display}
# Generated for Incus from ProxmoxVE Community Scripts
# License: MIT

source /dev/stdin <<<"\$(curl -fsSL ${COMMON_URL})"
source /dev/stdin <<<"\$(curl -fsSL ${BUILD_FUNC_URL})"

APP="${display}"
var_tags="\${var_tags:-}"
var_cpu="\${var_cpu:-1}"
var_ram="\${var_ram:-1024}"
var_disk="\${var_disk:-10}"
var_os="\${var_os:-ubuntu}"
var_version="\${var_version:-24.04}"

header_info "\$APP"
variables
check_existing_instance
create_instance

# Fetch the install script content on the host, then push it into the
# container and run it with 'bash -s' (which reads the script from stdin).
# We can't use 'bash -c' here because the upstream install scripts start
# with '#!/usr/bin/env bash' which would be treated as a command name.
INSTALL_SCRIPT=\$(curl -fsSL "${INSTALL_BASE_URL}/${app}-install.sh" 2>/dev/null) || {
    log_error "Failed to fetch install script for ${app}"
    exit 1
}
printf '%s\n' "\$INSTALL_SCRIPT" | incus_exec_stdin "\$var_instance"

IP=\$(get_instance_ip "\$var_instance")
echo ""
echo -e "\${GR}${display} deployed on \${var_instance} (\${IP})\${NC}"
echo ""
CTEOF

  # ── install/<app>-install.sh ─────────────
  cat > "${INSTALL_DIR}/${app}-install.sh" <<INSTEOF
#!/usr/bin/env bash
# install/${app}-install.sh — ${display}
# Generated for Incus from ProxmoxVE Community Scripts
# License: MIT

source /dev/stdin <<<"\$(curl -fsSL ${COMMON_URL})"
source /dev/stdin <<<"\$(curl -fsSL ${COMPAT_FUNC_URL})"

header_info "${display}"
setting_up_container
network_check
update_os

msg_info "Loading upstream install script for ${display}"
UPSTREAM_URL="${UPSTREAM_BASE}/${app}-install.sh"
UPSTREAM_SCRIPT=\$(curl -fsSL "\$UPSTREAM_URL" 2>/dev/null) || {
    msg_error "Failed to fetch upstream install script"
    exit 1
}

# Remove upstream function sourcing (provided by incus-compat)
UPSTREAM_SCRIPT="\${UPSTREAM_SCRIPT//source \/dev\/stdin <<<\"\\\$FUNCTIONS_FILE_PATH\"/: # (functions provided by incus-compat)}"
UPSTREAM_SCRIPT="\${UPSTREAM_SCRIPT//source <(curl -fsSL https:\\/\\/raw.githubusercontent.com\\/community-scripts\\/ProxmoxVE\\/main\\/misc\\/core.func)/: # (core.func)}"
UPSTREAM_SCRIPT="\${UPSTREAM_SCRIPT//source <(curl -fsSL https:\\/\\/raw.githubusercontent.com\\/community-scripts\\/ProxmoxVE\\/main\\/misc\\/error_handler.func)/: # (error_handler.func)}"

# Disable 'set -u' around eval of upstream: the upstream scripts
# use various bash features that may not be safe under strict
# unset-variable mode.
set +u
eval "\$UPSTREAM_SCRIPT"
set -u

echo ""
echo -e "\${GR}${display} installation complete!\${NC}"
echo ""
INSTEOF

  count=$((count + 1))
  if (( count % 50 == 0 )); then
    echo "Generated $count apps..."
  fi
done < "$APPS_FILE"

echo ""
echo "Done! Generated $count app templates."
echo "  ct/     : $(ls "$CT_DIR" | wc -l) files"
echo "  install/: $(ls "$INSTALL_DIR" | wc -l) files"
