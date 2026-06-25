#!/usr/bin/env python3
"""Build apps.json from ct/ scripts using metadata from community-scripts.org.

Reads each ct/*.sh file, extracts APP/var_*/etc metadata, and combines with
icon, install count, and description from CS.org metadata.

Outputs valid JSON to docs/apps.json with all the fields needed for
the search index and per-app card rendering.
"""
import json
import os
import re
import sys
from pathlib import Path


def parse_ct_script(path):
    """Extract metadata from a ct/<app>.sh script."""
    with open(path) as f:
        content = f.read()

    # Extract APP="..." field
    m = re.search(r'^APP="([^"]+)"', content, re.MULTILINE)
    if m:
        display = m.group(1)
    else:
        display = path.stem.replace('-', ' ').title()

    # Extract var_* defaults: var_X="${var_X:-N}"
    defs = {}
    for m in re.finditer(r'^var_(\w+)="\$\{var_\1:-([^}]+)\}"', content, re.MULTILINE):
        key, val = m.group(1), m.group(2)
        defs[key] = val

    return {
        'display': display,
        'tags': defs.get('tags', ''),
        'cpu': defs.get('cpu', '1'),
        'ram': defs.get('ram', '1024'),
        'disk': defs.get('disk', '10'),
        'os': defs.get('os', 'ubuntu'),
        'version': defs.get('version', '24.04'),
    }


def load_cs_metadata():
    """Load community-scripts.org metadata (descriptions, install counts, categories)."""
    path = Path(__file__).parent.parent / 'misc' / 'community-scripts-data.json'
    if not path.exists():
        return {}
    with open(path) as f:
        d = json.load(f)
    return {s['slug']: s for s in d.get('scripts', [])}


def load_icon_mapping():
    """Load icon filename mapping."""
    path = Path(__file__).parent.parent / 'docs' / 'assets' / 'icons' / '_mapping.json'
    if not path.exists():
        return {}
    with open(path) as f:
        d = json.load(f)
    return d.get('mapping', {})


def main():
    root = Path(__file__).parent.parent
    ct_dir = root / 'ct'
    docs_dir = root / 'docs'
    output = docs_dir / 'apps.json'

    cs_data = load_cs_metadata()
    icon_map = load_icon_mapping()

    apps = []
    for f in sorted(ct_dir.glob('*.sh')):
        slug = f.stem
        if slug == 'headers':
            continue

        meta = parse_ct_script(f)
        cs = cs_data.get(slug, {})

        # Matrix bridges and similar federation apps get auto-categorized
        # since they don't appear in community-scripts.org catalog.
        category = cs.get('category', 'Other')
        if category == 'Other':
            category = categorize_unlisted(slug, meta['display'])

        apps.append({
            'slug': slug,
            'name': meta['display'],
            'category': category,
            'description': cs.get('description') or default_description(slug, meta['display']),
            'tags': meta['tags'],
            'cpu': meta['cpu'],
            'ram': meta['ram'],
            'disk': meta['disk'],
            'os': meta['os'],
            'version': meta['version'],
            'icon': icon_map.get(slug, ''),
            'installs_30d': int(cs.get('installs_30d', 0) or 0),
            'url': f'apps/{slug}.html',
        })

    docs_dir.mkdir(parents=True, exist_ok=True)
    with open(output, 'w', encoding='utf-8') as f:
        json.dump(apps, f, indent=2, ensure_ascii=False)
        f.write('\n')

    with_icon = sum(1 for a in apps if a['icon'])
    with_installs = sum(1 for a in apps if a['installs_30d'] > 0)
    print(f"Wrote {output} ({len(apps)} apps, {with_icon} with icons, {with_installs} with install counts)")


def categorize_unlisted(slug, display):
    """Fallback categorization for apps that aren't in community-scripts.org.

    Bridges, federation gateways, and similar Matrix-protocol apps land here
    since they're not part of the CS catalog. We use simple slug/display
    keyword matching — same approach as gen_docs.sh's `categorize()`.
    """
    s = (slug + ' ' + display).lower()

    # Matrix protocol / bridges
    matrix_keys = ('matrix', 'mautrix', 'bridge', 'bifrost', 'heisenbridge',
                   'appservice', 'mx-puppet', 'synapse', 'dendrite')
    if any(k in s for k in matrix_keys):
        return 'Communication'

    # Email
    if any(k in s for k in ('email', 'imap', 'smtp', 'mail-')):
        return 'Email'

    # Reverse proxy / ingress
    if any(k in s for k in ('nginx', 'caddy', 'traefik', 'haproxy',
                           'caddyserver')):
        return 'Networking'

    return 'Other'


def default_description(slug, display):
    """Default description for apps without CS metadata."""
    s = (slug + ' ' + display).lower()
    if any(k in s for k in ('mautrix-telegram',)):
        return 'Bridges Telegram to Matrix — log in with QR, sync chats both ways.'
    if any(k in s for k in ('mautrix-whatsapp',)):
        return 'Bridges WhatsApp multi-device to Matrix via linked-devices QR login.'
    if any(k in s for k in ('mautrix-signal',)):
        return 'Bridges Signal to Matrix via linked-devices QR login.'
    if any(k in s for k in ('mautrix-discord',)):
        return 'Bridges Discord to Matrix using a Discord bot token.'
    if any(k in s for k in ('mautrix-slack', 'mx-puppet-slack')):
        return 'Bridges Slack to Matrix using a Slack app OAuth token.'
    if any(k in s for k in ('mautrix-googlechat',)):
        return 'Bridges Google Chat to Matrix via Google Workspace service account.'
    if any(k in s for k in ('mautrix-meta',)):
        return 'Bridges Facebook Messenger + Instagram to Matrix via cookies.'
    if any(k in s for k in ('mautrix-imessage',)):
        return 'Bridges iMessage to Matrix. Requires macOS host (CoreFoundation APIs).'
    if 'heisenbridge' in s:
        return 'IRC bouncer-style bridge with puppeting — control IRC from Matrix.'
    if 'bifrost' in s:
        return 'XMPP/Jabber gateway — connect to federated XMPP networks from Matrix.'
    if 'appservice-irc' in s:
        return 'Legacy IRC bridge for Matrix — connects to IRC servers as a bot.'
    if 'matrix-appservice-email' in s:
        return 'Email bridge — receive/send Matrix messages via IMAP/SMTP.'
    if 'kakaotalk' in s:
        return 'KakaoTalk bridge for Matrix (Korean users).'
    return f"Self-hosted {display} instance."


if __name__ == '__main__':
    main()
