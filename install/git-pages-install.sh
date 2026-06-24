#!/usr/bin/env bash
# install/git-pages-install.sh — git-pages static site server
# Hand-written install (no upstream compat-shim needed).
#
# Environment variables (passed from ct script):
#   GIT_PAGES_WITH_CADDY=yes|no  (default: yes)
#   GIT_PAGES_DOMAIN=example.com (optional, for Caddy TLS)

RELEASE_URL="https://codeberg.org/git-pages/git-pages/releases/download/latest"
BINARY_NAME="git-pages.linux-amd64"
CONFIG_DIR="/etc/git-pages"
DATA_DIR="/var/lib/git-pages"
GIT_PAGES_USER="git-pages"

WITH_CADDY="${GIT_PAGES_WITH_CADDY:-yes}"
DOMAIN="${GIT_PAGES_DOMAIN:-}"

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${INCUS_BASE:-https://codeberg.org/luna-dj/incus-scripts/raw/branch/main}/misc/incus-install-compat.func?v=$(date +%s))"

header_info "git-pages"
setting_up_container
network_check
update_os

# ── install dependencies ──────────────────────────────────────
msg_info "Installing dependencies"
apt-get install -y -qq curl ca-certificates 2>/dev/null || true
msg_ok "Dependencies installed"

# ── create user and directories ──────────────────────────────
msg_info "Creating git-pages user and directories"
if ! id -u "$GIT_PAGES_USER" &>/dev/null; then
    useradd -r -d "$DATA_DIR" -s /usr/sbin/nologin "$GIT_PAGES_USER"
fi
mkdir -p "$CONFIG_DIR" "$DATA_DIR"
chown "$GIT_PAGES_USER":"$GIT_PAGES_USER" "$DATA_DIR"
msg_ok "User and directories created"

# ── download git-pages binary ────────────────────────────────
msg_info "Downloading git-pages binary"
curl -fsSL "${RELEASE_URL}/${BINARY_NAME}" -o /usr/local/bin/git-pages 2>/dev/null || {
    # fallback to latest known version
    curl -fsSL "https://codeberg.org/git-pages/git-pages/releases/download/v0.9.1/${BINARY_NAME}" \
      -o /usr/local/bin/git-pages || {
        msg_error "Failed to download git-pages binary"
        exit 1
    }
}
chmod +x /usr/local/bin/git-pages
msg_ok "git-pages binary installed ($(/usr/local/bin/git-pages -version 2>&1 || true))"

# ── create config.toml ──────────────────────────────────────
msg_info "Creating config"
cat > "$CONFIG_DIR/config.toml" << 'CONFEOF'
[server]
pages = "tcp/:3000"

[storage]
type = "fs"
dir = "/var/lib/git-pages"

[limits]
allow-expiration = true
CONFEOF

chown root:root "$CONFIG_DIR/config.toml"
chmod 644 "$CONFIG_DIR/config.toml"
msg_ok "Config created at $CONFIG_DIR/config.toml"

# ── systemd service for git-pages ────────────────────────────
msg_info "Creating systemd service"
cat > /etc/systemd/system/git-pages.service << 'SVCEOF'
[Unit]
Description=git-pages static site server
Documentation=https://git-pages.org
After=network.target

[Service]
Type=simple
User=git-pages
Group=git-pages
RuntimeDirectory=git-pages
StateDirectory=git-pages
ConfigurationDirectory=git-pages
ExecStart=/usr/local/bin/git-pages -config /etc/git-pages/config.toml
Restart=on-failure
RestartSec=5
AmbientCapabilities=
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/var/lib/git-pages
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable --now git-pages.service
msg_ok "git-pages service started"

# ── optional: Caddy reverse proxy ────────────────────────────
if [[ "$WITH_CADDY" != "no" ]]; then
    msg_info "Installing Caddy reverse proxy"

    # Install Caddy from official repo
    curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key | \
        gpg --dearmor --batch --yes -o /usr/share/keyrings/caddy-stable.gpg 2>/dev/null
    curl -fsSL "https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt" | \
        sed 's|https://dl.cloudsmith.io/public/caddy/stable|deb [signed-by=/usr/share/keyrings/caddy-stable.gpg] https://dl.cloudsmith.io/public/caddy/stable/debian|' > /etc/apt/sources.list.d/caddy-stable.list

    apt-get update -qq
    apt-get install -y -qq caddy 2>/dev/null || {
        msg_warn "Caddy apt install failed; trying direct binary download"
        curl -fsSL "https://caddyserver.com/api/download?os=linux&arch=amd64" -o /usr/local/bin/caddy
        chmod +x /usr/local/bin/caddy
        # Create basic systemd unit for manually installed Caddy
        cat > /etc/systemd/system/caddy.service << 'CADDYEOF'
[Unit]
Description=Caddy reverse proxy for git-pages
Documentation=https://caddyserver.com
After=network.target git-pages.service
Wants=git-pages.service

[Service]
Type=simple
ExecStart=/usr/local/bin/caddy run --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
CADDYEOF
        systemctl daemon-reload
    }

    # Write Caddyfile
    if [[ -n "$DOMAIN" ]]; then
        # Production: TLS with domain
        cat > /etc/caddy/Caddyfile << CADDYEOF
${DOMAIN} {
    # On-demand TLS — git-pages decides which domains are allowed
    tls {
        on_demand
    }

    reverse_proxy http://127.0.0.1:3000
}

# Also respond on port 80 for ACME HTTP-01 challenge
http://${DOMAIN} {
    redir https://${DOMAIN}{uri}
}
CADDYEOF
    else
        # Dev/no-domain: HTTP only
        cat > /etc/caddy/Caddyfile << 'CADDYEOF'
:80 {
    reverse_proxy http://127.0.0.1:3000
}
CADDYEOF
    fi

    # Enable and start Caddy (if installed via apt, it's already enabled)
    systemctl enable caddy 2>/dev/null || true
    systemctl restart caddy 2>/dev/null || {
        msg_warn "Caddy service start failed; check /var/log/caddy.log"
    }

    msg_ok "Caddy reverse proxy configured"
fi

# ── verify ────────────────────────────────────────────────────
msg_info "Verifying installation"
sleep 2
if systemctl is-active --quiet git-pages.service; then
    msg_ok "git-pages is running"
else
    msg_error "git-pages service is not active"
    systemctl status git-pages.service --no-pager 2>&1 | tail -5
fi

echo ""
echo -e "${GR}git-pages installation complete!${NC}"
echo ""
echo -e "${BL}API endpoint:    http://$(hostname -I | awk '{print $1}'):3000${NC}"
if [[ "$WITH_CADDY" != "no" ]]; then
    echo -e "${BL}Web endpoint:    http://$(hostname -I | awk '{print $1}')${NC}"
    if [[ -n "$DOMAIN" ]]; then
        echo -e "${BL}Production URL:  https://${DOMAIN}${NC}"
    fi
fi
echo ""
echo -e "${YL}Publish a site:${NC}"
echo "  # From a tarball:"
echo "  curl http://$(hostname -I | awk '{print $1}'):3000/ -X PUT \\"
echo "    -H 'Content-Type: application/x-tar+gzip' \\"
echo "    --data-binary @site.tar.gz"
echo ""
echo "  # From a git repo (clones the 'pages' branch):"
echo "  curl http://$(hostname -I | awk '{print $1}'):3000/ -X PUT \\"
echo "    --data https://github.com/user/repo.git"
echo ""
echo "  # With auth (set a TXT record first):"
echo "  curl http://$(hostname -I | awk '{print $1}'):3000/ -X PUT \\"
echo "    -H 'Authorization: Pages <token>' \\"
echo "    --data https://github.com/user/repo.git"
echo ""
