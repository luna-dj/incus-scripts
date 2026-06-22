#!/usr/bin/env bash
# fix-compat-local.sh — Patch the local cached incus-compat.func
#
# Problem: $STD was defined as a function in the old incus-compat.func
#          which broke upstream ProxmoxVE install scripts.
# Solution: this script rewrites your local copy of the compat file
#           to use $STD as a variable (matches upstream behavior).
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/master/fix-compat-local.sh)

set -e

COMPAT_URL="https://raw.githubusercontent.com/luna-dj/incus-scripts/master/misc/incus-compat.func"
LOCAL_DIR="${HOME}/.local/share/incus-scripts"
LOCAL_FILE="${LOCAL_DIR}/incus-compat.func"

echo "==> Downloading fixed incus-compat.func..."
mkdir -p "$LOCAL_DIR"
curl -fsSL "$COMPAT_URL" -o "$LOCAL_FILE"
echo "    Saved to: $LOCAL_FILE"

echo ""
echo "==> Verifying fix..."
if grep -qE '^\$STD\(\)' "$LOCAL_FILE"; then
    echo "    ERROR: still contains broken '\$STD()' function definition"
    exit 1
fi

if grep -qE '^STD="silent"' "$LOCAL_FILE"; then
    echo "    OK: '\$STD' is now defined as a variable"
else
    echo "    WARNING: expected 'STD=\"silent\"' not found - check file manually"
fi

echo ""
echo "==> Done!"
echo "    This patch is local-only. The remote is fixed on branch 'master'."
echo ""
echo "    To use the patched file, override the source URL:"
echo "      bash <(curl -fsSL $COMPAT_URL) # verify the new version"
echo ""
echo "    Or, when you push your fix to the remote, the standard command works again:"
echo "      bash <(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/master/ct/<app>.sh)"
echo ""
echo "    Push status: the fix is committed locally (commit 50d4ae1) but not yet"
echo "    pushed to GitHub. Run:"
echo "      git push origin master"
echo ""
