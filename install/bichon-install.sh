#!/usr/bin/env bash
# install/bichon-install.sh — Bichon
# Generated for Incus from upstream ProxmoxVE Community Scripts
# Our wrapper code is MIT; upstream content retains its original license.

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/incus-install-compat.func?v=$(date +%s))"

header_info "Bichon"
setting_up_container
network_check
update_os

msg_info "Loading upstream install script for Bichon"
UPSTREAM_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/bichon-install.sh"
UPSTREAM_SCRIPT=$(curl -fsSL "${UPSTREAM_URL}?v=$(date +%s)" 2>/dev/null) || {
    msg_error "Failed to fetch upstream install script"
    exit 1
}

# Remove upstream function sourcing (provided by incus-compat)
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source \/dev\/stdin <<<\"\$FUNCTIONS_FILE_PATH\"/: # (functions provided by incus-compat)}"
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/core.func)/: # (core.func)}"
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/error_handler.func)/: # (error_handler.func)}"

# ── Fix architecture naming ──────────────────────────────────
# Upstream asset pattern:
#   bichon-*-$(arch_resolve "x86_64" "aarch64")-unknown-linux-gnu.tar.gz
# Our compat arch_resolve ignores args, returns "amd64"/"arm64".
# Github releases use Rust triple naming: x86_64/aarch64.
# Fix: replace arch_resolve call with raw $(uname -m)
ARCH_TRIPLE=$(uname -m)
UPSTREAM_SCRIPT="${UPSTREAM_SCRIPT//bichon-\*-\$\(arch_resolve \"x86_64\" \"aarch64\"\)-unknown-linux-gnu.tar.gz/bichon-server-*-${ARCH_TRIPLE}-unknown-linux-gnu.tar.gz}"

# ── Eval upstream ────────────────────────────────────────────
set +u
eval "$UPSTREAM_SCRIPT"
set -u

# ── Fix password in bichon.env ───────────────────────────────
# The upstream has mangled password generation lines.
# Regenerate the encryption password if the env file has the broken value.
BICHON_ENV="/opt/bichon/bichon.env"
if [[ -f "$BICHON_ENV" ]] && grep -q "BICHO\.\.\.WORD\|=*** rand" "$BICHON_ENV" 2>/dev/null; then
  msg_info "Fixing Bichon encryption password..."
  NEW_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
  sed -i "s/BICHON_ENCRYPT_PASSWORD=.*/BICHON_ENCRYPT_PASSWORD=${NEW_PASS}/" "$BICHON_ENV"
  systemctl restart bichon 2>/dev/null || true
  msg_ok "Bichon encryption password regenerated"
fi

echo ""
echo -e "${GR}Bichon installation complete!${NC}"
echo ""
