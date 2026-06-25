
#!/usr/bin/env bash
# ct/add-netbird-lxc.sh — Add Netbird Lxc (addon, Docker-based)
# Generated for Incus from upstream ProxmoxVE Community Scripts (tools/addon/)
# Our wrapper code is MIT; upstream content retains its original license.
#
# Set INCUS_BASE to override the raw content provider:
#   INCUS_BASE=https://raw.githubusercontent.com/luna-dj/incus-scripts/main

INCUS_BASE="${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}"
# Export so it survives subshells (pipes, incus_exec_stdin)
export INCUS_BASE
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE}/common.sh?v=$(date +%s))"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE}/misc/incus-build.func?v=$(date +%s))"

APP="Add Netbird Lxc"
var_tags="${var_tags:-}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-20}"
var_os="${var_os:-ubuntu}"
var_version="${var_version:-24.04}"

header_info "$APP"
variables
check_existing_instance
create_instance

# Fetch the install script content on the host, then push it into the
# container and run it with "bash -s" (which reads the script from stdin).
INSTALL_SCRIPT=$(curl -fsSL --http1.1 "${INCUS_BASE}/install/add-netbird-lxc-install.sh" 2>/dev/null) || {
    log_error "Failed to fetch install script for add-netbird-lxc"
    exit 1
}
printf '%s
' "INCUS_BASE=${INCUS_BASE}" "$INSTALL_SCRIPT" | incus_exec_stdin "$var_instance"

IP=$(get_instance_ip "$var_instance")
echo ""

# Verify the addon's Docker container is actually running. The upstream
# addon can silently exit ("Installation cancelled") if a `read` prompt
# receives empty input — we want to detect that instead of reporting
# success. Poll `docker ps` for up to 60s for a container whose name
# matches the app slug.
if incus_exec_stdin "$var_instance" bash -c '
    for i in $(seq 1 30); do
        if docker ps --format "{{.Names}}" 2>/dev/null | grep -qi "add-netbird-lxc"; then
            echo "OK"
            exit 0
        fi
        sleep 2
    done
    echo "TIMEOUT"
    exit 1
' 2>/dev/null | grep -q "^OK$"; then
    echo -e "${GR}Add Netbird Lxc deployed on ${var_instance} (${IP})${NC}"
else
    echo -e "${YL}Add Netbird Lxc install did not start a Docker container on ${var_instance} (${IP}).${NC}"
    echo -e "${YL}Check: incus exec ${var_instance} -- docker ps -a${NC}"
    exit 1
fi
echo ""
