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

# ── .NET SDK handling ─────────────────────────────────────────
# The upstream's
#   $STD apt install -y \
#     dotnet-sdk-10.0 \
#     libgssapi-krb5-2
# fails because the Microsoft Debian dotnet-sdk-10.0 package
# conflicts with Ubuntu's dotnet-host-10.0 on /usr/bin/dnx.
# This happens on ALL architectures (the Debian vs Ubuntu
# packaging conflict is architecture-independent).
# We install the SDK via dotnet-install.sh (native, no dpkg
# conflict) and patch the upstream to skip the broken apt install.

# Patch upstream: only install libgssapi-krb5-2 via apt
old_text=$'\n$STD apt install -y \\\n  dotnet-sdk-10.0 \\\n  libgssapi-krb5-2'
new_text=$'\n$STD apt install -y libgssapi-krb5-2'
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//$old_text/$new_text}"

msg_info "Installing .NET SDK via dotnet-install.sh..."

# Remove any previously-installed conflicting Ubuntu dotnet packages
apt-get remove -y dotnet-host-10.0 2>/dev/null || true

for i in 1 2 3; do
  curl -fsSL "https://dot.net/v1/dotnet-install.sh" -o /tmp/dotnet-install.sh && break
  sleep 2
done
if [[ -s /tmp/dotnet-install.sh ]]; then
  bash /tmp/dotnet-install.sh --channel 10.0 --install-dir /usr/share/dotnet 2>&1 | tail -3
  rm -f /tmp/dotnet-install.sh

  # dotnet-install.sh puts SDKs in /usr/share/dotnet/sdk, but the
  # dotnet host at /usr/lib/dotnet/dotnet looks for SDKs in ../sdk/.
  # Create /usr/lib/dotnet and symlink so the host can find them.
  if [[ -d /usr/share/dotnet ]]; then
    mkdir -p /usr/lib/dotnet
    for d in sdk shared host; do
      if [[ -d "/usr/share/dotnet/$d" ]] && [[ ! -e "/usr/lib/dotnet/$d" ]]; then
        ln -sf "/usr/share/dotnet/$d" "/usr/lib/dotnet/$d"
      fi
    done
  fi
  # Ensure /usr/bin/dotnet exists
  if [[ ! -f /usr/bin/dotnet ]] && [[ -f /usr/share/dotnet/dotnet ]]; then
    ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet
  fi

  if dotnet --list-sdks &>/dev/null; then
    msg_ok ".NET SDK installed ($(dotnet --list-sdks 2>&1 | tr '\n' ' '))"
  else
    msg_error "dotnet SDK still not available — build may fail"
  fi
else
  msg_error "Failed to download dotnet-install.sh — build may fail"
fi

# ── Eval upstream ────────────────────────────────────────────
set +u
eval "$UPSTREAM_SCRIPT"
set -u

# ── Fix PostgreSQL DB ────────────────────────────────────────
# The upstream calls setup_postgresql_db with env var prefixes
# (PG_DB_NAME="mailarchiver_db" PG_DB_USER="mailarchiver"), but
# our compat function takes positional args. Create the DB here
# if it wasn't created by the upstream.
if ! su - postgres -c "psql -l" 2>/dev/null | grep -q mailarchiver_db; then
  msg_info "Creating PostgreSQL database mailarchiver_db..."
  PG_DB_PASS="$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 16)"
  su - postgres -c "psql -c \"CREATE USER mailarchiver WITH PASSWORD '${PG_DB_PASS}';\" 2>/dev/null" || true
  su - postgres -c "psql -c \"CREATE DATABASE mailarchiver_db OWNER mailarchiver;\" 2>/dev/null" || true
  su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE mailarchiver_db TO mailarchiver;\" 2>/dev/null" || true
  msg_ok "PostgreSQL database 'mailarchiver_db' created"

  # Fix appsettings.json connection string with the generated password
  if [[ -f /opt/mail-archiver/appsettings.json ]]; then
    sed -i "s|\"Password=\"|\"Password=${PG_DB_PASS}\"|" /opt/mail-archiver/appsettings.json
    msg_ok "Connection string updated with DB password"
  fi
fi

# ── Post-eval rebuild ────────────────────────────────────────
# If the upstream's dotnet restore/publish failed (the patched
# apt install removed dotnet-sdk-10.0, so the upstream's build
# step lacks the SDK), rebuild here using the SDK we installed
# above. The source is at /opt/mail-archiver-build (the upstream
# mv'd it there before attempting restore).
if [[ ! -f /opt/mail-archiver/MailArchiver.dll ]]; then
  if [[ -d /opt/mail-archiver-build ]]; then
    msg_info "Rebuilding Mail Archiver..."
    cd /opt/mail-archiver-build
    dotnet restore 2>&1 | tail -5
    dotnet publish -c Release -o /opt/mail-archiver 2>&1 | tail -5
    if [[ -f /opt/mail-archiver/MailArchiver.dll ]]; then
      cp appsettings.json /opt/mail-archiver/ 2>/dev/null || true
      cd /
      rm -rf /opt/mail-archiver-build
      msg_ok "Mail Archiver rebuilt"
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
