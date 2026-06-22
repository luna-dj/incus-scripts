#!/usr/bin/env bash
# tools/incus-update-all.sh — Update all Incus instances
# Copyright (c) 2026 incus-helper-scripts
# License: MIT
#
# Usage:
#   bash <(curl -fsSL .../tools/incus-update-all.sh)
#   DRY_RUN=true bash <(curl ...)

set -euo pipefail

DRY_RUN="${DRY_RUN:-false}"
RD='\033[0;31m'
GR='\033[0;32m'
YL='\033[0;33m'
NC='\033[0m'

echo -e "${YL}┌─────────────────────────────────────────────┐${NC}"
echo -e "${YL}│${NC}  Incus Update All                           ${YL}│${NC}"
echo -e "${YL}└─────────────────────────────────────────────┘${NC}"
echo ""

[[ "$DRY_RUN" == "true" ]] && echo -e "${YL}DRY RUN MODE - no changes will be made${NC}" && echo ""

incus list --format csv 2>/dev/null | while IFS=',' read -r name state type ip; do
  if [[ "$state" != "Running" ]]; then
    echo -e "${YL}Skipping ${name} (status: ${state})${NC}"
    return
  fi
  echo -e "${GR}Updating: ${name}${NC}"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  Would run: apt update && apt upgrade -y"
  else
    incus exec "$name" -- apt-get update -qq 2>/dev/null || true
    incus exec "$name" -- apt-get upgrade -y -qq 2>/dev/null || true
    echo -e "${GR}  -> Done${NC}"
  fi
done

echo ""
echo "Update complete!"
