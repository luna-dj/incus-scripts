#!/usr/bin/env bash
# fix-master.sh — Run on your LOCAL machine (not the server)
# Switches the remote to Codeberg and pushes the bug fix.
#
# Why Codeberg? GitHub's raw.githubusercontent.com has aggressive caching
# that serves stale content even after a successful push. Codeberg serves
# files fresh on every request.

set -e

echo "==> Incus Scripts — push the STD fix to Codeberg"
echo ""

# Sanity check: verify the local file is fixed
if grep -qE '^\$STD\(\)' misc/incus-compat.func; then
    echo "ERROR: local misc/incus-compat.func still has the broken \$STD() function"
    exit 1
fi
echo "Local incus-compat.func is FIXED (no '\$STD()' function definition)"
echo ""

# Sanity check: verify local URLs all point to codeberg
if grep -rl 'github.com/luna-dj\|raw.githubusercontent.com/luna-dj' . 2>/dev/null | head -1 | grep -q .; then
    echo "ERROR: some files still reference github.com/luna-dj"
    grep -rl 'github.com/luna-dj\|raw.githubusercontent.com/luna-dj' . 2>/dev/null | head -5
    exit 1
fi
echo "All URLs point to codeberg.org/luna-dj/incus-scripts"
echo ""

# Switch remote
echo "==> Switching remote to Codeberg..."
git remote set-url origin https://codeberg.org/luna-dj/incus-scripts.git
git remote -v
echo ""

# Detect current branch
CURRENT_BRANCH="$(git branch --show-current)"
echo "Current local branch: $CURRENT_BRANCH"
echo ""

# Push
echo "==> Pushing to Codeberg (branch: $CURRENT_BRANCH)..."
if git push -u origin "$CURRENT_BRANCH" 2>&1; then
    echo ""
    echo "Push succeeded!"
    echo ""
    echo "Verify the fix is live:"
    echo "  curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/$CURRENT_BRANCH/misc/incus-compat.func | grep -E '^STD='"
    echo ""
    echo "Then re-run your deploy:"
    echo "  bash <(curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/$CURRENT_BRANCH/ct/nginxproxymanager.sh)"
else
    echo ""
    echo "Push failed. Auth options:"
    echo ""
    echo "  Option A: HTTPS with token"
    echo "    Create a Codeberg token: https://codeberg.org/user/settings/applications"
    echo "    git push -u origin $CURRENT_BRANCH"
    echo "    # username=luna-dj, password=<token>"
    echo ""
    echo "  Option B: Add SSH key"
    echo "    ssh-keygen -t ed25519 -C 'luna@luna-dj.dev'"
    echo "    cat ~/.ssh/id_ed25519.pub   # paste into https://codeberg.org/user/settings/keys"
    echo "    git push -u origin $CURRENT_BRANCH"
    exit 1
fi
