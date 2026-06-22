#!/usr/bin/env bash
# fix-master.sh — Run on your LOCAL machine (not the server)
# Pushes the bug fix to GitHub so the broken nginxproxymanager.sh works.
#
# This script just helps you run the right commands in the right order.
# You still need SSH or HTTPS credentials configured.

set -e

echo "==> Incus Scripts — push the STD fix"
echo ""
echo "Local repo:  $(pwd)"
echo "Remote:      $(git remote get-url origin)"
echo "Branch:      $(git branch --show-current)"
echo ""
echo "Local commits ready to push:"
git log origin/master..HEAD --oneline 2>/dev/null || git log --oneline -5
echo ""

# Sanity check: verify the local file is fixed
if grep -qE '^\$STD\(\)' misc/incus-compat.func; then
    echo "ERROR: local misc/incus-compat.func still has the broken \$STD() function"
    exit 1
fi
echo "Local incus-compat.func is FIXED (no '\$STD()' function definition)"
echo ""

# Try push
echo "==> Attempting push to origin/master..."
if git push -u origin master 2>&1; then
    echo ""
    echo "Push succeeded!"
    echo ""
    echo "Verify the fix is live:"
    echo "  curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/master/misc/incus-compat.func | grep -E '^STD='"
    echo ""
else
    echo ""
    echo "Push failed (likely auth). Try one of:"
    echo ""
    echo "  Option A: HTTPS with token"
    echo "    git remote set-url origin https://github.com/luna-dj/incus-scripts.git"
    echo "    git push -u origin master"
    echo "    # when prompted: username=luna-dj, password=<personal-access-token>"
    echo ""
    echo "  Option B: Add SSH key to GitHub"
    echo "    ssh-keygen -t ed25519 -C 'luna@luna-dj.dev'"
    echo "    cat ~/.ssh/id_ed25519.pub   # add to https://github.com/settings/keys"
    echo "    git push -u origin master"
    echo ""
    echo "  Option C: Use GitHub CLI"
    echo "    brew install gh && gh auth login"
    echo "    git push -u origin master"
    exit 1
fi
