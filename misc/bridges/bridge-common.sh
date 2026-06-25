#!/usr/bin/env bash
# misc/bridges/bridge-common.sh — Shared library for Matrix bridge installs
#
# All mautrix/* bridges follow the same pattern:
#   1. apt-install the upstream binary (from mautrix-cli's apt repo) OR
#      download a prebuilt tarball from github.com/mautrix/<bridge>/releases
#   2. Generate a config.yaml from template + env vars
#   3. Generate a registration.yaml (appservice registration file)
#   4. Start as systemd service
#
# Source this from inside the container install script:
#   source <(curl -fsSL "$INCUS_BASE/misc/bridges/bridge-common.sh")
#
# Required env vars (export before sourcing OR set in /etc/matrix-bridges.env):
#   BRIDGE_NAME        e.g. "telegram"  (used for systemd unit + config paths)
#   BRIDGE_DISPLAY     e.g. "mautrix-telegram" (for log messages)
#   BRIDGE_BIN         e.g. "/opt/mautrix-telegram/mautrix-telegram"
#   BRIDGE_CONFIG      e.g. "/etc/mautrix-telegram/config.yaml"
#   BRIDGE_REGISTRATION e.g. "/etc/mautrix-telegram/registration.yaml"
#   BRIDGE_DATA_DIR    e.g. "/var/lib/mautrix-telegram"
#   BRIDGE_USER        e.g. "mautrix-telegram" (systemd service user)
#   HS_URL             e.g. "https://matrix.femdev.nl"
#   HS_DOMAIN          e.g. "femdev.nl"  (server_name)
#   APPSERVICE_NS      e.g. "telegram"  (appservice namespace, used in user IDs)

# Defaults that get overridden by sourcing scripts
: "${BRIDGE_NAME:=bridge}"
: "${BRIDGE_DISPLAY:=Matrix Bridge}"
: "${BRIDGE_BIN:=/usr/local/bin/$BRIDGE_NAME}"
: "${BRIDGE_CONFIG:=/etc/$BRIDGE_NAME/config.yaml}"
: "${BRIDGE_REGISTRATION:=/etc/$BRIDGE_NAME/registration.yaml}"
: "${BRIDGE_DATA_DIR:=/var/lib/$BRIDGE_NAME}"
: "${BRIDGE_USER:=$BRIDGE_NAME}"
: "${HS_URL:=http://localhost:8008}"
: "${HS_DOMAIN:=localhost}"
: "${APPSERVICE_NS:=$BRIDGE_NAME}"

# ─── helpers ──────────────────────────────────────────────────────────────

bridge_log()  { echo -e "\033[0;36m[bridge:$BRIDGE_NAME]\033[0m $*"; }

bridge_install_systemd_unit() {
    cat > "/etc/systemd/system/$BRIDGE_NAME.service" <<EOF
[Unit]
Description=$BRIDGE_DISPLAY Matrix bridge
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$BRIDGE_USER
Group=$BRIDGE_USER
WorkingDirectory=$BRIDGE_DATA_DIR
ExecStart=$BRIDGE_BIN -c $BRIDGE_CONFIG -r $BRIDGE_REGISTRATION
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "$BRIDGE_NAME.service"
}

bridge_create_user_and_dirs() {
    if ! id "$BRIDGE_USER" &>/dev/null; then
        useradd --system --home "$BRIDGE_DATA_DIR" --shell /usr/sbin/nologin "$BRIDGE_USER"
    fi
    mkdir -p "$(dirname "$BRIDGE_CONFIG")" "$BRIDGE_DATA_DIR"
    chown -R "$BRIDGE_USER:$BRIDGE_USER" "$BRIDGE_DATA_DIR" "$(dirname "$BRIDGE_CONFIG")"
}

bridge_generate_registration() {
    # Appservice registration file. The shared secret + sender localpart here
    # MUST match what synapse has in homeserver.yaml under
    # `app_service_config_files`. The user pastes the generated
    # registration.yaml into their synapse config dir.
    local secret as_token hs_token
    secret=$(openssl rand -hex 32)
    as_token=$(openssl rand -hex 32)
    hs_token=$(openssl rand -hex 32)

    cat > "$BRIDGE_REGISTRATION" <<EOF
id: "$BRIDGE_NAME"
url: "$HS_URL"
as_token: "$as_token"
hs_token: "$hs_token"
sender_localpart: "_bridge_$APPSERVICE_NS"
rate_limited: false
EOF

    cat > "$BRIDGE_CONFIG" <<EOF
homeserver:
    address: $HS_URL
    domain: $HS_DOMAIN
    appservice:
        address: http://localhost:$(bridge_listen_port)
        hostname: 127.0.0.1
        port: $(bridge_listen_port)

appservice:
    id: $BRIDGE_NAME
    as_token: "$as_token"
    hs_token: "$hs_token"
    bot:
        username: $APPSERVICE_NS
        displayname: $BRIDGE_DISPLAY Bot
        avatar: mxc://femdev.nl/placeholder

# Bridge-specific section is appended by the per-bridge install script.
# See misc/bridges/templates/<bridge>.yaml
EOF
    bridge_log "Generated registration at $BRIDGE_REGISTRATION"
    bridge_log "*** Copy this file into your synapse config dir and add to ***"
    bridge_log "*** app_service_config_files in homeserver.yaml, then restart synapse ***"
}

# Default appservice listen port per bridge (overridden in per-bridge config)
bridge_listen_port() {
    case "$BRIDGE_NAME" in
        telegram)  echo 8443 ;;
        whatsapp)  echo 8444 ;;
        signal)    echo 8445 ;;
        discord)   echo 8446 ;;
        slack)     echo 8447 ;;
        googlechat) echo 8448 ;;
        meta)      echo 8449 ;;
        imessage)  echo 8450 ;;
        twitter)   echo 8451 ;;
        instagram) echo 8452 ;;
        *)         echo 9000 ;;
    esac
}

bridge_install_done_message() {
    cat <<EOF

\033[0;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
  $BRIDGE_DISPLAY installed
\033[0;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

  Config:      $BRIDGE_CONFIG
  Registration: $BRIDGE_REGISTRATION
  Data:        $BRIDGE_DATA_DIR
  Service:     systemctl status $BRIDGE_NAME

  \033[0;33mWiring to femdev.nl:\033[0m
    1. Copy $BRIDGE_REGISTRATION to your synapse pod/helm chart's
       app_service_config_files directory
    2. Add this path to homeserver.yaml:
         app_service_config_files:
           - /data/$BRIDGE_NAME-registration.yaml
    3. Restart synapse (kubectl rollout restart deployment/synapse)
    4. Back here:  systemctl start $BRIDGE_NAME
    5. Log in:    systemctl status $BRIDGE_NAME  (look for login URL/QR)

EOF
}