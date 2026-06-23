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

# ── ARM64 .NET SDK handling ───────────────────────────────────
# On arm64 (QEMU emulated containers), the upstream's
#   $STD apt install -y \
#     dotnet-sdk-10.0 \
#     libgssapi-krb5-2
# fails because the Microsoft Debian dotnet-sdk-10.0 package
# conflicts with Ubuntu's dotnet-host-10.0 on /usr/bin/dnx.
# We install the SDK via dotnet-install.sh (arm64-native) instead,
# and patch the upstream to skip the conflicting apt install.
if [[ "$(uname -m)" == "aarch64" ]]; then
  # Patch upstream: only install libgssapi-krb5-2 via apt, skip dotnet-sdk-10.0
  # The upstream block:
  #   $STD apt install -y \
  #     dotnet-sdk-10.0 \
  #     libgssapi-krb5-2
  old_text=$'\n$STD apt install -y \\\n  dotnet-sdk-10.0 \\\n  libgssapi-krb5-2'
  new_text=$'\n$STD apt install -y libgssapi-krb5-2'
  UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//$old_text/$new_text}"

  msg_info "Preparing .NET SDK for arm64..."

  # Remove any previously-installed conflicting Ubuntu dotnet packages
  # (from a prior failed attempt)
  apt-get remove -y dotnet-host-10.0 2>/dev/null || true

  for i in 1 2 3; do
    curl -fsSL "https://dot.net/v1/dotnet-install.sh" -o /tmp/dotnet-install.sh && break
    sleep 2
  done
  if [[ -s /tmp/dotnet-install.sh ]]; then
    # Install SDK to /usr/share/dotnet (default, arm64-native)
    bash /tmp/dotnet-install.sh --channel 10.0 --install-dir /usr/share/dotnet 2>&1 | tail -3
    rm -f /tmp/dotnet-install.sh

    # The dotnet host at /usr/lib/dotnet/dotnet looks for SDKs in
    # ../sdk/ — symlink from /usr/share/dotnet/sdk so it can find them
    if [[ -d /usr/share/dotnet/sdk ]] && [[ ! -e /usr/lib/dotnet/sdk ]]; then
      ln -sf /usr/share/dotnet/sdk /usr/lib/dotnet/sdk
    fi
    # Ensure /usr/bin/dotnet exists (removed above with dotnet-host-10.0)
    if [[ ! -f /usr/bin/dotnet ]] && [[ -f /usr/lib/dotnet/dotnet ]]; then
      ln -sf ../lib/dotnet/dotnet /usr/bin/dotnet
    fi

    if dotnet --list-sdks &>/dev/null; then
      msg_ok ".NET SDK prepared for arm64 ($(dotnet --list-sdks 2>&1 | tr '\n' ' '))"
    else
      msg_error "dotnet SDK still not available — build may fail"
    fi
  else
    msg_error "Failed to download dotnet-install.sh — build may fail"
  fi
fi

# ── Eval upstream ────────────────────────────────────────────
# Disable 'set -u' around eval of upstream: the upstream scripts
# use various bash features that may not be safe under strict
# unset-variable mode.
set +u
eval "$UPSTREAM_SCRIPT"
set -u

# ── Post-eval arm64 rebuild ──────────────────────────────────
# If the upstream's dotnet restore/publish failed (common on arm64
# because we patched the apt install), rebuild here using the SDK
# we installed above.  The source is at /opt/mail-archiver-build
# (the upstream mv'd it there before attempting restore), so we
# can pick up where it left off.
if [[ "$(uname -m)" == "aarch64" ]] && [[ ! -f /opt/mail-archiver/MailArchiver.dll ]]; then
  if [[ -d /opt/mail-archiver-build ]]; then
    msg_info "Rebuilding Mail Archiver on arm64..."
    cd /opt/mail-archiver-build
    dotnet restore 2>&1 | tail -5
    dotnet publish -c Release -o /opt/mail-archiver 2>&1 | tail -5
    if [[ -f /opt/mail-archiver/MailArchiver.dll ]]; then
      cp appsettings.json /opt/mail-archiver/ 2>/dev/null || true
      cd /
      rm -rf /opt/mail-archiver-build
      msg_ok "Mail Archiver rebuilt for arm64"
    else
      msg_error "Mail Archiver rebuild failed — check dotnet restore/publish above"
    fi
  else
    msg_warn "Source directory /opt/mail-archiver-build not found, can't rebuild"
  fi
fi

echo ""
echo -e "${GR}Mail Archiver installation complete!${NC}"
echo ""
