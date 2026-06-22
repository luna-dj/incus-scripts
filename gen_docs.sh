#!/usr/bin/env bash
# gen_docs.sh — Generate static docs site for all Incus scripts
# Reads ct/*.sh metadata, produces:
#   docs/index.html            (landing page with search + grid)
#   docs/apps/<app>.html       (one page per app)
#   docs/apps.json             (search index)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CT_DIR="$ROOT/ct"
DOCS_DIR="$ROOT/docs"
APPS_DIR="$DOCS_DIR/apps"

mkdir -p "$APPS_DIR"

REPO="luna-dj/incus-scripts"
BRANCH="${BRANCH:-main}"
RAW="https://codeberg.org/$REPO/raw/branch/$BRANCH"

# ── Category inference ──────────────────────
# Categorize based on app slug (since generated tags are empty)
categorize() {
  local app="$1" tags="$2"
  local a=$(echo "$app" | tr '[:upper:]' '[:lower:]')
  local t=$(echo "$tags" | tr '[:upper:]' '[:lower:]')
  local combined="$a $t"

  # Direct slug→category lookup: try each slug, return on first match.
  # This prevents the fallback patterns from also matching and causing
  # duplicate (e.g., "Business\nBusiness") output.
  case "$app" in
    actualbudget) echo "Business" && return 0 ;;
    agentdvr) echo "Media" && return 0 ;;
    ampache) echo "Media" && return 0 ;;
    anchor) echo "Media" && return 0 ;;
    anytype-server) echo "Productivity" && return 0 ;;
    apache-guacamole) echo "Utilities" && return 0 ;;
    apache-tika) echo "Utilities" && return 0 ;;
    apache-tomcat) echo "Development" && return 0 ;;
    apprise-api) echo "Communication" && return 0 ;;
    argus) echo "Monitoring" && return 0 ;;
    aria2) echo "Utilities" && return 0 ;;
    asterisk) echo "Communication" && return 0 ;;
    autobrr) echo "Media" && return 0 ;;
    autocaliweb) echo "Media" && return 0 ;;
    backrest) echo "Cloud & Storage" && return 0 ;;
    bitfocus-companion) echo "Media" && return 0 ;;
    bitmagnet) echo "Media" && return 0 ;;
    booklore) echo "Productivity" && return 0 ;;
    bookorbit) echo "Productivity" && return 0 ;;
    byparr) echo "Media" && return 0 ;;
    bytestash) echo "Utilities" && return 0 ;;
    certimate) echo "Security" && return 0 ;;
    changedetection) echo "Monitoring" && return 0 ;;
    checkmate) echo "Monitoring" && return 0 ;;
    cockpit) echo "Containers" && return 0 ;;
    configarr) echo "Media" && return 0 ;;
    crafty-controller) echo "Gaming" && return 0 ;;
    cross-seed) echo "Media" && return 0 ;;
    dawarich) echo "Productivity" && return 0 ;;
    discopanel) echo "Media" && return 0 ;;
    dispatcharr) echo "Media" && return 0 ;;
    docuseal) echo "Productivity" && return 0 ;;
    ezbookkeeping) echo "Business" && return 0 ;;
    feishin) echo "Media" && return 0 ;;
    firefly) echo "Business" && return 0 ;;
    fireshare) echo "Media" && return 0 ;;
    flaresolverr) echo "Media" && return 0 ;;
    foldergram) echo "Productivity" && return 0 ;;
    freepbx) echo "Communication" && return 0 ;;
    ghost) echo "Development" && return 0 ;;
    ghostfolio) echo "Business" && return 0 ;;
    gluetun) echo "Networking" && return 0 ;;
    go2rtc) echo "Media" && return 0 ;;
    gotify) echo "Communication" && return 0 ;;
    grist) echo "Productivity" && return 0 ;;
    grocy) echo "Productivity" && return 0 ;;
    hyperhdr) echo "Media" && return 0 ;;
    hyperion) echo "Media" && return 0 ;;
    igotify) echo "Communication" && return 0 ;;
    inventree) echo "Business" && return 0 ;;
    itsm-ng) echo "Business" && return 0 ;;
    kan) echo "Productivity" && return 0 ;;
    kapowarr) echo "Media" && return 0 ;;
    koillection) echo "Productivity" && return 0 ;;
    komodo) echo "Containers" && return 0 ;;
    kutt) echo "Productivity" && return 0 ;;
    linkstack) echo "Productivity" && return 0 ;;
    listmonk) echo "Communication" && return 0 ;;
    lldap) echo "Security" && return 0 ;;
    lobehub) echo "AI" && return 0 ;;
    magicmirror) echo "Home Automation" && return 0 ;;
    matomo) echo "Monitoring" && return 0 ;;
    mealie) echo "Productivity" && return 0 ;;
    meilisearch) echo "Database" && return 0 ;;
    metube) echo "Media" && return 0 ;;
    minarca) echo "Cloud & Storage" && return 0 ;;
    monica) echo "Productivity" && return 0 ;;
    mylar3) echo "Media" && return 0 ;;
    myspeed) echo "Networking" && return 0 ;;
    nextexplorer) echo "Cloud & Storage" && return 0 ;;
    nextpvr) echo "Media" && return 0 ;;
    notifiarr) echo "Monitoring" && return 0 ;;
    ntfy) echo "Communication" && return 0 ;;
    omada) echo "Networking" && return 0 ;;
    ombi) echo "Media" && return 0 ;;
    openobserve) echo "Monitoring" && return 0 ;;
    owncast) echo "Media" && return 0 ;;
    pangolin) echo "Networking" && return 0 ;;
    paperclip) echo "Productivity" && return 0 ;;
    papra) echo "Productivity" && return 0 ;;
    patchmon) echo "Monitoring" && return 0 ;;
    plant-it) echo "Productivity" && return 0 ;;
    pocketbase) echo "Development" && return 0 ;;
    pocketid) echo "Security" && return 0 ;;
    profilarr) echo "Media" && return 0 ;;
    projectsend) echo "Productivity" && return 0 ;;
    pulse) echo "Monitoring" && return 0 ;;
    qdrant) echo "AI" && return 0 ;;
    qui) echo "Productivity" && return 0 ;;
    radicale) echo "Productivity" && return 0 ;;
    rdtclient) echo "Media" && return 0 ;;
    reactive-resume) echo "Productivity" && return 0 ;;
    recyclarr) echo "Media" && return 0 ;;
    romm) echo "Gaming" && return 0 ;;
    scanopy) echo "Productivity" && return 0 ;;
    scraparr) echo "Media" && return 0 ;;
    searxng) echo "Productivity" && return 0 ;;
    seelf) echo "Development" && return 0 ;;
    semaphore) echo "Development" && return 0 ;;
    shlink) echo "Productivity" && return 0 ;;
    slskd) echo "Media" && return 0 ;;
    smokeping) echo "Monitoring" && return 0 ;;
    solidtime) echo "Productivity" && return 0 ;;
    sonarqube) echo "Development" && return 0 ;;
    sonobarr) echo "Media" && return 0 ;;
    spliit) echo "Productivity" && return 0 ;;
    split-pro) echo "Productivity" && return 0 ;;
    spoolman) echo "Productivity" && return 0 ;;
    sportarr) echo "Media" && return 0 ;;
    step-ca) echo "Security" && return 0 ;;
    storybook) echo "Development" && return 0 ;;
    tandoor) echo "Productivity" && return 0 ;;
    tasmoadmin) echo "Home Automation" && return 0 ;;
    tasmocompiler) echo "Home Automation" && return 0 ;;
    tdarr) echo "Media" && return 0 ;;
    teable) echo "Productivity" && return 0 ;;
    tianji) echo "Monitoring" && return 0 ;;
    tolgee) echo "Development" && return 0 ;;
    traccar) echo "Monitoring" && return 0 ;;
    tracktor) echo "Monitoring" && return 0 ;;
    tubearchivist) echo "Media" && return 0 ;;
    tududi) echo "Productivity" && return 0 ;;
    tunarr) echo "Media" && return 0 ;;
    twenty) echo "Productivity" && return 0 ;;
    twingate-connector) echo "Networking" && return 0 ;;
    umami) echo "Monitoring" && return 0 ;;
    umlautadaptarr) echo "Media" && return 0 ;;
    unifi-os-server) echo "Networking" && return 0 ;;
    unmanic) echo "Media" && return 0 ;;
    upsnap) echo "Productivity" && return 0 ;;
    vikunja) echo "Productivity" && return 0 ;;
    wallos) echo "Productivity" && return 0 ;;
    wastebin) echo "Productivity" && return 0 ;;
    watchyourlan) echo "Networking" && return 0 ;;
    wealthfolio) echo "Business" && return 0 ;;
    web-check) echo "Monitoring" && return 0 ;;
    wizarr) echo "Media" && return 0 ;;
    wordpress) echo "Development" && return 0 ;;
    writefreely) echo "Productivity" && return 0 ;;
    yourls) echo "Productivity" && return 0 ;;
    yt-dlp-webui) echo "Media" && return 0 ;;
    yunohost) echo "Cloud & Storage" && return 0 ;;
    zammad) echo "Communication" && return 0 ;;
    zipline) echo "Productivity" && return 0 ;;
    zitadel) echo "Security" && return 0 ;;
    zoraxy) echo "Networking" && return 0 ;;
    bunkerweb) echo "Security" && return 0 ;;
    donetick) echo "Productivity" && return 0 ;;
    dotnetaspwebapi) echo "Development" && return 0 ;;
    glance) echo "Dashboards" && return 0 ;;
    hev-socks5-server) echo "Networking" && return 0 ;;
    jotty) echo "Productivity" && return 0 ;;
    minthcm) echo "Business" && return 0 ;;
    netvisor) echo "Networking" && return 0 ;;
    netboot-xyz) echo "Development" && return 0 ;;
    nodecast-tv) echo "Media" && return 0 ;;
    openziti-controller) echo "Networking" && return 0 ;;
    ots) echo "Security" && return 0 ;;
    proxmox-backup-server) echo "Cloud & Storage" && return 0 ;;
    proxmox-datacenter-manager) echo "Containers" && return 0 ;;
    proxmox-mail-gateway) echo "Communication" && return 0 ;;
    teleport) echo "Networking" && return 0 ;;
    termix) echo "Development" && return 0 ;;
    transmute) echo "Utilities" && return 0 ;;
    upgopher) echo "Monitoring" && return 0 ;;
    versitygw) echo "Cloud & Storage" && return 0 ;;
    storyteller) echo "Media" && return 0 ;;
    nightscout) echo "Other" && return 0 ;;
    neko) echo "Gaming" && return 0 ;;
    bambuddy) echo "Home Automation" && return 0 ;;
    bichon) echo "Utilities" && return 0 ;;
    dynacat) echo "Productivity" && return 0 ;;
    hermesagent) echo "AI" && return 0 ;;
    isponsorblocktv) echo "Media" && return 0 ;;
    kima-hub) echo "Development" && return 0 ;;
    limesurvey) echo "Productivity" && return 0 ;;
    managemydamnlife) echo "Productivity" && return 0 ;;
    omv) echo "Cloud & Storage" && return 0 ;;
    peanut) echo "Productivity" && return 0 ;;
    salt) echo "Media" && return 0 ;;
    snowshare) echo "Cloud & Storage" && return 0 ;;
    sure) echo "Monitoring" && return 0 ;;
    yubal) echo "Security" && return 0 ;;
    nightscout) echo "Other" && return 0 ;;
    manyfold) echo "Media" && return 0 ;;
    nametag) echo "Utilities" && return 0 ;;
    ownfoil) echo "Other" && return 0 ;;
    reitti) echo "Other" && return 0 ;;
    trek) echo "Other" && return 0 ;;
    trip) echo "Other" && return 0 ;;
    wanderer) echo "Other" && return 0 ;;
    xyops) echo "Other" && return 0 ;;
    zerobyte) echo "Other" && return 0 ;;
    babybuddy) echo "Other" && return 0 ;;
    bar-assistant) echo "Other" && return 0 ;;
    birdnet-go) echo "Other" && return 0 ;;
    hortusfox) echo "Other" && return 0 ;;
    protonmail-bridge) echo "Communication" && return 0 ;;
    kimai) echo "Business" && return 0 ;;
    baikal) echo "Productivity" && return 0 ;;
    pairdrop) echo "Utilities" && return 0 ;;
    apache-airflow) echo "Development" && return 0 ;;
    domain-locker) echo "Security" && return 0 ;;
    endurain) echo "Other" && return 0 ;;
    mail-archiver) echo "Utilities" && return 0 ;;
    investbrain) echo "Business" && return 0 ;;
    uhf) echo "Media" && return 0 ;;
    splunk-enterprise) echo "Monitoring" && return 0 ;;
    mafl) echo "Dashboards" && return 0 ;;
    teddycloud) echo "Media" && return 0 ;;
    netbox) echo "Networking" && return 0 ;;
    strapi) echo "Development" && return 0 ;;
    miniflux) echo "Productivity" && return 0 ;;
    zot-registry) echo "Containers" && return 0 ;;
    inspircd) echo "Communication" && return 0 ;;
    jitsi-meet) echo "Communication" && return 0 ;;
    librespeed-rust) echo "Monitoring" && return 0 ;;
    rustdeskserver) echo "Utilities" && return 0 ;;
    rustypaste) echo "Productivity" && return 0 ;;
    rwmarkable) echo "Other" && return 0 ;;
    shelfmark) echo "Productivity" && return 0 ;;
    sparkyfitness) echo "Other" && return 0 ;;
    fumadocs) echo "Development" && return 0 ;;
    mattermost) echo "Communication" && return 0 ;;
    dolibarr) echo "Business" && return 0 ;;
    duplicati) echo "Cloud & Storage" && return 0 ;;
    invoiceshelf) echo "Business" && return 0 ;;
    nextcloud) echo "Cloud & Storage" && return 0 ;;
    nextcloudpi) echo "Cloud & Storage" && return 0 ;;
    rclone) echo "Cloud & Storage" && return 0 ;;
    sftpgo) echo "Cloud & Storage" && return 0 ;;
    syncthing) echo "Cloud & Storage" && return 0 ;;
    urbackupserver) echo "Cloud & Storage" && return 0 ;;
    dashy) echo "Dashboards" && return 0 ;;
    heimdall-dashboard) echo "Dashboards" && return 0 ;;
    homarr) echo "Dashboards" && return 0 ;;
    homepage) echo "Dashboards" && return 0 ;;
    homer) echo "Dashboards" && return 0 ;;
    adventurelog) echo "Productivity" && return 0 ;;
    lubelogger) echo "Productivity" && return 0 ;;
    wavelog) echo "Other" && return 0 ;;
    bichon) echo "Development" && return 0 ;;
    languagetool) echo "Productivity" && return 0 ;;
    resiliosync) echo "Cloud & Storage" && return 0 ;;
    geopulse) echo "Monitoring" && return 0 ;;
    ps5-mqtt) echo "Home Automation" && return 0 ;;
    teamspeak-server) echo "Communication" && return 0 ;;
    neko) echo "Other" && return 0 ;;
    sparkyfitness) echo "Other" && return 0 ;;
    glpi) echo "Business" && return 0 ;;
    snipeit) echo "Business" && return 0 ;;
    openthread-br) echo "Networking" && return 0 ;;
    threadfin) echo "Media" && return 0 ;;
    thingsboard) echo "Home Automation" && return 0 ;;
    wger) echo "Other" && return 0 ;;
    medusa) echo "Development" && return 0 ;;
    homebox) echo "Productivity" && return 0 ;;
    meshcentral) echo "Utilities" && return 0 ;;
    bichon) echo "Development" && return 0 ;;
    *) : ;;  # not found, fall through
  esac
  case "$combined" in
    *postgres*|*mariadb*|*mysql*|*redis*|*valkey*|*mongo*|*sqlite*|*keydb*|*clickhouse*|*duckdb*|*questdb*|*neo4j*|*arangodb*|*cassandra*|*couchdb*|*influxdb*|*memcached*|*ferretdb*|*surrealdb*|*mssql*|*sqlserver*|*phpmyadmin*|*adminer*|*pgadmin*|*myipam*|*phpipam*|*netbox*|*dbgate*|*drawdb*|*nocodb*|*baserow*|*directus*|*strapi*)
      echo "Database" ;;
    *nginx*|*traefik*|*caddy*|*haproxy*|*pihole*|*adguard*|*blocky*|*coredns*|*unbound*|*dnsdist*|*knot*|*powerdns*|*technitiumdns*|*bind*|*squid*|*sniproxy*|*wireguard*|*openvpn*|*headscale*|*netbird*|*nebula*|*zerotier*|*tailscale*|*pivpn*|*wg-easy*|*firezone*|*netmaker*|*ddns*|*ddclient*|*cloudflared*|*frp*|*rathole*)
      echo "Networking" ;;
    *plex*|*jellyfin*|*emby*|*navidrome*|*funkwhale*|*kavita*|*komga*|*lanraragi*|*calibre*|*audiobookshelf*|*lidarr*|*radarr*|*sonarr*|*readarr*|*prowlarr*|*bazarr*|*whisparr*|*sabnzbd*|*nzbget*|*qbittorrent*|*transmission*|*deluge*|*rutorrent*|*sick*|*jackett*|*indexer*|*ersatz*|*overseerr*|*jellyseerr*|*seerr*|*tautulli*|*tdarr*|*immich*|*photoprism*|*piwigo*|*lychee*|*nextcloud*|*nextcloudpi*|*seafile*|*filebrowser*|*filerun*|*kodbox*|*copyparty*|*snapdrop*|*syncthing*|*owncloud*|*pydio*|*duplicati*|*restic*|*borg*|*kopia*|*urbackup*|*rclone*|*rsnapshot*|*sftpgo*|*peertransfer*)
      echo "Media" ;;
    *uptimekuma*|*gatus*|*grafana*|*prometheus*|*loki*|*alertmanager*|*netdata*|*zabbix*|*nagios*|*librenms*|*observium*|*checkmk*|*glances*|*healthchecks*|*speedtest*|*dozzle*|*signoz*|*vector*|*telegraf*|*influxdb*|*victoriametrics*|*thanos*|*mimir*|*metabase*|*superset*|*dashy*|*homepage*|*homer*|*heimdall*|*homarr*|*statping*|*kuma*|*cachet*)
      echo "Monitoring" ;;
    *vaultwarden*|*bitwarden*|*passbolt*|*keycloak*|*authentik*|*authelia*|*tinyauth*|*oauth2-proxy*|*crowdsec*|*fail2ban*|*wazuh*|*graylog*|*osquery*|*snort*|*suricata*|*wireguard*|*openvpn*|*2fa*|*privacyidea*|*teampass*|*passwork*|*passbolt*|*passky*|*psono*|*1password*)
      echo "Security" ;;
    *homeassistant*|*homebox*|*homelable*|*zigbee*|*node-red*|*nodered*|*esphome*|*homebridge*|*mosquitto*|*mqtt*|*emqx*|*hivemq*|*deconz*|*matter*|*openhab*|*jeedom*|*domoticz*|*iobroker*|*tasmota*|*kasa*|*tuya*|*shelly*|*scrutiny*|*gladys*|*mydas*)
      echo "Home Automation" ;;
    *ollama*|*openwebui*|*comfyui*|*flowise*|*dify*|*n8n*|*langflow*|*librechat*|*chat*|*llm*|*gpt*|*stable*|*automatic*|*invokeai*|*text-gen*|*textgen*|*localai*|*kobold*|*oobabooga*|*sd-webui*)
      echo "AI" ;;
    *docker*|*podman*|*dockge*|*portainer*|*runtipi*|*coolify*|*casaos*|*dokploy*|*yacht*|*swizzin*|*umbrel*|*umbrel-os*|*cosmos*|*umbrel-community*|*startos*)
      echo "Containers" ;;
    *dashy*|*homepage*|*homer*|*heimdall*|*homarr*|*flame*|*organizr*|*cosmos*|*wger*|*dashmachine*|*dashlit*|*dashboard*)
      echo "Dashboards" ;;
    *nextcloud*|*owncloud*|*seafile*|*syncthing*|*filebrowser*|*filerun*|*kodbox*|*minio*|*garage*|*seaweedfs*|*rclone*|*restic*|*borg*|*kopia*|*duplicati*|*urbackup*|*pcloud*|*storj*|*fileflows*|*paperless*|*archivebox*|*alpine-bitmagnet*|*sftpgo*)
      echo "Cloud & Storage" ;;
    *gitea*|*forgejo*|*gogs*|*gitlab*|*github-runner*|*drone*|*woodpecker*|*jenkins*|*concourse*|*argocd*|*flux*|*tekton*|*spinnaker*|*buildbot*|*kasm*|*code-server*|*coder*|*theia*|*opengist*|*gist*|*snibox*|*codex*|*livebook*|*pluto*|*polynote*|*jupyter*|*vscode*)
      echo "Development" ;;
    *bookmark*|*read*|*rss*|*notes*|*wiki*|*freshrss*|*miniflux*|*rss*|*feedly*|*wallabag*|*readeck*|*linkding*|*linkwarden*|*shiori*|*karakeep*|*hoarder*|*readwise*|*reader*|*joplin*|*siyuan*|*trilium*|*anubis*|*memos*|*affine*|*logseq*|*obsidian*|*notion*|*outline*|*docmost*|*hedgedoc*|*dokuwiki*|*bookstack*|*mediawiki*|*wikijs*|*docusaurus*|*mkdocs*|*docsify*|*notion*)
      echo "Productivity" ;;
    *cs16*|*csgo*|*minecraft*|*factorio*|*terraria*|*steam*|*valheim*|*ark*|*rust*|*gameserver*|*minetest*|*teamspeak*|*mumble*|*jitsi*|*bigbluebutton*)
      echo "Gaming" ;;
    *)
      # Default fallback for unknown apps
      case "$a" in
        # Networking
        *proxy*|*dns*|*vpn*|*vlan*|*wlan*|*firewall*|*gateway*|*switch*|*mesh*|*tunnel*|*adguard*|*cloudflare*|*ddns*|*ddclient*|*gluetun*|*gwn*|*frp*|*tailscale*|*zerotier*|*headscale*|*netbird*|*wireguard*|*pihole*|*rport*|*myspeed*|*watchyourlan*|*net*work*|*twingate*|*pangolin*|*openziti*|*omada*|*unifi*|*npmplus*|*hev*|*myip*|*net*visor*|*teleport*|*zoraxy*) echo "Networking" ;; 
        # Databases
        *db*|*sql*|*data*|*redis*|*mongo*|*kafka*|*rabbitmq*|*meilisearch*|*qdrant*|*typesense*|*weaviate*|*milvus*|*chromadb*) echo "Database" ;;
        # Media
        *media*|*stream*|*video*|*photo*|*audio*|*music*|*torrent*|*usenet*|*arr*|*radarr*|*sonarr*|*lidarr*|*readarr*|*prowlarr*|*bazarr*|*tautulli*|*tdarr*|*sabnzbd*|*nzbget*|*qbittorrent*|*deluge*|*jackett*|*seerr*|*immich*|*jellyfin*|*plex*|*emby*|*navidrome*|*kavita*|*komga*|*audiobook*|*lychee*|*photoprism*|*piwigo*|*tubearchivist*|*yt-dlp*|*tunarr*|*kometa*|*dvr*|*epg*|*iptv*|*channel*|*m3u*|*tvhead*|*xteve*|*comics*|*manga*|*ampache*|*koel*|*ices*|*times*|*lms*) echo "Media" ;;
        # Monitoring / Observability
        *monitor*|*metric*|*log*|*trace*|*status*|*alert*|*uptime*|*gatus*|*grafana*|*prometheus*|*loki*|*netdata*|*zabbix*|*nagios*|*dozzle*|*signoz*|*beszel*|*checkmk*|*glances*|*speedtest*|*health*check*|*cronicle*|*smokeping*|*changedetect*|*notifiarr*|*matomo*|*umami*|*tianji*|*traccar*|*librenms*|*patchmon*|*statping*|*pulse*|*web-check*) echo "Monitoring" ;;
        # Security / Auth
        *vault*|*pass*|*auth*|*keycloak*|*authentik*|*authelia*|*crowdsec*|*fail2ban*|*wazuh*|*2fa*|*oauth*|*lldap*|*step-ca*|*cert*|*zitadel*|*guardian*|*degoog*|*globaleaks*|*ironclaw*|*infisical*) echo "Security" ;;
        # AI / LLM
        *llm*|*gpt*|*ollama*|*librechat*|*openwebui*|*comfyui*|*langflow*|*libretranslate*|*lobehub*|*dify*|*invokeai*|*kobold*|*stable*diffusion*|*text-gen*|*localai*) echo "AI" ;;
        # Containers / DevOps
        *docker*|*podman*|*kubernetes*|*compose*|*runtipi*|*coolify*|*casaos*|*dokploy*|*portainer*|*dockge*|*swizzin*|*watchtower*|*cockpit*|*cosmos*|*dagu*) echo "Containers" ;;
        # Dashboards
        *dashboard*|*homepage*|*homer*|*homarr*|*heimdall*|*dashy*|*flame*|*organizr*) echo "Dashboards" ;;
        # Cloud / Storage / Files
        *cloud*|*file*|*sync*|*s3*|*backup*|*minio*|*garage*|*seaweedfs*|*duplicati*|*restic*|*kopia*|*urbackup*|*minarca*|*paperless*|*archive*|*nextexplorer*|*kodbox*|*storage*) echo "Cloud & Storage" ;;
        # Development / Code / CI
        *git*|*forge*|*runner*|*ci*|*cd*|*deploy*|*code*|*ide*|*jupyter*|*livebook*|*gitea*|*forgejo*|*wordpress*|*ghost*|*strapi*|*directus*|*storybook*|*onerepo*|*onedev*|*semaphore*|*sonarqube*|*revealjs*|*gokapi*|*opengist*|*kubo*|*kasm*|*theia*|*stylus*|*tolgee*) echo "Development" ;;
        # Productivity / Notes / Wiki / RSS / Bookmarks
        *bookmark*|*rss*|*note*|*wiki*|*todo*|*task*|*kanban*|*board*|*plane*|*planka*|*focalboard*|*leantime*|*openproject*|*joplin*|*siyuan*|*trilium*|*memos*|*logseq*|*obsidian*|*outline*|*docmost*|*hedgedoc*|*dokuwiki*|*bookstack*|*wikijs*|*docusaurus*|*silverbullet*|*cryptpad*|*privatebin*|*writefreely*|*shiori*|*wallabag*|*readeck*|*linkding*|*linkwarden*|*miniflux*|*freshrss*|*kiwix*|*onlyoffice*|*grist*|*nocodb*|*baserow*|*teable*|*monica*|*grocy*|*mealie*|*tandoor*|*kitchenowl*|*linkstack*|*yourls*|*zipline*|*feed*|*reader*|*librar*|*searx*|*whoogle*|*fladder*|*fluid*|*foldergram*|*gotify*|*gramps*|*hoodik*|*inv*|*vault*|*vaultwarden*|*vikunja*|*wallos*|*wastebin*|*webtrees*|*wishlist*|*yam*|*docuseal*|*paperclip*|*papra*|*book*) echo "Productivity" ;;
        # Chat / Communication / Email / Forum
        *chat*|*mail*|*forum*|*matrix*|*xmpp*|*irc*|*lounge*|*mattermost*|*element*|*rocketchat*|*zammad*|*glpi*|*snipeit*|*discourse*|*nodebb*|*flarum*|*jitsi*|*jami*|*mumble*|*teamspeak*|*mastodon*|*pleroma*|*misskey*|*apprise*|*listmonk*|*ntfy*|*asterisk*|*freepbx*|*igotify*) echo "Communication" ;;
        # Gaming
        *game*|*steam*|*minecraft*|*factorio*|*terraria*|*valheim*|*ark*|*minetest*|*cs*|*csgo*|*pelican*|*pterodactyl*|*romm*|*crafty*|*retro*|*emul*|*epsxe*) echo "Gaming" ;;
        # Home Automation / IoT
        *home*|*iot*|*zigbee*|*mqtt*|*matter*|*openhab*|*jeedom*|*domoticz*|*iobroker*|*tasmota*|*homebridge*|*esphome*|*deconz*|*nodered*|*scrutiny*|*frigate*|*shinobi*|*motion*eye*|*octoprint*|*magicmirror*|*nxwitness*|*zwave*|*ebusd*|*espconnect*|*fhem*|*evcc*) echo "Home Automation" ;;
        # Business / Finance / ERP / CRM
        *erp*|*crm*|*invoice*|*odoo*|*dolibarr*|*erpnext*|*payment*|*invoicing*|*mafl*|*kimai*|*firefly*|*ezbookkeeping*|*ghostfolio*|*actual*|*budget*|*inventree*|*wealth*) echo "Business" ;;
        # Education / Learning
        *learn*|*course*|*school*|*university*|*edu*|*moodle*) echo "Education" ;;
        # Utilities / Tools
        *tool*|*utility*|*convert*|*pdf*|*stirling*|*cyberchef*|*drawio*|*excalidraw*|*aria*|*guacamole*|*tika*|*apt-cacher*|*bytestash*|*mini-qr*|*qdirstat*|*tldraw*|*hammond*) echo "Utilities" ;;
        # Default
        *) echo "Other" ;;
      esac
      ;;
  esac
}

# ── Brand name lookup ──────────────────────
brand_name() {
  case "$1" in
    postgresql) echo "PostgreSQL" ;;
    mariadb) echo "MariaDB" ;;
    mongodb) echo "MongoDB" ;;
    mysql) echo "MySQL" ;;
    sqlite) echo "SQLite" ;;
    nginxproxymanager) echo "Nginx Proxy Manager" ;;
    nginx-ui) echo "Nginx UI" ;;
    vaultwarden) echo "Vaultwarden" ;;
    n8n) echo "n8n" ;;
    node-red) echo "Node-RED" ;;
    pihole) echo "Pi-hole" ;;
    zigbee2mqtt) echo "Zigbee2MQTT" ;;
    rabbitmq) echo "RabbitMQ" ;;
    uptimekuma) echo "Uptime Kuma" ;;
    adguard) echo "AdGuard Home" ;;
    homeassistant) echo "Home Assistant" ;;
    authelia) echo "Authelia" ;;
    authentik) echo "Authentik" ;;
    keycloak) echo "Keycloak" ;;
    openhab) echo "openHAB" ;;
    rclone) echo "rclone" ;;
    openwebui) echo "Open WebUI" ;;
    prowlarr) echo "Prowlarr" ;;
    overseerr) echo "Overseerr" ;;
    jellyseerr) echo "Jellyseerr" ;;
    sonarr) echo "Sonarr" ;;
    radarr) echo "Radarr" ;;
    lidarr) echo "Lidarr" ;;
    readarr) echo "Readarr" ;;
    whisparr) echo "Whisparr" ;;
    bazarr) echo "Bazarr" ;;
    tautulli) echo "Tautulli" ;;
    ollama) echo "Ollama" ;;
    dockge) echo "Dockge" ;;
    runtipi) echo "Runtipi" ;;
    dozzle) echo "Dozzle" ;;
    komodo) echo "Komodo" ;;
    bitwarden) echo "Bitwarden" ;;
    npmplus) echo "NPMplus" ;;
    phpmyadmin) echo "phpMyAdmin" ;;
    pgadmin) echo "pgAdmin" ;;
    deconz) echo "deCONZ" ;;
    esphome) echo "ESPHome" ;;
    homebridge) echo "Homebridge" ;;
    paperless-ngx) echo "Paperless-ngx" ;;
    paperless-gpt) echo "Paperless-GPT" ;;
    paperless-ai) echo "Paperless-AI" ;;
    freshrss) echo "FreshRSS" ;;
    miniflux) echo "Miniflux" ;;
    komga) echo "Komga" ;;
    navidrome) echo "Navidrome" ;;
    kavita) echo "Kavita" ;;
    audiobookshelf) echo "Audiobookshelf" ;;
    calibre-web) echo "Calibre-Web" ;;
    snipeit) echo "Snipe-IT" ;;
    erpnext) echo "ERPNext" ;;
    mattermost) echo "Mattermost" ;;
    rocketchat) echo "Rocket.Chat" ;;
    jitsi-meet) echo "Jitsi Meet" ;;
    teamspeak-server) echo "TeamSpeak Server" ;;
    qbittorrent) echo "qBittorrent" ;;
    sabnzbd) echo "SABnzbd" ;;
    jackett) echo "Jackett" ;;
    tdarr) echo "Tdarr" ;;
    homarr) echo "Homarr" ;;
    heimdall-dashboard) echo "Heimdall Dashboard" ;;
    nextcloudpi) echo "NextcloudPi" ;;
    filerun) echo "FileRun" ;;
    seafile) echo "Seafile" ;;
    neo4j) echo "Neo4j" ;;
    arangodb) echo "ArangoDB" ;;
    apache-cassandra) echo "Apache Cassandra" ;;
    apache-couchdb) echo "Apache CouchDB" ;;
    clickhouse) echo "ClickHouse" ;;
    influxdb) echo "InfluxDB" ;;
    nextpvr) echo "NextPVR" ;;
    garage) echo "Garage" ;;
    seaweedfs) echo "SeaweedFS" ;;
    sftpgo) echo "SFTPGo" ;;
    duplicati) echo "Duplicati" ;;
    rustdesk) echo "RustDesk" ;;
    rustdeskserver) echo "RustDesk Server" ;;
    onlyoffice) echo "ONLYOFFICE" ;;
    hedgedoc) echo "HedgeDoc" ;;
    code-server) echo "code-server" ;;
    theia) echo "Theia" ;;
    outline) echo "Outline" ;;
    docmost) echo "Docmost" ;;
    linkding) echo "Linkding" ;;
    linkwarden) echo "Linkwarden" ;;
    wallabag) echo "Wallabag" ;;
    readeck) echo "Readeck" ;;
    trilium) echo "Trilium" ;;
    minarca) echo "Minarca" ;;
    syncthing) echo "Syncthing" ;;
    joplin-server) echo "Joplin Server" ;;
    fileflows) echo "FileFlows" ;;
    netdata) echo "Netdata" ;;
    glances) echo "Glances" ;;
    glpi) echo "GLPI" ;;
    oddo|odoo) echo "Odoo" ;;
    librenms) echo "LibreNMS" ;;
    storj) echo "Storj" ;;
    minio) echo "MinIO" ;;
    rustypaste) echo "Rustypaste" ;;
    drawio) echo "draw.io" ;;
    excalidraw) echo "Excalidraw" ;;
    cryptpad) echo "CryptPad" ;;
    emqx) echo "EMQX" ;;
    mosquitto) echo "Mosquitto" ;;
    watchyourlan) echo "WatchYourLAN" ;;
    openwrt) echo "OpenWrt" ;;
    ddclient) echo "ddclient" ;;
    cloudflared) echo "Cloudflared" ;;
    netbird) echo "NetBird" ;;
    headscale) echo "Headscale" ;;
    zerotier-one) echo "ZeroTier One" ;;
    immichframe) echo "ImmichFrame" ;;
    photoprism) echo "PhotoPrism" ;;
    immich) echo "Immich" ;;
    jellyfin) echo "Jellyfin" ;;
    plex) echo "Plex" ;;
    emby) echo "Emby" ;;
    funkwhale) echo "Funkwhale" ;;
    jami) echo "Jami" ;;
    mumble) echo "Mumble" ;;
    byparr) echo "Byparr" ;;
    flaresolverr) echo "FlareSolverr" ;;
    piwigo) echo "Piwigo" ;;
    lychee) echo "Lychee" ;;
    owncloud) echo "ownCloud" ;;
    filebrowser) echo "File Browser" ;;
    kodbox) echo "KodBox" ;;
    bookstack) echo "BookStack" ;;
    wikijs) echo "Wiki.js" ;;
    siyuan) echo "SiYuan" ;;
    memos) echo "Memos" ;;
    logseq) echo "Logseq" ;;
    gitea) echo "Gitea" ;;
    forgejo) echo "Forgejo" ;;
    gogs) echo "Gogs" ;;
    gitea-mirror) echo "Gitea Mirror" ;;
    gitlab) echo "GitLab" ;;
    github-runner) echo "GitHub Runner" ;;
    wordpress) echo "WordPress" ;;
    nextcloud) echo "Nextcloud" ;;
    nocodb) echo "NocoDB" ;;
    baserow) echo "Baserow" ;;
    strapi) echo "Strapi" ;;
    directus) echo "Directus" ;;
    ghost) echo "Ghost" ;;
    kavita) echo "Kavita" ;;
    kometa) echo "Kometa" ;;
    tautulli) echo "Tautulli" ;;
    overseerr) echo "Overseerr" ;;
    jellyseerr) echo "Jellyseerr" ;;
    signal) echo "Signal" ;;
    mongodb) echo "MongoDB" ;;
    meilisearch) echo "Meilisearch" ;;
    qdrant) echo "Qdrant" ;;
    valkey) echo "Valkey" ;;
    keydb) echo "KeyDB" ;;
    dozzle) echo "Dozzle" ;;
    focalboard) echo "Focalboard" ;;
    planka) echo "Planka" ;;
    plane) echo "Plane" ;;
    openproject) echo "OpenProject" ;;
    leantime) echo "Leantime" ;;
    kitematic) echo "Kitematic" ;;
    strikedns) echo "StrikeDNS" ;;
    bind) echo "BIND" ;;
    knot) echo "Knot DNS" ;;
    coredns) echo "CoreDNS" ;;
    unbound) echo "Unbound" ;;
    technitiumdns) echo "Technitium DNS" ;;
    frp) echo "frp" ;;
    rathole) echo "rathole" ;;
    sniproxy) echo "SNI Proxy" ;;
    squid) echo "Squid" ;;
    haproxy) echo "HAProxy" ;;
    zammad) echo "Zammad" ;;
    element) echo "Element" ;;
    synapse) echo "Synapse" ;;
    elementsynapse) echo "Element Synapse" ;;
    mattermost) echo "Mattermost" ;;
    matterbridge) echo "Matterbridge" ;;
    kimai) echo "Kimai" ;;
    searxng) echo "SearXNG" ;;
    whoogle) echo "Whoogle" ;;
    archivebox) echo "ArchiveBox" ;;
    n8n) echo "n8n" ;;
    open-archiver) echo "Open Archiver" ;;
    homarr) echo "Homarr" ;;
    homebox) echo "Homebox" ;;
    homepage) echo "Homepage" ;;
    homer) echo "Homer" ;;
    dashy) echo "Dashy" ;;
    diun) echo "Diun" ;;
    watchtower) echo "Watchtower" ;;
    npmplus) echo "NPMplus" ;;
    phpmyadmin) echo "phpMyAdmin" ;;
    pialert) echo "Pi.Alert" ;;
    binhex) echo "Binhex" ;;
    dab) echo "DAB" ;;
    tinyauth) echo "Tinyauth" ;;
    oauth2-proxy) echo "OAuth2 Proxy" ;;
    crowdsec) echo "CrowdSec" ;;
    wazuh) echo "Wazuh" ;;
    fail2ban) echo "Fail2ban" ;;
    snort) echo "Snort" ;;
    suricata) echo "Suricata" ;;
    arkime) echo "Arkime" ;;
    elastalert) echo "ElastAlert" ;;
    sigmacomputing) echo "Sigma Computing" ;;
    prometheus) echo "Prometheus" ;;
    grafana) echo "Grafana" ;;
    loki) echo "Loki" ;;
    alertmanager) echo "Alertmanager" ;;
    prometheus-blackbox-exporter) echo "Prometheus Blackbox Exporter" ;;
    prometheus-pve-exporter) echo "Prometheus PVE Exporter" ;;
    prometheus-alertmanager) echo "Prometheus Alertmanager" ;;
    thanos) echo "Thanos" ;;
    mimir) echo "Mimir" ;;
    victoriametrics) echo "VictoriaMetrics" ;;
    dozzle) echo "Dozzle" ;;
    speedtest-tracker) echo "Speedtest Tracker" ;;
    librespeed-rust) echo "LibreSpeed Rust" ;;
    glpi) echo "GLPI" ;;
    invtree|inventree) echo "Inventree" ;;
    maintenance) echo "Maintenance" ;;
    omv) echo "OpenMediaVault" ;;
    openmediavault) echo "OpenMediaVault" ;;
    urbackupserver) echo "UrBackup Server" ;;
    arch) echo "Arch" ;;
    solr) echo "Solr" ;;
    openrefine) echo "OpenRefine" ;;
    grocy) echo "Grocy" ;;
    mealie) echo "Mealie" ;;
    tandoor) echo "Tandoor" ;;
    kavita) echo "Kavita" ;;
    borg) echo "BorgBackup" ;;
    borgbackup) echo "BorgBackup" ;;
    restic) echo "restic" ;;
    kopia) echo "Kopia" ;;
    proxmox-backup-server) echo "Proxmox Backup Server" ;;
    proxmox-mail-gateway) echo "Proxmox Mail Gateway" ;;
    proxmox-datacenter-manager) echo "Proxmox Datacenter Manager" ;;
    komodo) echo "Komodo" ;;
    komga) echo "Komga" ;;
    kimai) echo "Kimai" ;;
    joplin-server) echo "Joplin Server" ;;
    focalboard) echo "Focalboard" ;;
    plane) echo "Plane" ;;
    planka) echo "Planka" ;;
    openproject) echo "OpenProject" ;;
    leantime) echo "Leantime" ;;
    dolibarr) echo "Dolibarr" ;;
    erpnext) echo "ERPNext" ;;
    odoo) echo "Odoo" ;;
    kimai) echo "Kimai" ;;
    jami) echo "Jami" ;;
    bilibili) echo "Bilibili" ;;
    doodle) echo "Doodle" ;;
    lobe) echo "LobeHub" ;;
    lobehub) echo "LobeHub" ;;
    lobe-chat) echo "LobeChat" ;;
    librechat) echo "LibreChat" ;;
    simpleicons) echo "Simple Icons" ;;
    gnu-social) echo "GNU Social" ;;
    misskey) echo "Misskey" ;;
    mastodon) echo "Mastodon" ;;
    pleroma) echo "Pleroma" ;;
    akkoma) echo "Akkoma" ;;
    wordpress) echo "WordPress" ;;
    hugo) echo "Hugo" ;;
    jekyll) echo "Jekyll" ;;
    eleventy) echo "Eleventy" ;;
    astro) echo "Astro" ;;
    hexo) echo "Hexo" ;;
    pelican) echo "Pelican" ;;
    nikola) echo "Nikola" ;;
    gitbook) echo "GitBook" ;;
    logseq) echo "Logseq" ;;
    obsidian) echo "Obsidian" ;;
    silverbullet) echo "SilverBullet" ;;
    trilium) echo "Trilium" ;;
    tiddlywiki) echo "TiddlyWiki" ;;
    zim-wiki) echo "Zim Wiki" ;;
    anubis) echo "Anubis" ;;
    vaultwarden) echo "Vaultwarden" ;;
    element) echo "Element" ;;
    element-web) echo "Element Web" ;;
    jami) echo "Jami" ;;
    briar) echo "Briar" ;;
    retroshare) echo "RetroShare" ;;
    tox) echo "Tox" ;;
    toxcore) echo "Tox" ;;
    signal) echo "Signal" ;;
    oxen) echo "Oxen" ;;
    *) return 1 ;;
  esac
}

# ── Description inference ───────────────────
describe() {
  local app="$1" cat="$2"
  case "$app" in
    nginx) echo "Lightweight HTTP and reverse proxy server" ;;
    postgresql|postgres) echo "Powerful open-source relational database" ;;
    mariadb|mysql) echo "Popular open-source relational database" ;;
    redis) echo "In-memory data store and cache" ;;
    valkey) echo "High-performance in-memory data store (Redis fork)" ;;
    mongodb) echo "Document-oriented NoSQL database" ;;
    minio) echo "S3-compatible object storage server" ;;
    ollama) echo "Run large language models locally" ;;
    openwebui) echo "Self-hosted AI chat interface" ;;
    jellyfin|plex|emby) echo "Self-hosted media streaming server" ;;
    immich) echo "Self-hosted photo and video backup" ;;
    photoprism) echo "AI-powered photo management" ;;
    nextcloud) echo "Self-hosted file sync and collaboration" ;;
    vaultwarden) echo "Lightweight password manager (Bitwarden compatible)" ;;
    homeassistant|homebox) echo "Home automation platform" ;;
    pihole|adguard|blocky|coredns) echo "Network-wide ad blocker and DNS server" ;;
    traefik|nginxproxymanager|caddy) echo "Reverse proxy with automatic HTTPS" ;;
    uptimekuma|gatus) echo "Service monitoring and status pages" ;;
    grafana|prometheus|influxdb|loki) echo "Observability stack" ;;
    homarr|heimdall-dashboard|homepage|homer|dashy) echo "Self-hosted dashboard for all your services" ;;
    docker|podman) echo "Container runtime" ;;
    dockge|runtipi|coolify|casaos|dokploy) echo "Self-hosted app deployment platforms" ;;
    pihole|adguard) echo "Network-wide DNS-level ad blocking" ;;
    npmplus|nginx-ui) echo "Web UI for managing Nginx" ;;
    zigbee2mqtt) echo "Zigbee to MQTT bridge for home automation" ;;
    nodebb|discourse|flarum) echo "Self-hosted forum software" ;;
    gitea|forgejo|gogs) echo "Lightweight self-hosted Git service" ;;
    gitea-mirror) echo "Mirror Gitea repositories to other Gitea instances" ;;
    authentik|authelia|keycloak) echo "Identity provider and SSO" ;;
    n8n) echo "Workflow automation tool" ;;
    mealie|tandoor|baserow|kitchenowl) echo "Recipe and meal planning" ;;
    paperless-ngx|paperless-gpt|paperless-ai) echo "Document management and archiving" ;;
    duplicati|restic|rclone) echo "Encrypted backup tools" ;;
    syncthing) echo "Continuous file synchronization" ;;
    seafile) echo "File sync and share platform" ;;
    freshrss|miniflux) echo "Self-hosted RSS feed aggregator" ;;
    wallabag|readeck|linkding|linkwarden) echo "Read-it-later and bookmark manager" ;;
    trilium|joplin-server|siyuan) echo "Personal knowledge base" ;;
    bookstack|dokuwiki|mediawiki|wikijs) echo "Self-hosted wiki" ;;
    it-tools|cyberchef|stirling-pdf) echo "Handy developer and sysadmin utilities" ;;
    changedetection|tracktor) echo "Website change detection" ;;
    whoogle|searxng) echo "Self-hosted search engine" ;;
    kavita|komga|lanraragi) echo "Self-hosted comic/manga/book server" ;;
    navidrome|funkwhale|jellyfin) echo "Self-hosted music streaming" ;;
    lidarr|prowlarr|radarr|readarr|sonarr|whisparr|bazarr) echo "Media automation (*arr suite)" ;;
    overseerr|jellyseerr) echo "Media request and discovery" ;;
    tautulli|tdarr) echo "Media library management" ;;
    handbrake|fileflows) echo "Video transcoding and processing" ;;
    frigate|shinobi|go2rtc|zoneminder) echo "Self-hosted NVR / camera management" ;;
    homebridge) echo "HomeKit bridge for non-HomeKit devices" ;;
    esphome) echo "ESP device firmware builder" ;;
    node-red) echo "Low-code programming for event-driven applications" ;;
    zwave-js-ui) echo "Z-Wave to MQTT gateway" ;;
    mosquitto|mqtt|emqx|hivemq) echo "MQTT message broker" ;;
    wireguard|headscale|netbird|nebula|zerotier-one) echo "Mesh VPN solutions" ;;
    tinyauth) echo "Lightweight authentication proxy" ;;
    oauth2-proxy) echo "Authentication reverse proxy" ;;
    crowdsec) echo "Collaborative security engine" ;;
    fail2ban) echo "Brute force attack protection" ;;
    wazuh|graylog) echo "Security information and event management" ;;
    osquery|velociraptor) echo "Endpoint visibility and forensics" ;;
    metabase|apache-superset) echo "Self-hosted business intelligence" ;;
    nodered|node-red) echo "Visual programming for IoT" ;;
    restic|borgbackup) echo "Encrypted deduplicated backup" ;;
    zammad|glpi|invtree) echo "Helpdesk and ticketing" ;;
    invoice*|invoiceninja|invoiceshelf) echo "Self-hosted invoicing" ;;
    kimai|mafl|anuko) echo "Time tracking" ;;
    wallabag) echo "Read-it-later with annotations" ;;
    traccar) echo "GPS tracking platform" ;;
    zabbix|netdata|prometheus|uptime-kuma|gatus) echo "Infrastructure monitoring" ;;
    uptimekuma) echo "Self-hosted monitoring tool" ;;
    uptime-kuma) echo "Self-hosted monitoring tool" ;;
    speedtest-tracker|librespeed-rust) echo "Internet speed test tracking" ;;
    healthchecks) echo "Cron job monitoring" ;;
    glances|netdata) echo "System monitoring dashboard" ;;
    ntfy) echo "Push notifications server" ;;
    gotify|igotify) echo "Self-hosted push notification server" ;;
    apprise|apprise-api) echo "Notification aggregator" ;;
    stirling-pdf) echo "PDF manipulation toolkit" ;;
    it-tools) echo "Collection of handy IT tools" ;;
    drawio|excalidraw) echo "Diagramming and visual thinking" ;;
    hedgedoc|outline|docusaurus) echo "Collaborative documentation" ;;
    dokuwiki|bookstack|wiki.js|wikijs|mediawiki) echo "Self-hosted wiki" ;;
    leantime|kitematic) echo "Project management and time tracking" ;;
    dolibarr|erpnext|odoo) echo "ERP and CRM suite" ;;
    plane|openproject|kanboard) echo "Project management" ;;
    drawdb|dolibarr) echo "Database design and modeling" ;;
    snipeit|glpi|invtree|inventory) echo "IT asset management" ;;
    zammad) echo "Helpdesk and customer support" ;;
    mattermost|element|rocketchat) echo "Team chat platform" ;;
    element|rocketchat) echo "Team communication platform" ;;
    zammad) echo "Customer support ticketing" ;;
    rss-bridge) echo "RSS feed generator" ;;
    freshrss) echo "Self-hosted RSS reader" ;;
    miniflux) echo "Lightweight RSS reader" ;;
    rabbitmq) echo "Message broker for distributed systems" ;;
    kafka) echo "Distributed event streaming" ;;
    nats) echo "Lightweight message broker" ;;
    beanstalkd) echo "Simple work queue" ;;
    ferretdb) echo "MongoDB-compatible database on Postgres" ;;
    surrealdb) echo "Multi-model database" ;;
    influxdb) echo "Time-series database" ;;
    questdb) echo "Time-series database" ;;
    clickhouse) echo "Column-oriented DBMS for analytics" ;;
    duckdb) echo "In-process analytical database" ;;
    neo4j) echo "Graph database" ;;
    arangodb) echo "Multi-model database" ;;
    apache-cassandra) echo "Distributed NoSQL database" ;;
    apache-couchdb) echo "Document-oriented NoSQL database" ;;
    memcached) echo "Distributed memory caching" ;;
    keydb) echo "High-performance Redis-compatible store" ;;
    dragonfly) echo "Modern in-memory datastore" ;;
    openldap) echo "LDAP directory server" ;;
    radius) echo "RADIUS authentication server" ;;
    openvpn) echo "VPN server" ;;
    pivpn) echo "Simple OpenVPN/WireGuard installer" ;;
    algorand|chia|bitcoin|monero|nano) echo "Cryptocurrency node" ;;
    urbackupserver) echo "Client/server backup system" ;;
    zfsbackup|borgbackup-server) echo "Backup servers" ;;
    borgbackup-server|alpine-borgbackup-server) echo "BorgBackup server" ;;
    proxmox-backup-server) echo "Proxmox's official backup server" ;;
    pbs) echo "Proxmox Backup Server" ;;
    pve-scripts-local) echo "Local Proxmox scripts collection" ;;
    kavita) echo "Cross-platform comic/manga/book server" ;;
    kodi) echo "Media center software" ;;
    osjs) echo "Web-based desktop operating system" ;;
    cockpit) echo "Web-based server management" ;;
    aaPanel|ajenti|cockpit|webmin) echo "Web-based server control panels" ;;
    runtipi) echo "Personal homeserver manager" ;;
    rport) echo "Remote access and management" ;;
    meshcentral) echo "Open-source remote management" ;;
    rustdesk*) echo "Self-hosted remote desktop" ;;
    openssh|sshwifty|shellhub) echo "Web-based SSH terminal" ;;
    netbox|netbox-docker) echo "Network infrastructure management" ;;
    phpipam|netbox) echo "IP address management" ;;
    uisp|unifi*) echo "Ubiquiti network management" ;;
    netdata|librenms|observium|zabbix) echo "Network monitoring" ;;
    patchmon) echo "Patch management dashboard" ;;
    cluster) echo "Container clustering" ;;
    *) echo "" ;;
  esac
}

# ── Generate apps.json (search index) ───────
generate_index_json() {
  local json_file="$DOCS_DIR/apps.json"
  local first=1
  echo "[" > "$json_file"
  
  for f in "$CT_DIR"/*.sh; do
    [ -e "$f" ] || continue
    local app=$(basename "$f" .sh)
    [ "$app" = "headers" ] && continue
    
    # Extract metadata from ct script
    local script_content=$(cat "$f")
    local display=$(echo "$script_content" | grep -E '^APP="[^"]+"' | head -1 | sed 's/^APP="//; s/"$//')
    local brand=$(brand_name "$app")
    [ -n "$brand" ] && display="$brand"
    [ -z "$display" ] && display=$(echo "$app" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
    
    local tags=$(echo "$script_content" | grep -E '^var_tags=' | head -1 | sed 's/.*:-//; s/}".*//')
    local cpu=$(echo "$script_content" | grep -E '^var_cpu=' | head -1 | sed 's/.*:-//; s/}".*//')
    local ram=$(echo "$script_content" | grep -E '^var_ram=' | head -1 | sed 's/.*:-//; s/}".*//')
    local disk=$(echo "$script_content" | grep -E '^var_disk=' | head -1 | sed 's/.*:-//; s/}".*//')
    local os=$(echo "$script_content" | grep -E '^var_os=' | head -1 | sed 's/.*:-//; s/}".*//')
    local version=$(echo "$script_content" | grep -E '^var_version=' | head -1 | sed 's/.*:-//; s/}".*//')
    
    local cat=$(categorize "$app" "$tags")
    local desc=$(describe "$app" "$cat")
    [ -z "$desc" ] && desc="Self-hosted $display instance"
    
    if [ $first -eq 0 ]; then echo "," >> "$json_file"; fi
    first=0
    
    # Escape for JSON
    local esc_desc=$(printf '%s' "$desc" | sed 's/"/\\"/g')
    local esc_tags=$(printf '%s' "$tags" | sed 's/"/\\"/g')
    local esc_cat=$(printf '%s' "$cat" | sed 's/"/\\"/g')
    
    cat >> "$json_file" <<EOF
  {
    "slug": "$app",
    "name": "$display",
    "category": "$esc_cat",
    "description": "$esc_desc",
    "tags": "$esc_tags",
    "cpu": "$cpu",
    "ram": "$ram",
    "disk": "$disk",
    "os": "$os",
    "version": "$version",
    "url": "apps/$app.html"
  }
EOF
  done
  echo "]" >> "$json_file"
  echo "Generated apps.json ($(wc -l < "$json_file") lines)"
}

# ── Generate per-app HTML pages ─────────────
generate_app_pages() {
  local count=0
  for f in "$CT_DIR"/*.sh; do
    [ -e "$f" ] || continue
    local app=$(basename "$f" .sh)
    [ "$app" = "headers" ] && continue
    
    local script_content=$(cat "$f")
    local display=$(echo "$script_content" | grep -E '^APP="[^"]+"' | head -1 | sed 's/^APP="//; s/"$//')
    local brand=$(brand_name "$app")
    [ -n "$brand" ] && display="$brand"
    [ -z "$display" ] && display=$(echo "$app" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
    
    local tags=$(echo "$script_content" | grep -E '^var_tags=' | head -1 | sed 's/.*:-//; s/}".*//')
    local cpu=$(echo "$script_content" | grep -E '^var_cpu=' | head -1 | sed 's/.*:-//; s/}".*//')
    local ram=$(echo "$script_content" | grep -E '^var_ram=' | head -1 | sed 's/.*:-//; s/}".*//')
    local disk=$(echo "$script_content" | grep -E '^var_disk=' | head -1 | sed 's/.*:-//; s/}".*//')
    local os=$(echo "$script_content" | grep -E '^var_os=' | head -1 | sed 's/.*:-//; s/}".*//')
    local version=$(echo "$script_content" | grep -E '^var_version=' | head -1 | sed 's/.*:-//; s/}".*//')
    
    local cat=$(categorize "$app" "$tags")
    local desc=$(describe "$app" "$cat")
    [ -z "$desc" ] && desc="Self-hosted $display instance"
    
    local icon=$(echo "$display" | head -c 1)
    
    # Escape for HTML
    local esc_desc=$(printf '%s' "$desc" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    local esc_tags=$(printf '%s' "$tags" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    
    local install_cmd="bash <(curl -fsSL $RAW/ct/$app.sh)"
    local install_esc=$(printf '%s' "$install_cmd" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    
    local out="$APPS_DIR/$app.html"
    cat > "$out" <<APPEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${display} - Incus Scripts</title>
  <meta name="description" content="$esc_desc">
  <link rel="stylesheet" href="../css/style.css">
</head>
<body>
  <nav class="navbar">
    <div class="navbar-inner">
      <a href="../index.html" class="navbar-brand">
        <svg viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="16" cy="16" r="14" stroke="#58a6ff" stroke-width="2"/><circle cx="16" cy="16" r="6" fill="#4c9b3f"/></svg>
        Incus Scripts
      </a>
      <div class="navbar-search">
        <form action="../index.html" method="get" style="margin: 0;">
          <input type="text" name="q" placeholder="Search 500+ apps... (press /)" onfocus="this.form.action='../index.html#'+this.value">
        </form>
      </div>
      <div class="navbar-links">
        <a href="https://codeberg.org/${REPO}" target="_blank">Codeberg</a>
      </div>
    </div>
  </nav>

  <div class="container">
    <div class="breadcrumb">
      <a href="../index.html">Home</a> / <span>${display}</span>
    </div>

    <header class="app-header">
      <div class="app-icon">${icon}</div>
      <div>
        <h1>${display}</h1>
        <div class="app-subtitle">${cat} · self-hosted</div>
      </div>
    </header>

    <section class="section">
      <h2>Install</h2>
      <p>${esc_desc}</p>
      <div class="code-block" style="margin-top: 14px;">
        <div class="code-block-header">
          <span>One-line install</span>
          <button class="copy-btn" data-copy="${install_cmd}">Copy</button>
        </div>
        <pre><code>${install_esc}</code></pre>
      </div>
    </section>

    <section class="section">
      <h2>Default Resources</h2>
      <table class="var-table">
        <thead><tr><th>Setting</th><th>Default</th><th>Description</th></tr></thead>
        <tbody>
          <tr><td>CPU</td><td>${cpu:-1}</td><td>vCPU cores</td></tr>
          <tr><td>RAM</td><td>${ram:-1024} MiB</td><td>Memory limit</td></tr>
          <tr><td>Disk</td><td>${disk:-10} GiB</td><td>Root filesystem size</td></tr>
          <tr><td>OS</td><td>${os:-ubuntu}</td><td>Base image OS</td></tr>
          <tr><td>Version</td><td>${version:-24.04}</td><td>OS version</td></tr>
        </tbody>
      </table>
    </section>

    <section class="section">
      <h2>Override Variables</h2>
      <p style="color: var(--text-2); font-size: 14px; margin-bottom: 12px;">
        Set any of these before the install command to override defaults:
      </p>
      <div class="code-block">
        <div class="code-block-header">
          <span>Example with overrides</span>
          <button class="copy-btn" data-copy="var_cpu=4 var_ram=4096 var_disk=50 bash &lt;(curl -fsSL $RAW/ct/$app.sh)">Copy</button>
        </div>
        <pre><code>var_cpu=4 var_ram=4096 var_disk=50 bash &lt;(curl -fsSL $RAW/ct/$app.sh)</code></pre>
      </div>
      <table class="var-table" style="margin-top: 14px;">
        <thead><tr><th>Variable</th><th>Type</th><th>Description</th></tr></thead>
        <tbody>
          <tr><td>var_cpu</td><td>integer</td><td>vCPU cores (e.g. 4)</td></tr>
          <tr><td>var_ram</td><td>integer</td><td>RAM in MiB (e.g. 2048)</td></tr>
          <tr><td>var_disk</td><td>integer</td><td>Disk in GiB (e.g. 20)</td></tr>
          <tr><td>var_os</td><td>string</td><td>Base OS: ubuntu, debian, alpine</td></tr>
          <tr><td>var_version</td><td>string</td><td>OS version (e.g. 24.04, 12, 3.20)</td></tr>
          <tr><td>var_instance</td><td>string</td><td>Custom instance name</td></tr>
          <tr><td>var_ipv4</td><td>CIDR</td><td>Static IP (e.g. 10.0.0.50)</td></tr>
          <tr><td>var_profile</td><td>string</td><td>Incus profile to use</td></tr>
        </tbody>
      </table>
    </section>

APPEOF

    # Tags section
    if [ -n "$tags" ]; then
      local tag_html=""
      IFS=',' read -ra TAG_ARR <<< "$tags"
      for tg in "${TAG_ARR[@]}"; do
        local t=$(echo "$tg" | xargs)
        [ -z "$t" ] && continue
        tag_html+="<span class=\"tag\">$(printf '%s' "$t" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')</span>"
      done
      cat >> "$out" <<APPEOF2
    <section class="section">
      <h2>Tags</h2>
      <div class="tag-list">${tag_html}</div>
    </section>

APPEOF2
    fi

    # How it works section
    cat >> "$out" <<APPEOF3
    <section class="section">
      <h2>How it works</h2>
      <ol style="padding-left: 20px; line-height: 1.8;">
        <li>Connects to your Incus host and pulls the <code>$RAW/ct/${app}.sh</code> script</li>
        <li>Sources the build framework (<code>common.sh</code> + <code>incus-build.func</code>)</li>
        <li>Launches a new container with your specified resources</li>
        <li>Pushes the <code>install/${app}-install.sh</code> script into the container</li>
        <li>Installs and configures <strong>${display}</strong> with the upstream-tested install procedure</li>
        <li>Prints the access URL and any credentials on completion</li>
      </ol>
    </section>

    <section class="section">
      <h2>Source files</h2>
      <ul style="list-style: none; display: flex; flex-direction: column; gap: 8px;">
        <li>📄 <a href="https://codeberg.org/${REPO}/src/branch/main/ct/${app}.sh" target="_blank">ct/${app}.sh</a> — host-side launcher</li>
        <li>📄 <a href="https://codeberg.org/${REPO}/src/branch/main/install/${app}-install.sh" target="_blank">install/${app}-install.sh</a> — in-container installer</li>
      </ul>
    </section>
  </div>

  <footer class="footer">
    <p>
      Part of <a href="../index.html">Incus Scripts</a> ·
      Inspired by <a href="https://community-scripts.org" target="_blank">community-scripts.org</a> ·
      <a href="https://codeberg.org/${REPO}" target="_blank">Codeberg</a>
    </p>
  </footer>
  <script src="../js/site.js"></script>
</body>
</html>
APPEOF3

    count=$((count + 1))
  done
  echo "Generated $count app pages"
}

# ── Generate index.html ─────────────────────
generate_index() {
  local json_file="$DOCS_DIR/apps.json"
  local total=$(grep -c '"slug"' "$json_file" 2>/dev/null || echo 0)
  
  cat > "$DOCS_DIR/index.html" <<INDEXEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Incus Scripts - One-command apps for Incus containers</title>
  <meta name="description" content="${total}+ one-command install scripts for Incus containers. Inspired by ProxmoxVE Community Scripts.">
  <link rel="stylesheet" href="css/style.css">
</head>
<body>
  <nav class="navbar">
    <div class="navbar-inner">
      <a href="index.html" class="navbar-brand">
        <svg viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="16" cy="16" r="14" stroke="#58a6ff" stroke-width="2"/><circle cx="16" cy="16" r="6" fill="#4c9b3f"/></svg>
        Incus Scripts
      </a>
      <div class="navbar-search">
        <input type="text" id="search" placeholder="Search ${total}+ apps... (press /)" autocomplete="off">
      </div>
      <div class="navbar-links">
        <a href="https://codeberg.org/${REPO}" target="_blank">Codeberg</a>
        <a href="https://codeberg.org/${REPO}/src/branch/main/README.md" target="_blank">Docs</a>
      </div>
    </div>
  </nav>

  <header class="hero">
    <h1>Incus Scripts</h1>
    <p>One-command application deployment for Incus containers.<br>
       ${total}+ self-hosted services, databases, media servers, and more — all deployable with a single bash command.</p>

    <div class="hero-install">
      <div class="hero-install-label">Try one now</div>
      <div class="code-block">
        <div class="code-block-header">
          <span>PostgreSQL</span>
          <button class="copy-btn" data-copy="bash &lt;(curl -fsSL ${RAW}/ct/postgresql.sh)">Copy</button>
        </div>
        <pre><code>bash &lt;(curl -fsSL ${RAW}/ct/postgresql.sh)</code></pre>
      </div>
    </div>

    <div class="hero-stats">
      <span><strong id="total-count">${total}</strong>apps</span>
      <span><strong id="visible-count">${total}</strong>showing</span>
      <span><strong>1</strong>command deploy</span>
    </div>
  </header>

  <main class="container">
    <div class="filters" id="filters">
      <span class="filters-label">Filter:</span>
      <button class="filter-btn active" data-category="all">All <span class="filter-count">${total}</span></button>
      <button class="filter-btn" data-category="Database">Database</button>
      <button class="filter-btn" data-category="Media">Media</button>
      <button class="filter-btn" data-category="Networking">Networking</button>
      <button class="filter-btn" data-category="Monitoring">Monitoring</button>
      <button class="filter-btn" data-category="Security">Security</button>
      <button class="filter-btn" data-category="Home Automation">Home Automation</button>
      <button class="filter-btn" data-category="AI">AI</button>
      <button class="filter-btn" data-category="Containers">Containers</button>
      <button class="filter-btn" data-category="Dashboards">Dashboards</button>
      <button class="filter-btn" data-category="Cloud & Storage">Cloud & Storage</button>
      <button class="filter-btn" data-category="Development">Development</button>
      <button class="filter-btn" data-category="Productivity">Productivity</button>
      <button class="filter-btn" data-category="Communication">Communication</button>
      <button class="filter-btn" data-category="Gaming">Gaming</button>
      <button class="filter-btn" data-category="Business">Business</button>
      <button class="filter-btn" data-category="Education">Education</button>
      <button class="filter-btn" data-category="Utilities">Utilities</button>
    </div>

    <div class="app-grid" id="app-grid">
INDEXEOF

  # Generate app cards from the json
  python3 -c "
import json
import sys
import html
import os

with open('$json_file') as f:
    apps = json.load(f)

# Sort by name
apps.sort(key=lambda a: a['name'].lower())

for app in apps:
    icon = app['name'][:1].upper()
    name = html.escape(app['name'])
    desc = html.escape(app.get('description', ''))
    cat = html.escape(app.get('category', 'Other'))
    url = app['url']
    slug = app['slug']
    cpu = app.get('cpu', '1')
    ram = app.get('ram', '1024')
    disk = app.get('disk', '10')
    print(f'''      <a class=\"app-card\" href=\"{url}\" data-name=\"{name.lower()}\" data-desc=\"{desc.lower()}\" data-category=\"{cat}\">
        <div class=\"app-category-badge\">{cat}</div>
        <div class=\"app-card-header\">
          <div class=\"app-icon\">{icon}</div>
          <div class=\"app-name\">{name}</div>
        </div>
        <div class=\"app-meta\">
          <span>CPU {cpu}</span>
          <span>{ram}MB</span>
          <span>{disk}GB</span>
        </div>
        <div class=\"app-desc\">{desc}</div>
      </a>''')
" >> "$DOCS_DIR/index.html"

  cat >> "$DOCS_DIR/index.html" <<INDEXEOF2
      <div class="app-empty" style="display: none;">No apps match your search.</div>
    </div>
  </main>

  <footer class="footer">
    <p>
      <strong>Incus Scripts</strong> · ${total} app templates ·
      Inspired by <a href="https://community-scripts.org" target="_blank">community-scripts.org</a> ·
      <a href="https://codeberg.org/${REPO}" target="_blank">View on Codeberg</a>
    </p>
    <p style="margin-top: 8px; opacity: 0.7;">
      Built for <a href="https://linuxcontainers.org/incus/" target="_blank">Incus</a> · MIT License
    </p>
  </footer>

  <script src="js/site.js"></script>
</body>
</html>
INDEXEOF2
  
  echo "Generated index.html"
}

# ── Run ─────────────────────────────────────
echo "==> Generating apps.json..."
generate_index_json
echo "==> Generating per-app pages..."
generate_app_pages
echo "==> Generating index.html..."
generate_index
echo ""
echo "Done! Docs in: $DOCS_DIR"
echo "  Total apps:  $(ls "$APPS_DIR" | wc -l)"
echo "  Index size:  $(wc -l < "$DOCS_DIR/index.html") lines"
echo "  Open:        file://$DOCS_DIR/index.html"
