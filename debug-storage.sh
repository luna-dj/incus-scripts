#!/usr/bin/env bash
# debug-storage.sh — Run this on incs-laptop to see what incus outputs
# This will help us figure out why get_default_storage returns empty.

echo "=== incus storage list (table format) ==="
incus storage list

echo ""
echo "=== incus storage list --format csv (raw bytes) ==="
incus storage list --format csv | od -c | head -10

echo ""
echo "=== incus storage list --format csv (with line numbers) ==="
incus storage list --format csv | cat -n

echo ""
echo "=== Simulating our get_default_storage function ==="
result=$(incus storage list --format csv 2>/dev/null \
  | awk 'NR>1 && /[^[:space:]]/' \
  | head -1 \
  | cut -d',' -f1 \
  | tr -d '[:space:]"')
echo "Result: [$result]"
if [[ -z "$result" ]]; then
  echo "EMPTY — this is why the pre-flight fails"
else
  echo "NON-EMPTY — should work"
fi

echo ""
echo "=== Alternative: try --format json ==="
incus storage list --format json 2>/dev/null | head -20

echo ""
echo "=== Try with comma-separated header (no quotes) ==="
incus storage list --format csv 2>/dev/null | while IFS=, read -r name desc driver state; do
  if [[ -n "$name" && "$name" != "NAME" ]]; then
    echo "First valid pool: $name"
    break
  fi
done
