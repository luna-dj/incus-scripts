#!/usr/bin/env bash
# gen_docs.sh — Generate the static docs site for incus-scripts.
#
# This is a thin shim around the new Python generator at scripts/build-site.py.
# The Python generator reads docs/apps.json (built by scripts/build-apps-json.py)
# and produces:
#   docs/index.html         (homepage: hero, features, filters, app grid)
#   docs/apps/<slug>.html   (per-app pages: spec grid, override vars, install)
#   docs/404.html           (404 fallback)
#
# For the full regen pipeline (ct/ + install/ + apps.json + icons + docs site),
# see scripts/regen-from-upstream.py and the .github/workflows/regen.yml workflow.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "==> Building apps.json from ct/ + community-scripts.org metadata..."
if [[ -f "$ROOT/scripts/build-apps-json.py" ]]; then
  python3 "$ROOT/scripts/build-apps-json.py"
else
  echo "WARNING: scripts/build-apps-json.py not found, reusing existing apps.json" >&2
fi

echo "==> Rendering docs site..."
python3 "$ROOT/scripts/build-site.py"

echo ""
echo "Done! Docs in: $ROOT/docs"
echo "  Total apps:  $(ls "$ROOT/docs/apps" | wc -l | tr -d ' ')"
echo "  Index size:  $(wc -c < "$ROOT/docs/index.html" | tr -d ' ') bytes"
echo "  Open:        file://$ROOT/docs/index.html"
