#!/usr/bin/env bash
# tools/incus-list.sh — List all Incus instances with useful info
# Copyright (c) 2026 incus-helper-scripts
# License: MIT
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/tools/incus-list.sh)

echo "┌───────────────────────────────────────────────────────────────┐"
echo "│ Incus Instances                                               │"
echo "├───────────────────────────────────────────────────────────────┤"
printf "│ %-20s %-12s %-8s %-15s │\n" "NAME" "STATUS" "TYPE" "IP"
echo "├───────────────────────────────────────────────────────────────┤"

incus list --format csv 2>/dev/null | while IFS=',' read -r name state type ip; do
  printf "│ %-20s %-12s %-8s %-15s │\n" "$name" "$state" "$type" "$(echo $ip | cut -d' ' -f1)"
done

echo "└───────────────────────────────────────────────────────────────┘"
