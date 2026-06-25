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

        apps.append({
            'slug': slug,
            'name': meta['display'],
            'category': cs.get('category', 'Other'),
            'description': cs.get('description', f"Self-hosted {meta['display']} instance"),
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


if __name__ == '__main__':
    main()
