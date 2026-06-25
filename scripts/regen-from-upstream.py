#!/usr/bin/env python3
"""Generate ct/ and install/ scripts from upstream community-scripts/ProxmoxVE.

This script:
1. Fetches the list of all install/*-install.sh from community-scripts/ProxmoxVE
2. For each, generates a wrapper in install/ that:
   - Sources our compat shim
   - Patches upstream to remove the ProxmoxVE-specific function sourcing
   - evals the upstream
3. Generates a thin launcher in ct/ that:
   - Sources common.sh + incus-build.func
   - Creates the instance
   - Pushes install/<app>-install.sh into the container and runs it
4. Regenerates misc/app-categories.json
5. Regenerates misc/install-wizard.sh (ncurses menu)

The install/ scripts are tiny templates; the heavy lifting is the compat shim.
"""
import os
import sys
import json
import urllib.request
import urllib.error
import re
import time
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).parent.parent
CT_DIR = ROOT / 'ct'
INSTALL_DIR = ROOT / 'install'
MISC_DIR = ROOT / 'misc'

UPSTREAM_REPO = 'community-scripts/ProxmoxVE'
UPSTREAM_API = f'https://api.github.com/repos/{UPSTREAM_REPO}/contents/install'
UPSTREAM_ADDON_API = f'https://api.github.com/repos/{UPSTREAM_REPO}/contents/tools/addon'
UPSTREAM_RAW = f'https://raw.githubusercontent.com/{UPSTREAM_REPO}/main/install'
UPSTREAM_ADDON_RAW = f'https://raw.githubusercontent.com/{UPSTREAM_REPO}/main/tools/addon'

OUR_BASE_DEFAULT = 'https://codeberg.org/luna-dj/incus-scripts/raw/branch/main'

# Apps with custom hand-written install/ scripts. The regen script will
# only update the ct/ launcher for these — never the install/ file.
# Each entry is the app name stem (no .sh, no -install).
CUSTOM_INSTALL_APPS = {
    'mail-archiver',  # Has the arm64 .NET SDK workaround
}

# Apps to skip entirely (don't even generate ct/ for them).
SKIP_APPS = set()

# Addon scripts (require Docker in the container). They live in upstream's
# tools/addon/ directory, not install/. We generate the same wrapper but
# add a Docker install hint in the install/ script.
# Each entry: app_name -> display_name
ADDON_APPS = {
    'arcane': 'Arcane',
    'dockge': 'Dockge',
    'dokploy': 'Dokploy',
    'komodo': 'Komodo',
    'runtipi': 'Runtipi',
    'coolify': 'Coolify',
    'copyparty': 'Copyparty',
    'olivetin': 'OliveTin',
    'phpmyadmin': 'phpMyAdmin',
    'crowdsec': 'CrowdSec',
    'filebrowser': 'Filebrowser',
    'glances': 'Glances',
    'netdata': 'Netdata',
    'webmin': 'Webmin',
    'all-templates': 'All Templates',
}

# ──────────────────────────────────────────────────────────────
# HELPERS
# ──────────────────────────────────────────────────────────────

def fetch_install_list():
    """Fetch list of *-install.sh from upstream."""
    req = urllib.request.Request(UPSTREAM_API, headers={'User-Agent': 'incus-scripts-regen'})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.loads(r.read())
    files = [e['name'] for e in data if e['name'].endswith('-install.sh')]
    return sorted(files)


def fetch_install_content(name):
    """Fetch raw content of one install script from upstream."""
    url = f"{UPSTREAM_RAW}/{name}?t={int(time.time())}"
    req = urllib.request.Request(url, headers={'User-Agent': 'incus-scripts-regen'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode('utf-8', errors='replace')


def app_name_from_install(name):
    """adguard-install.sh -> adguard, Apache-Airflow-install.sh -> apache-airflow"""
    base = name.replace('-install.sh', '')
    return base.lower()


def app_name_from_addon(name):
    """arcane.sh -> arcane, all-templates.sh -> all-templates"""
    return name.replace('.sh', '').lower()


def fetch_addon_list():
    """Fetch list of addon scripts from upstream tools/addon/."""
    try:
        req = urllib.request.Request(UPSTREAM_ADDON_API, headers={'User-Agent': 'incus-scripts-regen'})
        with urllib.request.urlopen(req, timeout=30) as r:
            data = json.loads(r.read())
        files = [e['name'] for e in data if e['name'].endswith('.sh')]
        return sorted(files)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print(f"  WARN: {UPSTREAM_ADDON_API} returned 404 — skipping addon sync")
            return []
        raise


def pretty_name(name):
    """adguard -> Adguard, apache-airflow -> Apache Airflow"""
    return name.replace('-', ' ').title()


# ──────────────────────────────────────────────────────────────
# TEMPLATE RENDERING
# ──────────────────────────────────────────────────────────────

CT_TEMPLATE = '''#!/usr/bin/env bash
# ct/{app}.sh — {pretty}
# Generated for Incus from upstream ProxmoxVE Community Scripts
# Our wrapper code is MIT; upstream content retains its original license.
#
# Set INCUS_BASE to override the raw content provider:
#   INCUS_BASE=https://raw.githubusercontent.com/luna-dj/incus-scripts/main

INCUS_BASE="${{INCUS_BASE:-{our_base}}}"
# Export so it survives subshells (pipes, incus_exec_stdin)
export INCUS_BASE
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${{INCUS_BASE}}/common.sh?v=$(date +%s))"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${{INCUS_BASE}}/misc/incus-build.func?v=$(date +%s))"

APP="{pretty}"
var_tags="${{var_tags:-}}"
var_cpu="${{var_cpu:-1}}"
var_ram="${{var_ram:-1024}}"
var_disk="${{var_disk:-10}}"
var_os="${{var_os:-ubuntu}}"
var_version="${{var_version:-24.04}}"

header_info "$APP"
variables
check_existing_instance
create_instance

# Fetch the install script content on the host, then push it into the
# container and run it with 'bash -s' (which reads the script from stdin).
# We can't use 'bash -c' here because the upstream install scripts start
# with '#!/usr/bin/env bash' which would be treated as a command name.
INSTALL_SCRIPT=$(curl -fsSL --http1.1 "${{INCUS_BASE}}/install/{app}-install.sh" 2>/dev/null) || {{
    log_error "Failed to fetch install script for {app}"
    exit 1
}}
printf '%s\\n' "INCUS_BASE=${{INCUS_BASE}}" "$INSTALL_SCRIPT" | incus_exec_stdin "$var_instance"

IP=$(get_instance_ip "$var_instance")
echo ""
echo -e "${{GR}}{pretty} deployed on ${{var_instance}} (${{IP}})${{NC}}"
echo ""
'''

CT_ADDON_TEMPLATE = (
'''
#!/usr/bin/env bash
# ct/{app}.sh — {pretty} (addon, Docker-based)
# Generated for Incus from upstream ProxmoxVE Community Scripts (tools/addon/)
# Our wrapper code is MIT; upstream content retains its original license.
#
# Set INCUS_BASE to override the raw content provider:
#   INCUS_BASE=https://raw.githubusercontent.com/luna-dj/incus-scripts/main

INCUS_BASE="${{INCUS_BASE:-{our_base}}}"
# Export so it survives subshells (pipes, incus_exec_stdin)
export INCUS_BASE
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${{INCUS_BASE}}/common.sh?v=$(date +%s))"
source /dev/stdin <<<"$(curl -fsSL --http1.1 ${{INCUS_BASE}}/misc/incus-build.func?v=$(date +%s))"

APP="{pretty}"
var_tags="${{var_tags:-}}"
var_cpu="${{var_cpu:-1}}"
var_ram="${{var_ram:-2048}}"
var_disk="${{var_disk:-20}}"
var_nesting="${{var_nesting:-true}}"
var_os="${{var_os:-ubuntu}}"
var_version="${{var_version:-24.04}}"

header_info "$APP"
variables
check_existing_instance
create_instance

# Fetch the install script content on the host, then push it into the
# container and run it with "bash -s" (which reads the script from stdin).
INSTALL_SCRIPT=$(curl -fsSL --http1.1 "${{INCUS_BASE}}/install/{app}-install.sh" 2>/dev/null) || {{
    log_error "Failed to fetch install script for {app}"
    exit 1
}}
printf '%s\n' "INCUS_BASE=${{INCUS_BASE}}" "$INSTALL_SCRIPT" | incus_exec_stdin "$var_instance"

IP=$(get_instance_ip "$var_instance")
echo ""

# Verify the addon's Docker container is actually running. The upstream
# addon can silently exit ("Installation cancelled") if a `read` prompt
# receives empty input — we want to detect that instead of reporting
# success. Poll `docker ps` for up to 60s for a container whose name
# matches the app slug.
if incus_exec_stdin "$var_instance" bash -c '
    for i in $(seq 1 30); do
        if docker ps --format "{{{{.Names}}}}" 2>/dev/null | grep -qi "{app}"; then
            echo "OK"
            exit 0
        fi
        sleep 2
    done
    echo "TIMEOUT"
    exit 1
' 2>/dev/null | grep -q "^OK$"; then
    echo -e "${{GR}}{pretty} deployed on ${{var_instance}} (${{IP}})${{NC}}"
else
    echo -e "${{YL}}{pretty} install did not start a Docker container on ${{var_instance}} (${{IP}}).${{NC}}"
    echo -e "${{YL}}Check: incus exec ${{var_instance}} -- docker ps -a${{NC}}"
    exit 1
fi
echo ""
'''
)

INSTALL_TEMPLATE = '''#!/usr/bin/env bash
# install/{app}-install.sh — {pretty}
# Generated for Incus from upstream ProxmoxVE Community Scripts
# Our wrapper code is MIT; upstream content retains its original license.

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${{INCUS_BASE:-{our_base}}}/misc/incus-install-compat.func?v=$(date +%s))"

header_info "{pretty}"
setting_up_container
network_check
update_os

msg_info "Loading upstream install script for {pretty}"
UPSTREAM_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/{app}-install.sh"
UPSTREAM_SCRIPT=$(curl -fsSL "${{UPSTREAM_URL}}?v=$(date +%s)" 2>/dev/null) || {{
    msg_error "Failed to fetch upstream install script"
    exit 1
}}

# Remove upstream function sourcing (provided by incus-compat)
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//source \\/dev\\/stdin <<<\\"\\$FUNCTIONS_FILE_PATH\\"/: # (functions provided by incus-compat)}}"
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/core.func)/: # (core.func)}}"
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/error_handler.func)/: # (error_handler.func)}}"

# Disable 'set -u' around eval of upstream: the upstream scripts
# use various bash features that may not be safe under strict
# unset-variable mode.
set +u
eval "$UPSTREAM_SCRIPT"
set -u

echo ""
echo -e "${{GR}}{pretty} installation complete!${{NC}}"
echo ""
'''

ADDON_INSTALL_TEMPLATE = '''#!/usr/bin/env bash
# install/{app}-install.sh — {pretty} (addon)
# Generated for Incus from upstream ProxmoxVE Community Scripts (tools/addon/)
# Our wrapper code is MIT; upstream content retains its original license.
#
# Addon scripts require Docker inside the container. Incus containers
# don't ship with Docker, so we install it before eval'ing the upstream.

source /dev/stdin <<<"$(curl -fsSL --http1.1 ${{INCUS_BASE:-{our_base}}}/misc/incus-install-compat.func?v=$(date +%s))"

header_info "{pretty}"
setting_up_container
network_check
update_os

# Addon apps run as Docker containers. Install Docker first.
# Use setup_docker from compat shim (handles Debian/Ubuntu/Alpine).
if ! command -v docker &>/dev/null; then
  msg_info "Installing Docker (required for {pretty} addon)"
  setup_docker
  msg_ok "Docker installed"
fi

# Ensure TERM is set so upstream's `header_info` `clear` command works.
# Inside `incus exec ... bash -s` there is no TTY, so TERM is unset.
# Without TERM, `clear` errors and trips the upstream ERR trap.
TERM="${{TERM:-xterm-256color}}"
export TERM

# Ensure TERM is set so upstream header_info clear command works.
# Inside incus exec bash -s there is no TTY; TERM may be dumb or unset.
# dumb does not know clear, so unconditionally force a real terminal type.
TERM="xterm-256color"
export TERM
shopt -s expand_aliases
alias clear=true

msg_info "Loading upstream addon script for {pretty}"
UPSTREAM_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/{app}.sh"
UPSTREAM_SCRIPT=$(curl -fsSL "${{UPSTREAM_URL}}?v=$(date +%s)" 2>/dev/null) || {{
    msg_error "Failed to fetch upstream addon script"
    exit 1
}}

# Remove upstream function sourcing (provided by incus-compat)
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/core.func)/: # (core.func)}}"
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/tools.func)/: # (tools.func)}}"
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/error_handler.func)/: # (error_handler.func)}}"

# Auto-answer upstream interactive prompts. Addon scripts run inside
# `incus exec ... bash -s` so there is no TTY for `read -r`. Without this
# every prompt receives empty input and the addon exits with "Installation
# cancelled". Force-yes for install/uninstall, force-no for update (we're
# doing a fresh install, not an update).
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//read -r install_prompt/install_prompt=y}}"
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//read -r install_docker_prompt/install_docker_prompt=y}}"
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//read -r update_prompt/update_prompt=n}}"
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//read -r uninstall_prompt/uninstall_prompt=n}}"

# Disable 'set -u' around eval of upstream
set +u
eval "$UPSTREAM_SCRIPT"
set -u

echo ""
echo -e "${{GR}}{pretty} installation complete!${{NC}}"
echo ""
'''


# ──────────────────────────────────────────────────────────────
# CATEGORY MAPPING (mirrors .claude/build-categories.py)
# ──────────────────────────────────────────────────────────────

CATEGORY_RULES = [
    ('AI/ML',       ['ollama', 'comfy', 'stable-diffusion', 'whisper', 'llm', 'openai', 'kohya', 'automatic1111', 'fooocus', 'invokeai', 'comfyui']),
    ('Media',       ['jellyfin', 'plex', 'emby', 'sonarr', 'radarr', 'lidarr', 'readarr', 'prowlarr', 'bazarr', 'kavita', 'audiobookshelf', 'navidrome', 'calibre', 'immich', 'frigate', 'photoprism', 'lychee', 'qbittorrent', 'sabnzbd', 'deluge', 'rtorrent', 'transmission', 'ersatztv', 'tdarr', 'unmanic', 'wyoming', 'piper', 'komga', 'dozzle']),
    ('Productivity',['nextcloud', 'onlyoffice', 'collabora', 'bookstack', 'trilium', 'joplin', 'logseq', 'affine', 'appsmith', 'nocodb', 'baserow', 'vikunja', 'leantime', 'kanboard', 'wekan', 'planka', 'openproject', 'redmine', 'taiga', 'odoo', 'erpnext', 'espocrm', 'vtigercrm', 'invoiceninja', 'kimai', 'wallabag', 'linkwarden', 'linkding', 'hedgedoc', 'etherpad', 'cryptpad', 'paperless']),
    ('Web Servers', ['nginx', 'caddy', 'apache', 'traefik', 'haproxy', 'hestia', 'cyberpanel', 'virtualmin', 'vesta', 'lamp', 'lemp', 'openlitespeed', 'ols', 'swag', 'nginxproxymanager']),
    ('Databases',   ['postgres', 'postgresql', 'mysql', 'mariadb', 'mongodb', 'redis', 'memcached', 'cassandra', 'clickhouse', 'influxdb', 'timescaledb', 'couchdb', 'neo4j', 'arangodb', 'rethinkdb', 'cockroachdb', 'tidb', 'dgraph', 'etcd', 'consul', 'vault']),
    ('Monitoring',  ['grafana', 'prometheus', 'loki', 'tempo', 'mimir', 'thanos', 'uptime-kuma', 'uptimekuma', 'healthchecks', 'changedetection', 'argus', 'autocaliweb', 'beszel', 'checkmk', 'librenms', 'zabbix', 'nagios', 'netdata', 'glances', 'dashdot', 'dashy', 'homepage', 'heimdall', 'monica']),
    ('Development', ['gitea', 'gogs', 'gitlab', 'forgejo', 'phorge', 'phabricator', 'gerrit', 'jenkins', 'drone', 'woodpecker', 'argocd', 'fluxcd', 'rancher', 'portainer', 'k3s', 'k3sup', 'microk8s', 'k0s', 'rke2']),
    ('Security',    ['authelia', 'authentik', 'keycloak', 'zitadel', 'casdoor', 'ory', 'wireguard', 'tailscale', 'headscale', 'netbird', 'zerotier', 'pivpn', 'wg-easy', 'crowdsec', 'fail2ban', 'kanidm', 'passbolt', 'vaultwarden', 'bitwarden', 'psono', 'wazuh', 'velociraptor']),
    ('Networking',  ['pihole', 'adguard', 'adguardhome', 'blocky', 'unbound', 'bind', 'powerdns', 'cloudflared', 'firezone', 'netmaker', 'nebula', 'bmon', 'darkstat', 'socat']),
    ('System',      ['portainer', 'dockge', 'yacht', 'homarr', 'homepage', 'dashy', 'heimdall', 'organizr', 'firefly-iii', 'actual', 'mealie', 'tandoor', 'grocy', 'openhab', 'home-assistant', 'mosquitto', 'zigbee2mqtt', 'webmin', 'cockpit', 'ajenti', 'wordpress', 'joomla']),
    ('Storage',     ['minio', 'nextcloud', 'owncloud', 'seafile', 'filebrowser', 'syncthing', 'filerun', 'seaweedfs', 'sftpgo', 'h5ai', 'glusterfs', 'rook', 'longhorn', 'openebs', 'linstor', 'ceph', 'samba', 'openmediavault', 'rockstor', 'truenas', 'zfs']),
    ('Communication',['matrix', 'synapse', 'element', 'rocket-chat', 'rocketchat', 'mattermost', 'jitsi', 'livekit', 'mumble', 'teamspeak', 'coturn', 'bbb', 'bigbluebutton']),
    ('Containers',  ['docker', 'kubernetes', 'k3s', 'microk8s', 'k0s', 'rke2', 'rancher', 'portainer', 'dockge', 'podman', 'buildah', 'skopeo', 'argocd', 'fluxcd', 'helm', 'kubectl']),
]


def categorize(name):
    nl = name.lower()
    for cat, kws in CATEGORY_RULES:
        for kw in kws:
            if kw in nl:
                return cat
    return 'Other'


# ──────────────────────────────────────────────────────────────
# REGENERATION
# ──────────────────────────────────────────────────────────────

def render_ct(app, pretty):
    return CT_TEMPLATE.format(app=app, pretty=pretty, our_base=OUR_BASE_DEFAULT)


def render_ct_addon(app, pretty):
    return CT_ADDON_TEMPLATE.format(app=app, pretty=pretty, our_base=OUR_BASE_DEFAULT)


def render_install(app, pretty):
    return INSTALL_TEMPLATE.format(app=app, pretty=pretty, our_base=OUR_BASE_DEFAULT)


def render_addon_install(app, pretty):
    return ADDON_INSTALL_TEMPLATE.format(app=app, pretty=pretty, our_base=OUR_BASE_DEFAULT)


def regenerate_addons():
    """Regenerate ct/ and install/ for addon apps (Docker-based)."""
    print(f"\nFetching addon list from {UPSTREAM_REPO}/tools/addon/...")
    files = fetch_addon_list()
    if not files:
        return set()
    print(f"Found {len(files)} addon scripts")

    new_count = 0
    updated_count = 0
    upstream_apps = set()

    for name in files:
        app = app_name_from_addon(name)
        pretty = ADDON_APPS.get(app, pretty_name(app))
        upstream_apps.add(app)

        if app in SKIP_APPS:
            print(f"  SKIP ct/{app}.sh (in SKIP_APPS)")
            continue

        # Generate ct/<app>.sh (addon template with Docker container check)
        ct_path = CT_DIR / f'{app}.sh'
        ct_content = render_ct_addon(app, pretty)

        if ct_path.exists():
            if ct_path.read_text() != ct_content:
                ct_path.write_text(ct_content)
                ct_path.chmod(0o755)
                updated_count += 1
                print(f"  UPD  ct/{app}.sh (addon)")
        else:
            ct_path.write_text(ct_content)
            ct_path.chmod(0o755)
            new_count += 1
            print(f"  NEW  ct/{app}.sh (addon)")

        # Generate install/<app>-install.sh (addon template with Docker pre-install)
        if app in CUSTOM_INSTALL_APPS:
            print(f"  KEEP install/{app}-install.sh (custom)")
            continue

        install_path = INSTALL_DIR / f'{app}-install.sh'
        install_content = render_addon_install(app, pretty)

        if install_path.exists():
            if install_path.read_text() != install_content:
                install_path.write_text(install_content)
                install_path.chmod(0o755)
                print(f"  UPD  install/{app}-install.sh (addon)")
        else:
            install_path.write_text(install_content)
            install_path.chmod(0o755)
            print(f"  NEW  install/{app}-install.sh (addon)")

    print(f"\nAddon summary: {new_count} new, {updated_count} updated")
    return upstream_apps


def regenerate():
    print(f"Fetching install list from {UPSTREAM_REPO}...")
    files = fetch_install_list()
    print(f"Found {len(files)} install scripts")

    new_count = 0
    updated_count = 0
    upstream_apps = set()

    for name in files:
        app = app_name_from_install(name)
        pretty = pretty_name(app)
        upstream_apps.add(app)

        # Generate ct/<app>.sh
        if app in SKIP_APPS:
            print(f"  SKIP ct/{app}.sh (in SKIP_APPS)")
            continue

        ct_path = CT_DIR / f'{app}.sh'
        ct_content = render_ct(app, pretty)

        if ct_path.exists():
            if ct_path.read_text() != ct_content:
                ct_path.write_text(ct_content)
                ct_path.chmod(0o755)
                updated_count += 1
                print(f"  UPD  ct/{app}.sh")
        else:
            ct_path.write_text(ct_content)
            ct_path.chmod(0o755)
            new_count += 1
            print(f"  NEW  ct/{app}.sh")

        # Generate install/<app>-install.sh
        # Skip if app is in CUSTOM_INSTALL_APPS — it has hand-written patches.
        if app in CUSTOM_INSTALL_APPS:
            print(f"  KEEP install/{app}-install.sh (custom)")
            continue

        install_path = INSTALL_DIR / f'{app}-install.sh'
        install_content = render_install(app, pretty)

        if install_path.exists():
            if install_path.read_text() != install_content:
                install_path.write_text(install_content)
                install_path.chmod(0o755)
                print(f"  UPD  install/{app}-install.sh")
        else:
            install_path.write_text(install_content)
            install_path.chmod(0o755)
            print(f"  NEW  install/{app}-install.sh")

    print(f"\nSummary: {new_count} new, {updated_count} updated")
    return upstream_apps


def regenerate_categories(apps):
    cats = defaultdict(list)
    for app in sorted(apps):
        cats[categorize(app)].append(app)

    out = {}
    for cat in sorted(cats.keys(), key=lambda c: -len(cats[c])):
        out[cat] = sorted(cats[cat])

    MISC_DIR.mkdir(parents=True, exist_ok=True)
    (MISC_DIR / 'app-categories.json').write_text(json.dumps(out, indent=2))

    print(f"\nCategories: {len(cats)}")
    for cat, lst in out.items():
        print(f"  {cat:15s} {len(lst):3d} apps")


if __name__ == '__main__':
    # Main install/ apps
    apps = regenerate()
    # Addon apps (Docker-based)
    addon_apps = regenerate_addons()
    # Combined list for categories
    all_apps = apps | addon_apps
    regenerate_categories(all_apps)
    print(f"\n✓ Regenerated {len(all_apps)} apps from upstream ({len(apps)} install + {len(addon_apps)} addon)")
