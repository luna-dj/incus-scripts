#!/usr/bin/env python3
"""Sync metadata from community-scripts.org to incus-scripts.

Fetches the live scripts catalog from community-scripts.org (Next.js
embedded JSON), then writes a JSON file with enriched metadata for
each script: name, category, description, install counts, has_arm, etc.

This metadata is consumed by:
- gen_docs.sh (to render richer per-app pages with descriptions + categories)
- misc/app-categories.json (replaces the heuristic categorization
  with the official upstream categorization)
- README.md (to show popular apps in the docs site)

Output: misc/community-scripts-data.json
"""
import re
import json
import urllib.request
import urllib.error
from pathlib import Path

ROOT = Path(__file__).parent.parent
MISC_DIR = ROOT / 'misc'

URL = 'https://community-scripts.org/scripts'
OUTPUT = MISC_DIR / 'community-scripts-data.json'


def fetch_page():
    """Fetch the /scripts page and return the embedded RSC payload."""
    req = urllib.request.Request(URL, headers={'User-Agent': 'incus-scripts-sync/1.0'})
    with urllib.request.urlopen(req, timeout=30) as r:
        content = r.read().decode('utf-8', errors='replace')
    return content


def extract_data(content):
    """Extract the Next.js RSC payload containing scripts + categories.

    The page embeds the data as escaped JSON inside:
        1:"<escaped-json-payload>"
    where the payload is a serialized RSC stream with initData.
    """
    # Find all escaped strings (bounded by unescaped ")
    chunks = []
    i = 0
    while i < len(content):
        if content[i] == '\\' and i + 1 < len(content) and content[i + 1] == '"':
            j = i + 2
            while j < len(content):
                if content[j] == '\\' and j + 1 < len(content) and content[j + 1] in ('"', '\\'):
                    j += 2
                elif content[j] == '"':
                    chunks.append((i, j + 1))
                    i = j + 1
                    break
                else:
                    j += 1
            else:
                break
        else:
            i += 1

    # Find the chunk with installCount30d + totalInstalls
    for s, e in chunks:
        substr = content[s:e]
        if 'installCount30d' in substr and 'totalInstalls' in substr:
            decoded = substr[2:-1].encode().decode('unicode_escape')
            obj_start = decoded.find('{')
            obj_end = decoded.rfind('}')
            json_str = decoded[obj_start:obj_end + 1]
            return json.loads(json_str)
    raise RuntimeError("Could not find scripts payload in page")


def transform(raw):
    """Flatten the nested data into per-script metadata."""
    init = raw.get('initData', {})
    cat_map = {c['id']: c['name'] for c in init.get('categories', [])}

    scripts = []
    for s in init.get('scripts', []):
        cats = s.get('expand', {}).get('categories', [])
        cat_name = cats[0].get('name', 'Miscellaneous') if cats else 'Miscellaneous'
        slug = s.get('slug', '')
        scripts.append({
            'slug': slug,
            'name': s.get('name', slug),
            'category': cat_name,
            'description': s.get('description', '').replace('\\r\\n', '\n'),
            'has_arm': s.get('has_arm', False),
            'privileged': s.get('privileged', False),
            'is_dev': s.get('is_dev', False),
            'logo': s.get('logo', ''),
            'updated': s.get('script_updated', s.get('updated', '')),
            'created': s.get('script_created', s.get('created', '')),
            'execute_in': s.get('execute_in', []),
            'raw_categories': s.get('categories', []),
        })

    # Add install counts
    popular = {p['slug']: p.get('installCount30d', 0) for p in init.get('popularStats', [])}
    for s in scripts:
        s['installs_30d'] = popular.get(s['slug'], 0)

    # Sort by popularity
    scripts.sort(key=lambda s: -s['installs_30d'])

    return {
        'categories': [
            {'id': c['id'], 'name': c['name'], 'icon': c.get('icon', ''),
             'description': c.get('description', ''), 'sort_order': c.get('sort_order', 0)}
            for c in init.get('categories', [])
        ],
        'scripts': scripts,
        'totalInstalls': init.get('totalInstalls', 0),
        'totalScripts': len(scripts),
    }


def write_categories(data):
    """Write misc/app-categories.json merging CS.org + our local apps.

    Strategy:
    1. Use CS.org's official categorization for all 602 CS apps
    2. Add any local ct/ apps that aren't in CS to the 'Other' bucket
       (preserves our custom apps like alpine-*, mail-archiver, etc.)
    3. Update doc scripts consume this via simple slug lookup
    """
    # Initialize all CS categories (including ones we don't yet have apps in)
    cs_cats = {c['name']: [] for c in data['categories']}
    cs_cats['Other'] = []

    # 1. Categorize CS apps using their official categories
    cs_slugs = set()
    for s in data['scripts']:
        cat = s['category']
        cs_slugs.add(s['slug'])
        if cat in cs_cats:
            cs_cats[cat].append(s['slug'])
        else:
            cs_cats['Other'].append(s['slug'])

    # 2. Add our local apps not in CS to 'Other'
    ct_dir = ROOT / 'ct'
    if ct_dir.exists():
        our_slugs = {f.stem for f in ct_dir.glob('*.sh')}
        not_in_cs = our_slugs - cs_slugs
        for slug in not_in_cs:
            cs_cats.setdefault('Other', []).append(slug)
        if not_in_cs:
            print(f"\n  Local apps not in CS.org: {len(not_in_cs)}")
            sample = sorted(not_in_cs)[:10]
            print(f"    {', '.join(sample)}{'...' if len(not_in_cs) > 10 else ''}")

    # Sort categories by count desc; remove empty ones
    out = {}
    for cat in sorted(cs_cats.keys(), key=lambda c: -len(cs_cats[c])):
        if cs_cats[cat]:
            out[cat] = sorted(cs_cats[cat])

    out_path = MISC_DIR / 'app-categories.json'
    out_path.write_text(json.dumps(out, indent=2))
    print(f"\nWrote {out_path}")
    for cat, slugs in out.items():
        print(f"  {cat:30s} {len(slugs):3d} apps")
    print(f"  {'TOTAL':30s} {sum(len(v) for v in out.values()):3d} apps")


def main():
    print(f"Fetching {URL}...")
    content = fetch_page()
    print(f"Page: {len(content):,} bytes")

    raw = extract_data(content)
    print(f"Found {len(raw.get('initData', {}).get('scripts', []))} scripts in payload")

    data = transform(raw)
    print(f"\nTotal installs (30d): {data['totalInstalls']:,}")
    print(f"Total scripts: {data['totalScripts']}")
    print(f"Categories: {len(data['categories'])}")

    # Top 5 most installed
    print("\nTop 5 most installed (30d):")
    for s in data['scripts'][:5]:
        print(f"  {s['slug']:25s} {s['installs_30d']:6d} - {s['name']}")

    MISC_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(data, indent=2, ensure_ascii=False))
    print(f"\nWrote {OUTPUT} ({OUTPUT.stat().st_size:,} bytes)")

    write_categories(data)


if __name__ == '__main__':
    main()
