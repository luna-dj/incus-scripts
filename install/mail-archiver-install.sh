#!/usr/bin/env bash
# install/mail-archiver-install.sh — Mail Archiver
# Generated for Incus from upstream ProxmoxVE Community Scripts
# Our wrapper code is MIT; upstream content retains its original license.

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/incus-install-compat.func?v=$(date +%s))"

header_info "Mail Archiver"
setting_up_container
network_check
update_os

msg_info "Loading upstream install script for Mail Archiver"
UPSTREAM_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/mail-archiver-install.sh"
UPSTREAM_SCRIPT=$(curl -fsSL "${UPSTREAM_URL}?v=$(date +%s)" 2>/dev/null) || {
    msg_error "Failed to fetch upstream install script"
    exit 1
}

# Remove upstream function sourcing (provided by incus-compat)
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source \/dev\/stdin <<<\"\$FUNCTIONS_FILE_PATH\"/: # (functions provided by incus-compat)}"
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/core.func)/: # (core.func)}"
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/error_handler.func)/: # (error_handler.func)}"

# On arm64, dotnet-sdk via apt installs amd64 packages (emulated) but fails
# to install the actual SDK component. Pre-install it via dotnet-install.sh.
if [[ "$(uname -m)" == "aarch64" ]]; then
  msg_info "Pre-installing .NET SDK for arm64..."
  for i in 1 2 3; do
    curl -fsSL "https://dot.net/v1/dotnet-install.sh" -o /tmp/dotnet-install.sh && break
    sleep 2
  done
  if [[ -s /tmp/dotnet-install.sh ]]; then
    bash /tmp/dotnet-install.sh --channel 10.0 --install-dir /usr/lib/dotnet 2>&1 | tail -3
    rm -f /tmp/dotnet-install.sh
    if dotnet --list-sdks &>/dev/null; then
      msg_ok ".NET SDK pre-installed for arm64"
    else
      msg_error "dotnet SDK still not available after install — build may fail"
    fi
  else
    msg_error "Failed to download dotnet-install.sh — build may fail"
  fi
fi

# Disable 'set -u' around eval of upstream: the upstream scripts
# use various bash features that may not be safe under strict
# unset-variable mode.
set +u
eval "$UPSTREAM_SCRIPT"
set -u

# On arm64, the upstream's 'apt install dotnet-sdk-10.0' silently fails
# (no arm64 package in the Microsoft repo), so the upstream's
# dotnet restore + dotnet publish step also fails. Rebuild here
# using the SDK we pre-installed above.
if [[ "$(uname -m)" == "aarch64" ]] && [[ ! -f /opt/mail-archiver/MailArchiver.dll ]]; then
  msg_info "Rebuilding Mail Archiver on arm64..."
  if [[ -d /opt/mail-archiver-build ]]; then
    cd /opt/mail-archiver-build
    dotnet restore 2>&1 | tail -5
    dotnet publish -c Release -o /opt/mail-archiver 2>&1 | tail -5
    if [[ -f /opt/mail-archiver/MailArchiver.dll ]]; then
      cp appsettings.json /opt/mail-archiver/ 2>/dev/null || true
      msg_ok "Mail Archiver rebuilt for arm64"
    else
      msg_error "Mail Archiver rebuild failed — check dotnet restore/publish above"
    fi
    cd /
    rm -rf /opt/mail-archiver-build
  fi
fi

echo ""
echo -e "${GR}Mail Archiver installation complete!${NC}"
echo ""
