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
    # ../sdk/ — but dotnet-install.sh puts SDKs in /usr/share/dotnet/sdk,
    # and on a fresh container there's no /usr/lib/dotnet at all.
    # Create /usr/lib/dotnet and symlink sdk/ so the host can find it,
    # then symlink the dotnet binary into PATH.
    if [[ -d /usr/share/dotnet ]]; then
      mkdir -p /usr/lib/dotnet
      if [[ -d /usr/share/dotnet/sdk ]] && [[ ! -e /usr/lib/dotnet/sdk ]]; then
        ln -sf /usr/share/dotnet/sdk /usr/lib/dotnet/sdk
      fi
      if [[ -d /usr/share/dotnet/shared ]] && [[ ! -e /usr/lib/dotnet/shared ]]; then
        ln -sf /usr/share/dotnet/shared /usr/lib/dotnet/shared
      fi
      if [[ -d /usr/share/dotnet/host ]] && [[ ! -e /usr/lib/dotnet/host ]]; then
        ln -sf /usr/share/dotnet/host /usr/lib/dotnet/host
      fi
    fi
    # Ensure /usr/bin/dotnet exists
    if [[ ! -f /usr/bin/dotnet ]] && [[ -f /usr/share/dotnet/dotnet ]]; then
      ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet
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

# ── Fix PostgreSQL DB (arm64 compat) ────────────────────────
# The upstream calls setup_postgresql_db with env var prefixes
# (PG_DB_NAME="mailarchiver_db" PG_DB_USER="mailarchiver"), but
# our compat function takes positional args. Create the DB here
# if it wasn't created by the upstream (common on arm64).
if ! su - postgres -c "psql -l" 2>/dev/null | grep -q mailarchiver_db; then
  msg_info "Creating PostgreSQL database mailarchiver_db..."
  PG_DB_PASS="$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 16)"
  su - postgres -c "psql -c \"CREATE USER mailarchiver WITH PASSWORD '${PG_DB_PASS}';\" 2>/dev/null" || true
  su - postgres -c "psql -c \"CREATE DATABASE mailarchiver_db OWNER mailarchiver;\" 2>/dev/null" || true
  su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE mailarchiver_db TO mailarchiver;\" 2>/dev/null" || true
  msg_ok "PostgreSQL database 'mailarchiver_db' created"

  # Fix appsettings.json connection string with the generated password
  if [[ -f /opt/mail-archiver/appsettings.json ]]; then
    sed -i "s|\\\"Password=\\\"|\\\"Password=${PG_DB_PASS}\\\"|" /opt/mail-archiver/appsettings.json
    msg_ok "Connection string updated with DB password"
  fi
fi

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
