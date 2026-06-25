#!/usr/bin/env python3
"""Download and cache app icons from selfhst/icons via jsdelivr CDN.

Source data: misc/community-scripts-data.json (has 'logo' URLs)
Output: docs/assets/icons/<slug>.<ext>
Mapping: docs/assets/icons/_mapping.json (slug -> icon file)

The icon URLs come from CS metadata. We download all unique icons
(541 across 602 apps), then build a slug->file mapping that gen_docs.sh
can use directly.

Apps without an icon get a generic placeholder (the brand initial).
"""
import json
import os
import re
import urllib.request
import urllib.error
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).parent.parent
MISC_DIR = ROOT / 'misc'
ASSETS_DIR = ROOT / 'docs' / 'assets' / 'icons'
MAPPING_FILE = ASSETS_DIR / '_mapping.json'
CDN_BASE = 'https://cdn.jsdelivr.net/gh/selfhst/icons@main/webp'

# Apps with no direct CS icon — fallback to a known good icon
# (used to fill gaps for alpine-* and custom apps)
ICON_FALLBACKS = {
    'alpine-adguard': 'adguard-home.webp',
    'alpine-bitmagnet': 'bitmagnet.webp',
    'alpine-caddy': 'caddy.webp',
    'alpine-cinny': 'cinny.webp',
    'alpine-docker': 'docker.webp',
    'alpine-forgejo': 'forgejo.webp',
    'alpine-garage': 'garage.webp',
    'alpine-gatus': 'gatus.webp',
    'alpine-gitea': 'gitea.webp',
    'alpine-grafana': 'grafana.webp',
    'alpine-ironclaw': 'ironclaw.webp',
    'alpine-it-tools': 'it-tools.webp',
    'alpine-loki': 'loki.webp',
    'alpine-mariadb': 'mariadb.webp',
    'alpine-nextcloud': 'nextcloud.webp',
    'alpine-node-red': 'node-red.webp',
    'alpine-ntfy': 'ntfy.webp',
    'alpine-postgresql': 'postgresql.webp',
    'alpine-prometheus': 'prometheus.webp',
    'alpine-rclone': 'rclone.webp',
    'alpine-redlib': 'libreddit.webp',
    'alpine-rustdeskserver': 'rustdesk.webp',
    'alpine-rustypaste': 'rusty-paste.webp',
    'alpine-syncthing': 'syncthing.webp',
    'alpine-teamspeak-server': 'teamspeak.webp',
    'alpine-tinyauth': 'tinyauth.webp',
    'alpine-traefik': 'traefik.webp',
    'alpine-transmission': 'transmission.webp',
    'alpine-valkey': 'valkey.webp',
    'alpine-vaultwarden': 'vaultwarden.webp',
    'alpine-wakapi': 'wakapi.webp',
    'alpine-wireguard': 'wireguard.webp',
    'alpine-zigbee2mqtt': 'zigbee2mqtt.webp',
    'alpine-redis': 'redis.webp',
    'mail-archiver': 'mailcow.webp',
    'bichon': 'beehive.webp',  # Bichon is a manga reader, fallback
    'git-pages': 'forgejo.webp',
    'hoodik': 'cryptpad.webp',  # encrypted storage fallback
    'jellyseerr': 'overseerr.webp',  # jellyseerr is overseerr fork
    'netvisor': 'homepage.webp',  # network dashboard
    'nginx': 'nginx.webp',  # check if exists
    'mysql': 'mariadb.webp',  # mysql client
    'apache-airflow': 'airflow.webp',  # check
}


def slug_to_fallback(slug):
    """Try to find a reasonable fallback icon for a slug that has no direct match.
    Strips common prefixes and tries variations."""
    # Strip alpine- prefix
    if slug.startswith('alpine-'):
        return f"{slug[7:]}.webp"
    return f"{slug}.webp"


def load_cs_data():
    """Load community-scripts.org metadata."""
    path = MISC_DIR / 'community-scripts-data.json'
    if not path.exists():
        print(f"WARN: {path} not found — run scripts/sync-cs-metadata.py first")
        return {}
    with open(path) as f:
        return json.load(f)


def extract_logo_url(logo_field):
    """Convert a CS logo field to a selfhst icon URL.

    CS logo field examples:
      'requested'         — no logo yet
      'https://cdn.jsdelivr.net/.../nextcloud.webp' — direct URL
      '/path/to/icon.svg' — relative path (rare)
    """
    if not logo_field or logo_field == 'requested':
        return None
    if logo_field.startswith('http'):
        return logo_field
    if logo_field.startswith('/'):
        return f"https://cdn.jsdelivr.net/gh/selfhst/icons@main{logo_field}"
    return None


def build_slug_to_icon(data):
    """Build slug -> icon URL mapping."""
    mapping = {}

    # 1. Apps with explicit logos in CS data
    for s in data.get('scripts', []):
        slug = s['slug']
        url = extract_logo_url(s.get('logo', ''))
        if url:
            mapping[slug] = url

    # 2. Apply fallbacks for known apps without CS icons
    for slug, icon_file in ICON_FALLBACKS.items():
        if slug not in mapping:
            mapping[slug] = f"{CDN_BASE}/{icon_file}"

    return mapping


def download_icons(mapping, force=False):
    """Download all unique icon files. Returns slug -> local_filename mapping."""
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)

    # Group by URL to dedupe downloads
    url_to_slugs = defaultdict(list)
    for slug, url in mapping.items():
        url_to_slugs[url].append(slug)

    print(f"Downloading {len(url_to_slugs)} unique icons for {len(mapping)} apps...")

    downloaded = 0
    failed = 0
    failed_urls = []
    slug_to_file = {}

    for url, slugs in url_to_slugs.items():
        # Extract filename from URL
        filename = url.split('/')[-1]
        local_path = ASSETS_DIR / filename

        if local_path.exists() and not force:
            downloaded += 1
        else:
            try:
                req = urllib.request.Request(
                    url,
                    headers={'User-Agent': 'incus-scripts-icons/1.0'}
                )
                with urllib.request.urlopen(req, timeout=15) as r:
                    data = r.read()
                if len(data) < 100:
                    print(f"  SKIP {url}: only {len(data)} bytes")
                    failed += 1
                    failed_urls.append(url)
                    continue
                local_path.write_bytes(data)
                downloaded += 1
            except (urllib.error.URLError, urllib.error.HTTPError) as e:
                print(f"  FAIL {url}: {e}")
                failed += 1
                failed_urls.append(url)
                continue

        for slug in slugs:
            slug_to_file[slug] = filename

    print(f"  Downloaded: {downloaded}, Failed: {failed}")
    if failed_urls:
        print(f"  Failed URLs saved to {ASSETS_DIR}/_failed.txt")
        (ASSETS_DIR / '_failed.txt').write_text('\n'.join(failed_urls))

    return slug_to_file


def write_mapping(slug_to_file):
    """Write the slug -> file mapping as JSON for gen_docs.sh to consume."""
    out = {
        'version': 1,
        'source': 'selfhst/icons via jsdelivr',
        'total_apps': len(slug_to_file),
        'mapping': dict(sorted(slug_to_file.items())),
    }
    MAPPING_FILE.write_text(json.dumps(out, indent=2))
    print(f"  Wrote {MAPPING_FILE}")


def main():
    data = load_cs_data()
    mapping = build_slug_to_icon(data)
    print(f"Built slug->icon mapping for {len(mapping)} apps")

    slug_to_file = download_icons(mapping)
    write_mapping(slug_to_file)

    # Coverage stats
    from pathlib import Path
    ct_slugs = {f.stem for f in (ROOT / 'ct').glob('*.sh')}
    with_icon = ct_slugs & set(slug_to_file.keys())
    without_icon = ct_slugs - set(slug_to_file.keys())
    print(f"\nCoverage: {len(with_icon)}/{len(ct_slugs)} ct/ apps have icons")
    if without_icon:
        print(f"Without icons: {len(without_icon)}")
        for s in sorted(without_icon)[:10]:
            print(f"  {s}")


if __name__ == '__main__':
    main()
