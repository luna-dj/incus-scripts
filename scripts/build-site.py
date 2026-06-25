#!/usr/bin/env python3
"""Build the new incus-scripts docs site.

Reads:
- docs/apps.json                  (built by build-apps-json.py)
- docs/assets/icons/*.webp        (cached icons)
- docs/assets/logo.svg            (new logo)

Writes:
- docs/index.html                 (homepage)
- docs/apps/<slug>.html           (per-app pages, 571 of them)
- docs/404.html                   (auto-redirects to /)

Design goals:
- Professional dark theme, real logo, modern typography
- Sticky filter bar with category pills
- Lazy-revealed app cards (IntersectionObserver)
- Per-app pages with hero, spec grid, override vars, install command
- Provider switcher (Codeberg ↔ GitHub) baked into JS
- Search via / keyboard shortcut
- No build step, no framework, no JS deps
"""
import json
import html
import os
import re
import sys
from pathlib import Path
from collections import Counter
from urllib.parse import quote

ROOT = Path(__file__).parent.parent
DOCS = ROOT / 'docs'
APPS_JSON = DOCS / 'apps.json'
ICONS = DOCS / 'assets' / 'icons'
ASSETS = DOCS / 'assets'
OUTPUT_INDEX = DOCS / 'index.html'
APPS_DIR = DOCS / 'apps'
OUTPUT_404 = DOCS / '404.html'

REPO = "luna-dj/incus-scripts"
CODEBERG_CT = lambda s: f"https://codeberg.org/{REPO}/raw/branch/main/ct/{s}.sh"
GITHUB_CT   = lambda s: f"https://raw.githubusercontent.com/{REPO}/main/ct/{s}.sh"


# ──────────────────────────── HTML HELPERS ────────────────────────────

def esc(s):
    """HTML-escape a string. None-safe."""
    if s is None:
        return ''
    return html.escape(str(s), quote=True)


def fmt_count(n):
    """113 -> '113', 1234 -> '1.2k', 12345 -> '12k'."""
    if not n:
        return '0'
    n = int(n)
    if n >= 100_000:
        return f"{n/1000:.0f}k"
    if n >= 10_000:
        return f"{n/1000:.0f}k"
    if n >= 1_000:
        return f"{n/1000:.1f}k"
    return str(n)


def icon_url(slug, icon_name):
    """Resolve icon path, with fallback to nothing (CSS will show letter)."""
    if not icon_name:
        return None
    if icon_name.startswith('http'):
        return icon_name
    return f"assets/icons/{icon_name}"


ONERROR_SNIPPET = 'onerror="this.replaceWith(document.createTextElement(this.alt||this.dataset.fallback||\'?\'))"'


def app_card(app):
    """Render a single app card for the grid."""
    slug = esc(app['slug'])
    name = esc(app['name'])
    desc = esc((app.get('description') or '').strip())
    cat = esc(app.get('category') or 'Other')
    installs = fmt_count(app.get('installs_30d') or 0)
    icon = icon_url(app['slug'], app.get('icon'))
    fallback_letter = esc(name[0] if name else '?')

    if icon:
        # Use data-fallback for the JS onerror to grab; otherwise the img shows nothing
        icon_html = (
            f'<img src="{esc(icon)}" alt="{fallback_letter}" loading="lazy" '
            f'data-fallback="{fallback_letter}" {ONERROR_SNIPPET}>'
        )
    else:
        icon_html = f'<span class="fallback">{fallback_letter}</span>'

    return f'''      <a class="app-card" href="apps/{slug}.html"
         data-name="{esc(app["name"])}"
         data-desc="{esc((app.get("description") or "").lower())}"
         data-category="{cat}">
        <div class="app-card-icon">{icon_html}</div>
        <div class="app-card-name">{name}</div>
        <div class="app-card-desc">{desc}</div>
        <div class="app-card-meta">
          <span class="cat">{cat}</span>
          <span class="installs" title="Installs last 30 days">↓ {installs}</span>
        </div>
      </a>'''


# ──────────────────────────── NAVBAR (shared) ────────────────────────────

NAVBAR_LINKS_INDEX = '''        <a href="#apps" data-mobile-nav>Apps</a>
        <a href="#how" data-mobile-nav>How it works</a>
        <a href="https://codeberg.org/{REPO}" target="_blank" rel="noopener">Codeberg ↗</a>
        <a href="https://github.com/{REPO}" target="_blank" rel="noopener">GitHub ↗</a>'''


def navbar_index(total):
    """Navbar for the homepage."""
    return f'''  <nav class="navbar" id="navbar">
    <div class="navbar-inner">
      <button class="navbar-burger" id="nav-burger" aria-label="Open menu" aria-expanded="false">
        <span></span><span></span><span></span>
      </button>
      <a href="index.html" class="navbar-brand">
        <img src="assets/logo.svg" alt="incus-scripts">
      </a>
      <div class="navbar-nav">
{NAVBAR_LINKS_INDEX.format(REPO=REPO)}
      </div>
      <div class="navbar-right">
        <div class="navbar-search">
          <svg class="search-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
          </svg>
          <input type="text" id="search" placeholder="Search {total} apps…" autocomplete="off" spellcheck="false">
          <kbd>/</kbd>
        </div>
        <button class="navbar-icon-btn" id="search-toggle" aria-label="Search apps">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
          </svg>
        </button>
        <select id="provider-select" class="provider-select" title="Raw content provider">
          <option value="codeberg">Codeberg</option>
          <option value="github">GitHub</option>
        </select>
      </div>
    </div>
  </nav>

  <!-- Mobile drawer -->
  <div class="drawer-backdrop" id="drawer-backdrop"></div>
  <aside class="drawer" id="drawer" aria-hidden="true">
    <div class="drawer-header">
      <a href="index.html" class="navbar-brand">
        <img src="assets/logo.svg" alt="incus-scripts">
      </a>
      <button class="drawer-close" id="drawer-close" aria-label="Close menu">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <line x1="6" y1="6" x2="18" y2="18"/><line x1="6" y1="18" x2="18" y2="6"/>
        </svg>
      </button>
    </div>
    <nav class="drawer-nav" id="drawer-nav">
      <a href="#apps" data-mobile-nav>📦 Apps</a>
      <a href="#how" data-mobile-nav>⚙️ How it works</a>
      <a href="https://codeberg.org/{REPO}" target="_blank" rel="noopener">↗ Codeberg</a>
      <a href="https://github.com/{REPO}" target="_blank" rel="noopener">↗ GitHub</a>
    </nav>
    <div class="drawer-section">
      <div class="drawer-section-label">Raw provider</div>
      <select id="drawer-provider" class="drawer-provider">
        <option value="codeberg">Codeberg</option>
        <option value="github">GitHub</option>
      </select>
    </div>
    <div class="drawer-section">
      <button class="drawer-search-btn" id="drawer-search-btn">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
        </svg>
        Search apps
      </button>
    </div>
  </aside>

  <!-- Mobile search overlay -->
  <div class="search-overlay" id="search-overlay" aria-hidden="true">
    <div class="search-overlay-bar">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
      </svg>
      <input type="text" id="search-overlay-input" placeholder="Search {total} apps…" autocomplete="off" spellcheck="false">
      <button class="search-overlay-close" id="search-overlay-close" aria-label="Close search">✕</button>
    </div>
    <div class="search-overlay-results" id="search-overlay-results"></div>
  </div>

  <!-- Mobile filter sheet (homepage only) -->
  <div class="sheet-backdrop" id="filter-sheet-backdrop"></div>
  <div class="sheet" id="filter-sheet" aria-hidden="true">
    <div class="sheet-handle"></div>
    <div class="sheet-header">
      <h3>Categories</h3>
      <button class="sheet-close" id="filter-sheet-close" aria-label="Close">✕</button>
    </div>
    <div class="sheet-body" id="filter-sheet-body"></div>
  </div>'''


def navbar_app(slug):
    """Navbar for a per-app page."""
    return f'''  <nav class="navbar" id="navbar">
    <div class="navbar-inner">
      <button class="navbar-burger" id="nav-burger" aria-label="Open menu" aria-expanded="false">
        <span></span><span></span><span></span>
      </button>
      <a href="../index.html" class="navbar-brand">
        <img src="../assets/logo.svg" alt="incus-scripts">
      </a>
      <div class="navbar-nav">
        <a href="../index.html#apps">All apps</a>
        <a href="https://codeberg.org/{REPO}/raw/branch/main/ct/{esc(slug)}.sh" target="_blank" rel="noopener">View script</a>
        <a href="https://codeberg.org/{REPO}/raw/branch/main/install/{esc(slug)}-install.sh" target="_blank" rel="noopener">View installer</a>
      </div>
      <div class="navbar-right">
        <div class="navbar-search">
          <svg class="search-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
          </svg>
          <input type="text" id="search" placeholder="Search…" autocomplete="off" spellcheck="false">
        </div>
        <button class="navbar-icon-btn" id="search-toggle" aria-label="Search apps">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
          </svg>
        </button>
        <select id="provider-select" class="provider-select" title="Raw content provider">
          <option value="codeberg">Codeberg</option>
          <option value="github">GitHub</option>
        </select>
      </div>
    </div>
  </nav>

  <!-- Mobile drawer -->
  <div class="drawer-backdrop" id="drawer-backdrop"></div>
  <aside class="drawer" id="drawer" aria-hidden="true">
    <div class="drawer-header">
      <a href="../index.html" class="navbar-brand">
        <img src="../assets/logo.svg" alt="incus-scripts">
      </a>
      <button class="drawer-close" id="drawer-close" aria-label="Close menu">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <line x1="6" y1="6" x2="18" y2="18"/><line x1="6" y1="18" x2="18" y2="6"/>
        </svg>
      </button>
    </div>
    <nav class="drawer-nav" id="drawer-nav">
      <a href="../index.html#apps" data-mobile-nav>📦 All apps</a>
      <a href="https://codeberg.org/{REPO}/raw/branch/main/ct/{esc(slug)}.sh" target="_blank" rel="noopener">↗ View script</a>
      <a href="https://codeberg.org/{REPO}/raw/branch/main/install/{esc(slug)}-install.sh" target="_blank" rel="noopener">↗ View installer</a>
      <a href="https://codeberg.org/{REPO}" target="_blank" rel="noopener">↗ Codeberg</a>
      <a href="https://github.com/{REPO}" target="_blank" rel="noopener">↗ GitHub</a>
    </nav>
    <div class="drawer-section">
      <div class="drawer-section-label">Raw provider</div>
      <select id="drawer-provider" class="drawer-provider">
        <option value="codeberg">Codeberg</option>
        <option value="github">GitHub</option>
      </select>
    </div>
    <div class="drawer-section">
      <button class="drawer-search-btn" id="drawer-search-btn">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
        </svg>
        Search apps
      </button>
    </div>
  </aside>

  <!-- Mobile search overlay -->
  <div class="search-overlay" id="search-overlay" aria-hidden="true">
    <div class="search-overlay-bar">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
      </svg>
      <input type="text" id="search-overlay-input" placeholder="Search apps…" autocomplete="off" spellcheck="false">
      <button class="search-overlay-close" id="search-overlay-close" aria-label="Close search">✕</button>
    </div>
    <div class="search-overlay-results" id="search-overlay-results"></div>
  </div>'''


# ──────────────────────────── INDEX PAGE ────────────────────────────

def render_index(apps):
    total = len(apps)
    cats = Counter(a.get('category') or 'Other' for a in apps)
    sorted_cats = sorted(cats.items(), key=lambda x: -x[1])

    # Top 3 most-installed apps for the hero install picker
    top = sorted([a for a in apps if a.get('installs_30d')], key=lambda a: -a['installs_30d'])[:5]
    if not top:
        top = apps[:5]
    hero_pick = top[0]
    hero_cmd = f'bash <(curl -fsSL {CODEBERG_CT(hero_pick["slug"])})'

    # Featured / category chips
    filter_btns = [f'      <button class="filter-btn active" data-category="All">All <span class="filter-count">{total}</span></button>']
    for cat, n in sorted_cats:
        filter_btns.append(
            f'      <button class="filter-btn" data-category="{esc(cat)}">'
            f'{esc(cat)} <span class="filter-count">{n}</span></button>'
        )

    cards = '\n'.join(app_card(a) for a in sorted(apps, key=lambda a: a['name'].lower()))

    html_doc = f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>incus-scripts — one-command app deployment for Incus</title>
  <meta name="description" content="{total} self-hosted apps deployable to Incus containers with a single bash command. Inspired by ProxmoxVE Community Scripts.">
  <meta name="theme-color" content="#0b0f17">
  <link rel="icon" type="image/svg+xml" href="assets/logo-mark.svg">
  <meta property="og:title" content="incus-scripts — one-command app deployment for Incus">
  <meta property="og:description" content="{total} self-hosted apps. One command. Done.">
  <meta property="og:image" content="assets/logo-mark.svg">
  <link rel="stylesheet" href="css/site.css">
</head>
<body>

{navbar_index(total)}

  <header class="hero">
    <div class="hero-inner">
      <img class="hero-logo" src="assets/logo.svg" alt="incus-scripts">

      <h1>One command.<br><span class="gradient">{total} apps. Zero config.</span></h1>
      <p class="hero-tagline">
        Deploy self-hosted services into <strong>Incus</strong> containers with a single
        bash command. No dashboards, no YAML, no YAML-dashboards either.
      </p>

      <div class="hero-install" data-install-slug="{esc(hero_pick['slug'])}">
        <div class="hero-install-label">Try it now</div>
        <div class="code-block">
          <div class="code-block-header">
            <span class="dots"><span></span><span></span><span></span></span>
            <span style="flex:1; text-align:left; padding-left:8px;">{esc(hero_pick['name'])} · one-line install</span>
            <button class="copy-btn" data-copy="{esc(hero_cmd)}">Copy</button>
          </div>
          <pre><code><span class="prompt">$ </span><span class="url">bash</span> &lt;(curl -fsSL {esc(CODEBERG_CT(hero_pick['slug']))})</code></pre>
        </div>
      </div>

      <div class="hero-stats">
        <div class="hero-stat">
          <span class="num"><span class="gradient" id="total-count">{total}</span></span>
          <span class="label">Apps ready</span>
        </div>
        <div class="hero-stat">
          <span class="num">1</span>
          <span class="label">Command deploy</span>
        </div>
        <div class="hero-stat">
          <span class="num"><span class="gradient">0</span></span>
          <span class="label">Config files</span>
        </div>
        <div class="hero-stat">
          <span class="num">2×</span>
          <span class="label">Mirrors (CB+GH)</span>
        </div>
      </div>
    </div>
  </header>

  <section class="features">
    <div class="features-grid">
      <div class="feature">
        <div class="feature-icon">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/>
          </svg>
        </div>
        <h3>One-line install</h3>
        <p>Every app is a single bash + curl. No clone, no dependencies, no config to write. Just paste and run.</p>
      </div>
      <div class="feature">
        <div class="feature-icon">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/>
            <rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/>
          </svg>
        </div>
        <h3>Mirrored everywhere</h3>
        <p>Synced daily from <a href="https://community-scripts.org" target="_blank">community-scripts.org</a>.
        Hosted on both Codeberg and GitHub. Pick whichever is faster from your region.</p>
      </div>
      <div class="feature">
        <div class="feature-icon">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 2L2 7l10 5 10-5-10-5z"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/>
          </svg>
        </div>
        <h3>Real containers</h3>
        <p>Each app runs in its own Incus container with proper resource limits, OS, and version pinning.
        Override anything via <code>var_*</code> env vars.</p>
      </div>
    </div>
  </section>

  <section class="section" id="apps">
    <div class="section-head">
      <h2>All apps</h2>
      <span class="count"><span id="visible-count">{total}</span> of {total} showing</span>
    </div>

    <div class="filters-wrap">
      <div class="filters" id="filters">
        <span class="filter-label">Filter</span>
{chr(10).join(filter_btns)}
        <button class="filter-mobile-btn" id="filter-mobile-btn" aria-label="Browse categories">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="4" y1="6" x2="20" y2="6"/><line x1="4" y1="12" x2="14" y2="12"/><line x1="4" y1="18" x2="10" y2="18"/>
          </svg>
          <span>Categories</span>
          <span class="filter-mobile-count" id="filter-mobile-count"></span>
        </button>
      </div>
    </div>

    <div class="app-grid" id="app-grid">
{cards}
    </div>

    <div id="app-grid-empty" class="app-grid-empty" style="display:none">
      <h3>No apps match your search</h3>
      <p>Try a different keyword, or clear the filter to see all {total} apps.</p>
    </div>
  </section>

  <section class="section" id="how">
    <div class="section-head"><h2>How it works</h2></div>
    <div class="container" style="max-width:880px; padding:0 24px;">
      <p style="color:var(--text-2); font-size:15.5px; line-height:1.7; margin-bottom:18px;">
        Each app is two scripts: a <code>ct/&lt;app&gt;.sh</code> that runs on your Incus host (creates the
        container, sets resources, pipes in the installer) and an <code>install/&lt;app&gt;-install.sh</code>
        that runs inside the container (installs the app, configures it, starts the service).
      </p>
      <p style="color:var(--text-2); font-size:15.5px; line-height:1.7; margin-bottom:18px;">
        Resource defaults (CPU, RAM, disk, OS, version) are exposed as <code>var_*</code> env vars and
        can be overridden inline:
      </p>
      <div class="code-block" style="margin-bottom:18px;">
        <div class="code-block-header">
          <span class="dots"><span></span><span></span><span></span></span>
          <span style="flex:1; text-align:left; padding-left:8px;">Override defaults</span>
          <button class="copy-btn" data-copy="var_cpu=4 var_ram=4096 var_disk=50 bash &lt;(curl -fsSL {esc(CODEBERG_CT(hero_pick['slug']))})">Copy</button>
        </div>
        <pre><code><span class="prompt">$ </span><span class="url">var_cpu</span>=4 <span class="url">var_ram</span>=4096 <span class="url">var_disk</span>=50 bash &lt;(curl -fsSL {esc(CODEBERG_CT(hero_pick['slug']))})</code></pre>
      </div>
      <p style="color:var(--text-2); font-size:15.5px; line-height:1.7;">
        Browse the full list above, or jump straight to one of the most popular:
        {', '.join(f'<a href="apps/{esc(a["slug"])}.html">{esc(a["name"])}</a>' for a in top[:5])}.
      </p>
    </div>
  </section>

  <footer class="footer">
    <div class="footer-inner">
      <div class="footer-brand">
        <img src="assets/logo.svg" alt="incus-scripts">
        <p>One-command application deployment for Incus containers. Inspired by the ProxmoxVE Community Scripts.</p>
      </div>
      <div>
        <h4>Project</h4>
        <ul>
          <li><a href="https://codeberg.org/{REPO}" target="_blank" rel="noopener">Codeberg →</a></li>
          <li><a href="https://github.com/{REPO}" target="_blank" rel="noopener">GitHub →</a></li>
          <li><a href="https://community-scripts.org" target="_blank" rel="noopener">Upstream →</a></li>
        </ul>
      </div>
      <div>
        <h4>Resources</h4>
        <ul>
          <li><a href="https://linuxcontainers.org/incus/docs/main/" target="_blank" rel="noopener">Incus docs →</a></li>
          <li><a href="https://linuxcontainers.org/incus/docs/main/installing/" target="_blank" rel="noopener">Install Incus →</a></li>
          <li><a href="https://linuxcontainers.org/" target="_blank" rel="noopener">linuxcontainers.org →</a></li>
        </ul>
      </div>
      <div>
        <h4>Stats</h4>
        <ul style="color:var(--text-3); font-size:13px;">
          <li>{total} apps</li>
          <li>{len([c for c, n in sorted_cats])} categories</li>
          <li>Updated daily</li>
        </ul>
      </div>
    </div>
    <div class="footer-bottom">
      <span>MIT licensed · {total} apps · maintained by luna-dj</span>
      <span><a href="https://codeberg.org/{REPO}/issues" target="_blank" rel="noopener">Report an issue →</a></span>
    </div>
  </footer>

  <script src="js/site.js"></script>
</body>
</html>
'''
    OUTPUT_INDEX.write_text(html_doc)


# ──────────────────────────── PER-APP PAGE ────────────────────────────

def render_app_page(app):
    slug = app['slug']
    name = esc(app['name'])
    desc_raw = (app.get('description') or '').strip()
    desc = esc(desc_raw)
    cat = esc(app.get('category') or 'Other')
    icon = icon_url(slug, app.get('icon'))
    cpu = app.get('cpu') or '1'
    ram = app.get('ram') or '512'
    disk = app.get('disk') or '4'
    os_ = esc(app.get('os') or 'ubuntu')
    ver = esc(app.get('version') or '24.04')
    installs = app.get('installs_30d') or 0
    tags = app.get('tags') or ''

    icon_html = (
        f'<img src="../{esc(icon)}" alt="" loading="lazy" {ONERROR_SNIPPET}>'
        if icon else f'<span class="fallback">{name[0] if name else "?"}</span>'
    )

    # Override vars block
    var_rows = f'''<div class="var-row"><span class="var-name">var_cpu</span><span class="var-default">{esc(cpu)}</span><span class="var-desc">vCPU cores</span></div>
      <div class="var-row"><span class="var-name">var_ram</span><span class="var-default">{esc(ram)}</span><span class="var-desc">Memory (MiB)</span></div>
      <div class="var-row"><span class="var-name">var_disk</span><span class="var-default">{esc(disk)}</span><span class="var-desc">Disk (GiB)</span></div>
      <div class="var-row"><span class="var-name">var_os</span><span class="var-default">{os_}</span><span class="var-desc">Base image OS</span></div>
      <div class="var-row"><span class="var-name">var_version</span><span class="var-default">{ver}</span><span class="var-desc">OS version</span></div>'''

    install_cmd = f'bash <(curl -fsSL {CODEBERG_CT(slug)})'
    override_cmd = f'var_cpu=4 var_ram=4096 var_disk=50 {install_cmd}'

    # Tags
    tag_html = ''
    if tags:
        tag_list = [t.strip() for t in re.split(r'[,;]', tags) if t.strip()]
        if tag_list:
            tag_html = '<div class="app-tags">' + ''.join(f'<span class="app-tag">{esc(t)}</span>' for t in tag_list) + '</div>'

    # Description (escape, then add paragraph breaks on double newlines if any)
    desc_html = '<p>' + desc.replace('\n\n', '</p><p>') + '</p>' if desc else ''

    return f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <title>{name} — incus-scripts</title>
  <meta name="description" content="{desc[:200]}">
  <meta name="theme-color" content="#0b0f17">
  <link rel="icon" type="image/svg+xml" href="../assets/logo-mark.svg">
  <link rel="stylesheet" href="../css/site.css">
</head>
<body>

{navbar_app(slug)}

  <main class="app-page">
    <div class="crumbs">
      <a href="../index.html">Home</a>
      <span class="sep">/</span>
      <a href="../index.html#cat={quote(cat, safe='')}">{cat}</a>
      <span class="sep">/</span>
      <span style="color:var(--text-2)">{name}</span>
    </div>

    <header class="app-page-header">
      <div class="app-page-icon">{icon_html}</div>
      <div class="app-page-title">
        <h1>{name}</h1>
        <div class="subtitle">{cat} · {esc(fmt_count(installs))} installs (30d)</div>
        <div class="badge-row">
          <span class="badge badge-primary">{os_} {ver}</span>
          {f'<span class="badge badge-accent">{esc(fmt_count(installs))} installs / 30d</span>' if installs else ''}
        </div>
      </div>
    </header>

    <section class="app-section">
      <h2>About</h2>
      {desc_html}
    </section>

    <section class="app-section">
      <h2>Install</h2>
      <div class="code-block" data-install-slug="{esc(slug)}">
        <div class="code-block-header">
          <span class="dots"><span></span><span></span><span></span></span>
          <span style="flex:1; text-align:left; padding-left:8px;">One-line install</span>
          <button class="copy-btn" data-copy="{esc(install_cmd)}">Copy</button>
        </div>
        <pre><code><span class="prompt">$ </span><span class="url">bash</span> &lt;(curl -fsSL {esc(CODEBERG_CT(slug))})</code></pre>
      </div>
    </section>

    <section class="app-section">
      <h2>Default resources</h2>
      <div class="spec-grid">
        <div class="spec">
          <div class="spec-label">CPU</div>
          <div class="spec-value">{esc(cpu)}<small>vCPU</small></div>
        </div>
        <div class="spec">
          <div class="spec-label">RAM</div>
          <div class="spec-value">{esc(ram)}<small>MiB</small></div>
        </div>
        <div class="spec">
          <div class="spec-label">Disk</div>
          <div class="spec-value">{esc(disk)}<small>GiB</small></div>
        </div>
        <div class="spec">
          <div class="spec-label">OS</div>
          <div class="spec-value" style="font-size:15px;">{os_} {ver}</div>
        </div>
      </div>
    </section>

    <section class="app-section">
      <h2>Override variables</h2>
      <p style="color:var(--text-2); font-size:14px; margin-bottom:12px;">
        Set any of these before the install command to override defaults:
      </p>
      <div class="app-vars">{var_rows}</div>
      <div class="code-block" style="margin-top:14px;">
        <div class="code-block-header">
          <span class="dots"><span></span><span></span><span></span></span>
          <span style="flex:1; text-align:left; padding-left:8px;">Example with overrides</span>
          <button class="copy-btn" data-copy="{esc(override_cmd)}">Copy</button>
        </div>
        <pre><code><span class="prompt">$ </span><span class="url">var_cpu</span>=4 <span class="url">var_ram</span>=4096 <span class="url">var_disk</span>=50 {esc(install_cmd)}</code></pre>
      </div>
    </section>
    {f'<section class="app-section"><h2>Tags</h2>{tag_html}</section>' if tag_html else ''}

    <section class="app-section" style="margin-top:36px;">
      <a href="../index.html#apps" class="btn btn-ghost">← Back to all apps</a>
    </section>
  </main>

  <!-- Mobile bottom action bar -->
  <div class="action-bar" data-app-slug="{esc(slug)}">
    <button class="action-bar-btn action-bar-primary" data-copy="{esc(install_cmd)}">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/></svg>
      <span>Copy install</span>
    </button>
    <a class="action-bar-btn action-bar-secondary" href="https://codeberg.org/{REPO}/raw/branch/main/ct/{esc(slug)}.sh" target="_blank" rel="noopener">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
      <span>Script</span>
    </a>
    <a class="action-bar-btn action-bar-secondary" href="https://codeberg.org/{REPO}/raw/branch/main/install/{esc(slug)}-install.sh" target="_blank" rel="noopener">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="8 17 12 11 16 17"/><line x1="12" y1="11" x2="12" y2="21"/><path d="M20.88 18.09A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.29"/></svg>
      <span>Installer</span>
    </a>
  </div>

  <footer class="footer">
    <div class="footer-inner">
      <div class="footer-brand">
        <img src="../assets/logo.svg" alt="incus-scripts">
        <p>One-command application deployment for Incus containers.</p>
      </div>
      <div>
        <h4>Project</h4>
        <ul>
          <li><a href="https://codeberg.org/{REPO}" target="_blank" rel="noopener">Codeberg →</a></li>
          <li><a href="https://github.com/{REPO}" target="_blank" rel="noopener">GitHub →</a></li>
        </ul>
      </div>
      <div>
        <h4>Resources</h4>
        <ul>
          <li><a href="https://linuxcontainers.org/incus/" target="_blank" rel="noopener">Incus →</a></li>
          <li><a href="https://community-scripts.org" target="_blank" rel="noopener">Upstream →</a></li>
        </ul>
      </div>
      <div>
        <h4>This app</h4>
        <ul style="color:var(--text-3); font-size:13px;">
          <li><a href="https://codeberg.org/{REPO}/raw/branch/main/ct/{esc(slug)}.sh" target="_blank" rel="noopener">ct/{esc(slug)}.sh</a></li>
          <li><a href="https://codeberg.org/{REPO}/raw/branch/main/install/{esc(slug)}-install.sh" target="_blank" rel="noopener">install/{esc(slug)}-install.sh</a></li>
        </ul>
      </div>
    </div>
    <div class="footer-bottom">
      <span>MIT licensed · maintained by luna-dj</span>
      <span><a href="https://codeberg.org/{REPO}/issues" target="_blank" rel="noopener">Report an issue →</a></span>
    </div>
  </footer>

  <script src="../js/site.js"></script>
</body>
</html>
'''


# ──────────────────────────── 404 ────────────────────────────

def render_404():
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>404 — incus-scripts</title>
  <link rel="icon" type="image/svg+xml" href="assets/logo-mark.svg">
  <link rel="stylesheet" href="css/site.css">
  <style>
    body { display:flex; align-items:center; justify-content:center; min-height:100vh; padding:24px; }
    .nf { text-align:center; max-width:480px; }
    .nf h1 { font-size:120px; font-weight:800; letter-spacing:-4px; line-height:1;
      background: linear-gradient(135deg, var(--primary), var(--accent));
      -webkit-background-clip:text; -webkit-text-fill-color:transparent; }
    .nf h2 { font-size:24px; margin:12px 0 8px; }
    .nf p { color:var(--text-2); margin-bottom:24px; }
  </style>
</head>
<body>
  <div class="nf">
    <h1>404</h1>
    <h2>App not found</h2>
    <p>This app doesn't exist (yet) or the URL got mistyped. Head back to the directory to find what you need.</p>
    <a href="index.html" class="btn">← Browse all apps</a>
  </div>
</body>
</html>
'''


# ──────────────────────────── MAIN ────────────────────────────

def main():
    if not APPS_JSON.exists():
        print(f"ERROR: {APPS_JSON} not found. Run scripts/build-apps-json.py first.", file=sys.stderr)
        sys.exit(1)

    apps = json.loads(APPS_JSON.read_text())
    print(f"Loaded {len(apps)} apps from {APPS_JSON}")

    # Check icon directory exists
    if not ICONS.exists():
        print(f"WARNING: {ICONS} not found. Icons will be missing.", file=sys.stderr)

    APPS_DIR.mkdir(exist_ok=True)

    # Render index
    print(f"Rendering {OUTPUT_INDEX}…")
    render_index(apps)
    print(f"  → {OUTPUT_INDEX.stat().st_size:,} bytes")

    # Render per-app pages
    print(f"Rendering {len(apps)} app pages to {APPS_DIR}/…")
    total_bytes = 0
    for app in apps:
        page = APPS_DIR / f"{app['slug']}.html"
        page.write_text(render_app_page(app))
        total_bytes += page.stat().st_size
    print(f"  → {len(apps)} pages, ~{total_bytes:,} bytes total")

    # 404
    OUTPUT_404.write_text(render_404())
    print(f"  → {OUTPUT_404.stat().st_size:,} bytes (404)")

    print("Done.")


if __name__ == '__main__':
    main()
