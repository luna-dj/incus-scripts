#!/usr/bin/env bash
# common.sh — Shared utilities for Incus Helper Scripts
# Copyright (c) 2026 incus-helper-scripts
# License: MIT

set -uo pipefail
# Note: we deliberately do NOT use `set -e` because sourced helper functions
# rely on command exit codes for control flow (e.g. `cmd || true`, `if cmd; then`).
# A failure in `incus launch` should print a clear error, not silently exit.

# Debug: print exit code on error
trap 'echo "DEBUG: error at line $LINENO (exit $?)" >&2' ERR

# ──────────────────────────────────────────────
# COLOR & OUTPUT
# ──────────────────────────────────────────────

if [[ -t 1 ]]; then
  RD='\033[0;31m'
  GR='\033[0;32m'
  YL='\033[0;33m'
  BL='\033[0;34m'
  MG='\033[0;35m'
  CY='\033[0;36m'
  NC='\033[0m' # No Color
  BOLD='\033[1m'
else
  RD='' GR='' YL='' BL='' MG='' CY='' NC='' BOLD=''
fi

log_info()  { echo -e "${BL}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GR}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YL}[WARN]${NC}  $*"; }
log_error() { echo -e "${RD}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${CY}━━━ $* ━━━${NC}"; }
log_debug() { [[ "${DEBUG:-false}" == "true" ]] && echo -e "${MG}[DEBUG]${NC} $*"; }

# ──────────────────────────────────────────────
# ERROR HANDLING
# ──────────────────────────────────────────────

catch_errors() {
  trap 'log_error "Script failed at line $LINENO. Exit code: $?"' ERR
}

# Run a command silently unless DEBUG is true
# Note: STD is a VARIABLE (not function) to match upstream ProxmoxVE
STD="${STD:-silent}"
silent() { "$@" >/dev/null 2>&1; }
# Function form for our own scripts (lowercase to avoid collision)
std() {
  if [[ "${DEBUG:-false}" == "true" ]]; then "$@"
  else "$@" >/dev/null 2>&1; fi
}

# ──────────────────────────────────────────────
# VALIDATION
# ──────────────────────────────────────────────

check_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    log_error "This script must be run as root or with sudo"
    exit 1
  fi
}

check_incus() {
  if ! command -v incus &>/dev/null; then
    log_error "Incus CLI not found. Install it first: https://linuxcontainers.org/incus/docs/main/installing/"
    exit 1
  fi
  log_ok "Incus $(incus --version) detected"
}

check_incus_remote() {
  local remote="${1:-local}"
  if ! incus remote list --format csv 2>/dev/null | grep -q "^${remote},"; then
    log_error "Incus remote '${remote}' not found"
    exit 1
  fi
}

# ──────────────────────────────────────────────
# STRING HELPERS
# ──────────────────────────────────────────────

to_lower() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

sluggify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g; s/^-//; s/-$//'
}

# ──────────────────────────────────────────────
# INCUS HELPERS
# ──────────────────────────────────────────────

# Get default Incus remote name
get_default_remote() {
  incus remote list --format csv 2>/dev/null | grep 'YES' | head -1 | cut -d',' -f1
}

# Check if an instance exists
instance_exists() {
  incus info "$1" &>/dev/null
}

# Wait for instance to be running
wait_for_instance() {
  local name="$1"
  local timeout="${2:-30}"
  local elapsed=0
  while ! incus info "$name" 2>/dev/null | grep -q "Status: Running"; do
    sleep 2
    elapsed=$((elapsed + 2))
    if [[ $elapsed -ge $timeout ]]; then
      log_error "Timeout waiting for instance '${name}' to start"
      return 1
    fi
    log_debug "Waiting for ${name} to start... (${elapsed}s)"
  done
  log_ok "Instance '${name}' is running"
}

# Execute command inside instance
incus_exec() {
  local instance="$1"
  shift
  incus exec "$instance" -- "$@"
}

# Execute a script (read from stdin) inside the instance.
# Usage:
#   echo "$script_content" | incus_exec_stdin <instance>
# This avoids the 'bash -c "..."' shebang-parse bug where the first
# line '#!/usr/bin/env bash' gets treated as a command name.
incus_exec_stdin() {
  local instance="$1"
  incus exec "$instance" -- bash -s
}

# Push file into instance
incus_push() {
  local src="$1"
  local dst="$2"
  local instance="${3}"
  incus file push "$src" "${instance}${dst}"
}

# Pull file from instance
incus_pull() {
  local src="${1}"
  local dst="$2"
  local instance="${3:-}"
  # src format: <instance>/<path>
  incus file pull "${instance}${src}" "$dst"
}

# ──────────────────────────────────────────────
# IMAGE HELPERS
# ──────────────────────────────────────────────

get_image_aliases() {
  incus image list --format csv | cut -d',' -f1 | tr ',' '\n'
}

# Find the best image alias for a given OS/version
resolve_image() {
  # Returns a fully-qualified image reference (with 'images:' prefix).
  # The 'images:' remote is the official Incus image server and works
  # for all standard OS images (ubuntu/24.04, debian/12, alpine/3.20, etc.)
  local os="${1:-ubuntu}"
  local version="${2:-24.04}"
  local variant="${3:-cloud}"

  # Build a list of candidate aliases, in order of preference
  local alias
  for alias in "${os}/${version}/${variant}" "${os}/${version}" "${os}"; do
    # Check local cache first (no network)
    if incus image alias list --format csv 2>/dev/null \
         | tail -n +2 2>/dev/null \
         | grep -q "^${alias},"; then
      echo "${alias}"
      return 0
    fi
  done

  # Default to the images: remote — it has all standard OS images
  echo "images:${os}/${version}"
  return 0
}

# ──────────────────────────────────────────────
# STORAGE HELPERS
# ──────────────────────────────────────────────

get_default_storage() {
  # Get the first storage pool name. Handles multiple incus output formats:
  # 1. CSV without header: "default,dir,,2,CREATED"  (some incus versions)
  # 2. CSV with header:    "NAME,...\ndefault,..."  (newer incus)
  # 3. Table format:       "| default | dir | ..."
  #
  # We try CSV first, then table, and skip lines that look like a CSV header.

  # 1. Try CSV: skip any header line (one with no values OR with "NAME" in field 1)
  local csv_out first_line pool
  csv_out="$(incus storage list --format csv 2>/dev/null)"
  if [[ -n "$csv_out" ]]; then
    first_line="$(echo "$csv_out" | head -1)"
    # A header line has the column name "NAME" in field 1, OR has only column
    # names like "NAME,DESCRIPTION,..." with no real pool data.
    if [[ "$first_line" == NAME* ]] || [[ "$first_line" == *",DRIVER"* ]]; then
      pool="$(echo "$csv_out" | tail -n +2 | grep -v '^[[:space:]]*$' | head -1 | cut -d',' -f1 | tr -d '[:space:]"')"
    else
      pool="$(echo "$csv_out" | grep -v '^[[:space:]]*$' | head -1 | cut -d',' -f1 | tr -d '[:space:]"')"
    fi
    if [[ -n "$pool" ]]; then
      echo "$pool"
      return
    fi
  fi

  # 2. Fall back to table format
  incus storage list 2>/dev/null \
    | grep -E '^\| ' \
    | head -1 \
    | sed -E 's/^\|[[:space:]]+([^|]+).*/\1/' \
    | grep -v '^NAME$'
}

get_default_profile() {
  # Get the first profile name. Same multi-format logic as get_default_storage.
  local csv_out first_line profile
  csv_out="$(incus profile list --format csv 2>/dev/null)"

  if [[ -n "$csv_out" ]]; then
    first_line="$(echo "$csv_out" | head -1)"
    if [[ "$first_line" == NAME* ]] || [[ "$first_line" == *",DESCRIPTION"* ]] || [[ "$first_line" == *",DRIVER"* ]]; then
      profile="$(echo "$csv_out" | tail -n +2 | grep -v '^[[:space:]]*$' | head -1 | cut -d',' -f1 | tr -d '[:space:]"')"
    else
      profile="$(echo "$csv_out" | grep -v '^[[:space:]]*$' | head -1 | cut -d',' -f1 | tr -d '[:space:]"')"
    fi
    if [[ -n "$profile" ]]; then
      echo "$profile"
      return
    fi
  fi

  incus profile list 2>/dev/null \
    | grep -E '^\| ' \
    | head -1 \
    | sed -E 's/^\|[[:space:]]+([^|]+).*/\1/' \
    | grep -v '^NAME$'
}

# ──────────────────────────────────────────────
# NETWORK HELPERS
# ──────────────────────────────────────────────

get_instance_ip() {
  local name="$1"
  incus list --format csv 2>/dev/null | grep "^${name}," | awk -F',' '{print $4}' | xargs
}

get_default_bridge() {
  incus network list --format csv 2>/dev/null | grep -i 'bridge' | head -1 | cut -d',' -f1
}
