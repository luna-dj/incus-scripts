#!/usr/bin/env bash
# tools/incus-backup.sh — Backup Incus instances
# Copyright (c) 2026 incus-helper-scripts
# License: MIT
#
# Usage:
#   bash <(curl -fsSL .../tools/incus-backup.sh) [instance_name|--all]
#   BACKUP_DIR=/path/to/backups bash <(curl ...) --all

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/var/backups/incus}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if ! command -v incus &>/dev/null; then
  echo "ERROR: incus CLI not found"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

backup_instance() {
  local name="$1"
  local backup_file="${BACKUP_DIR}/${name}_${TIMESTAMP}.tar.gz"
  echo "Backing up: ${name}"
  incus export "$name" "$backup_file"
  echo "  -> ${backup_file} ($(du -h "$backup_file" | cut -f1))"
}

if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]]; then
  echo "Usage: $0 [instance_name|--all]"
  echo ""
  echo "  BACKUP_DIR=/path/to/backups $0 --all"
  exit 0
fi

if [[ "$1" == "--all" ]]; then
  echo "Backing up all instances to ${BACKUP_DIR}..."
  incus list --format csv | cut -d',' -f1 | while read -r name; do
    backup_instance "$name"
  done
else
  backup_instance "$1"
fi

echo ""
echo "Done! Backups in: ${BACKUP_DIR}"
