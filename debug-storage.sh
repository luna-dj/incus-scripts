#!/usr/bin/env bash
# debug-storage.sh — Diagnose why get_default_storage returns empty
# Run on incs-laptop to see what incus actually outputs.
#
# Usage:
#   bash <(curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/debug-storage.sh)

set +e

echo "═══════════════════════════════════════════════════════"
echo "  Storage List Diagnostic"
echo "═══════════════════════════════════════════════════════"
echo ""

echo "=== 1. Table format (default) ==="
incus storage list 2>&1
echo "[end of table output]"
echo ""

echo "=== 2. CSV format ==="
incus storage list --format csv 2>&1
echo "[end of CSV output]"
echo ""

echo "=== 3. CSV format with line numbers ==="
incus storage list --format csv 2>/dev/null | cat -n
echo "[end of numbered CSV]"
echo ""

echo "=== 4. JSON format ==="
incus storage list --format json 2>&1 | head -20
echo "[end of JSON]"
echo ""

echo "=== 5. CSV bytes (od -c) ==="
incus storage list --format csv 2>/dev/null | od -c | head -10
echo "[end of od output]"
echo ""

echo "=== 6. Test our get_default_storage function (loaded from common.sh) ==="
source <(curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/common.sh)
result=$(get_default_storage 2>&1)
rc=$?
echo "Return code: $rc"
echo "Result: [$result]"
if [[ -z "$result" ]]; then
  echo "EMPTY — this is why the pre-flight check fails"
else
  echo "NON-EMPTY — should work"
fi
echo ""

echo "=== 7. Workaround (just pass var_storage=default) ==="
echo "If everything else fails, you can bypass the auto-detection:"
echo ""
echo "  var_storage=default bash <(curl -fsSL https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/ct/nginxproxymanager.sh)"
echo ""
