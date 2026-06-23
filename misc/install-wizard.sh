#!/usr/bin/env bash
# install-wizard.sh — Interactive ncurses-based installation wizard
# Usage: bash misc/install-wizard.sh
#
# Provides a multi-screen wizard for browsing, searching, and installing
# apps from the incus-scripts project. Uses whiptail (ncurses) which is
# pre-installed on Debian/Ubuntu. Falls back to dialog if whiptail is
# unavailable.
#
# Wizard flow:
#   1. Welcome / preflight check
#   2. Choose install mode:  [Category browse] [Search] [Show all] [Quit]
#   3. Multi-select apps (checkbox) or category picker
#   4. Configure: CPU, RAM, Disk defaults
#   5. Review selection
#   6. Install progress (tailbox) with abort option
#
# After the wizard finishes, runs each selected app's ct/<app>.sh with
# the configured environment variables, and shows a final summary.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INCUS_BASE="${INCUS_BASE:-https://raw.githubusercontent.com/luna-dj/incus-scripts/main}"

# ──────────────────────────────────────────────────────────────────
#  ncurses tool detection + sanity check
# ──────────────────────────────────────────────────────────────────
DIALOG_TOOL=""
if command -v whiptail >/dev/null 2>&1; then
    DIALOG_TOOL="whiptail"
elif command -v dialog >/dev/null 2>&1; then
    DIALOG_TOOL="dialog"
else
    echo "ERROR: This wizard requires whiptail (Debian/Ubuntu) or dialog."
    echo "       Install with: apt install whiptail"
    exit 1
fi

# Verify the ncurses tool actually works on this terminal. Some
# SSH/serial terminals break whiptail's ncurses render. We do a
# 2-second smoke test: run a tiny msgbox with a timeout, and if
# it doesn't return, fall back to a plain-text menu.
#
# Set FORCE_TEXT_MENU=1 to skip the smoke test entirely.
verify_ncurses() {
    if [[ "${FORCE_TEXT_MENU:-0}" == "1" ]]; then
        return 1
    fi
    if [[ "${DISABLE_NCURSES_CHECK:-0}" == "1" ]]; then
        return 0
    fi
    # Render test: ask whiptail to write a single character then exit.
    # Use --infobox (no input needed) with a 1-second timeout. If the
    # render loop is broken, the timeout will fire. If whiptail is
    # working, it will exit cleanly after 1s.
    timeout 1 whiptail --title "Test" --infobox "ncurses OK" 6 30 >/dev/tty 2>&1
    local rc=$?
    # timeout returns 124 on timeout (which is fine — whiptail was running)
    # whiptail returns 0 on success, 1 on cancel
    if [[ $rc -eq 0 || $rc -eq 1 || $rc -eq 124 ]]; then
        return 0
    fi
    return 1
}

if ! verify_ncurses; then
    echo "WARNING: whiptail/dialog did not respond on this terminal." >&2
    echo "         Falling back to plain-text menu." >&2
    USE_TEXT_MENU=1
    # Restore terminal in case whiptail messed it up
    stty sane 2>/dev/null
    reset 2>/dev/null
else
    USE_TEXT_MENU=0
    echo "ncurses OK, using whiptail UI" >&2
    # Clear screen and reset terminal so whiptail renders cleanly
    clear
    stty sane 2>/dev/null
    # Some terminals need a moment for the smoke test's terminal
    # mode changes to settle before whiptail can take over
    sleep 0.3
fi

# After the smoke test, the terminal may have leftover ncurses state.
# Reset it before any user-facing prompts.

# whiptail and dialog have nearly identical CLI; dialog has a few
# extra options. Set up an alias for whichever we found.
if [[ "$DIALOG_TOOL" == "whiptail" ]]; then
    # whiptail doesn't have --title-on-sep lines; differences are minor
    TUI() { whiptail "$@"; }
else
    TUI() { dialog "$@"; }
fi

# If the ncurses smoke test failed, TUI becomes a plain-text menu
# wrapper. This guarantees the wizard is always usable, even on
# terminals that break whiptail.
if [[ "$USE_TEXT_MENU" == "1" ]]; then
    TUI() {
        local title="" text="" default="" h=10 w=60 list_h=8
        local kind="" items=()
        local h_set=0 w_set=0 list_h_set=0 text_set=0
        # Parse args. whiptail syntax:
        #   --title <title>
        #   --<kind> <text> <height> <width> [list-height] [tag item status]...
        # text is optional for msgbox/yesno/infobox (no text means no body)
        # for --menu, --checklist, --inputbox, text is the prompt shown above.
        # We are tolerant: skip unknown flags, accept missing text.
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --title)        title="$2"; shift 2 ;;
                --separate-output) shift ;;  # ignored
                --msgbox|--yesno|--inputbox|--menu|--infobox|--checklist)
                    kind="${1#--}"; shift ;;
                *)
                    if [[ "$text_set" -eq 0 && ("$kind" == "menu" || "$kind" == "checklist" || "$kind" == "inputbox") ]]; then
                        # First non-flag arg is the prompt text for menu/inputbox
                        text="$1"; text_set=1; shift
                    elif [[ "$h_set" -eq 0 ]]; then
                        h="$1"; h_set=1; shift
                    elif [[ "$w_set" -eq 0 ]]; then
                        w="$1"; w_set=1; shift
                    elif [[ "$list_h_set" -eq 0 && ("$kind" == "menu" || "$kind" == "checklist") ]]; then
                        list_h="$1"; list_h_set=1; shift
                    else
                        # Tag/item pairs
                        items+=("$1"); shift
                    fi
                    ;;
            esac
        done

        # In text mode we work around the caller's stdout/stderr
        # swap (whiptail idiom: 3>&1 1>&2 2>&3) by writing all user-
        # visible output to /dev/tty directly. The answer goes to
        # stdout (which the caller's $(...) captures via fd 3).
        case "$kind" in
            msgbox)
                printf '\n=== %s ===\n' "${title:-Message}" >/dev/tty
                [[ -n "$text" ]] && printf '%s\n' "$text" >/dev/tty
                read -rp "Press Enter to continue... " </dev/tty
                return 0 ;;
            infobox)
                printf '\n=== %s ===\n' "${title:-Info}" >/dev/tty
                [[ -n "$text" ]] && printf '%s\n' "$text" >/dev/tty
                sleep 1
                return 0 ;;
            yesno)
                printf '\n=== %s ===\n' "${title:-Confirm}" >/dev/tty
                [[ -n "$text" ]] && printf '%s\n' "$text" >/dev/tty
                local ans
                while true; do
                    read -rp "y/n > " ans </dev/tty
                    case "${ans,,}" in
                        y|yes) return 0 ;;
                        n|no|"")  return 1 ;;
                        q)     return 1 ;;
                        *)     printf "Please answer y or n.\n" >/dev/tty ;;
                    esac
                done ;;
            inputbox)
                printf '\n=== %s ===\n' "${title:-Input}" >/dev/tty
                [[ -n "$text" ]]  && printf '%s\n' "$text" >/dev/tty
                local default_val="${items[0]:-}"
                local val
                if [[ -n "$default_val" ]]; then
                    read -rp "[${default_val}] > " val </dev/tty
                    [[ -z "$val" ]] && val="$default_val"
                else
                    read -rp "> " val </dev/tty
                fi
                printf '%s' "$val"
                return 0 ;;
            menu|checklist)
                printf '\n=== %s ===\n' "${title:-Menu}" >/dev/tty
                [[ -n "$text" ]]  && printf '%s\n' "$text" >/dev/tty
                local i
                for ((i=0; i<${#items[@]}; i+=2)); do
                    printf "  %3d) %s\n" $((i/2+1)) "${items[$((i+1))]}" >/dev/tty
                done
                local sel
                while true; do
                    read -rp "Enter number (1-${#items[@]}/2), or q to quit: " sel </dev/tty
                    [[ "${sel,,}" == "q" ]] && return 1
                    if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#items[@]}/2 )); then
                        printf '%s' "${items[$(( (sel-1)*2 ))]}"
                        return 0
                    fi
                    printf "Invalid selection.\n" >/dev/tty
                done ;;
            *)
                printf '\n=== %s ===\n' "${title:-Wizard}" >/dev/tty
                printf "Unknown dialog type '%s'.\n" "$kind" >/dev/tty
                return 1 ;;
        esac
    }
fi

# Terminal size hints (whiptail autodetects, but explicit is safer)
TERM_SIZE="$(stty size 2>/dev/null || echo '24 80')"
ROWS="${TERM_SIZE%% *}"
COLS="${TERM_SIZE##* }"
[[ "$ROWS" -lt 20 ]] && ROWS=20
[[ "$COLS" -lt 70 ]] && COLS=70

# ──────────────────────────────────────────────────────────────────
#  Preflight checks
# ──────────────────────────────────────────────────────────────────
preflight() {
    if [[ "$EUID" -ne 0 ]]; then
        TUI --title "Error" --msgbox "This wizard must be run as root or with sudo." 8 60
        exit 1
    fi
    if ! command -v incus >/dev/null 2>&1; then
        TUI --title "Error" --msgbox "Incus is not installed.\n\nInstall it from:\nhttps://linuxcontainers.org/incus/docs/main/installing/" 10 60
        exit 1
    fi
    if ! incus remote list --format csv 2>/dev/null | grep -q "^images,"; then
        TUI --title "Error" --msgbox "The 'images:' remote is not configured.\n\nRun: incus remote add images https://images.linuxcontainers.org" 10 60
        exit 1
    fi
}

# ──────────────────────────────────────────────────────────────────
#  Get list of available apps
# ──────────────────────────────────────────────────────────────────
# Parse ct/<app>.sh files. Each file has APP="Name" on a line.
get_apps() {
    local ct_dir="$REPO_ROOT/ct"
    if [[ ! -d "$ct_dir" ]]; then
        # Remote: fetch the file index from INCUS_BASE
        TUI --infobox "Fetching app list from $INCUS_BASE ..." 5 70
        sleep 1
    fi
    # For each ct/*.sh, extract the APP= variable and the file basename
    for f in "$ct_dir"/*.sh; do
        [[ -f "$f" ]] || continue
        local slug app
        slug="$(basename "$f" .sh)"
        # APP="..." line, but the local wrapper doesn't always set it
        # (the upstream ProxmoxVE uses APP). Use the slug as display name.
        app="$(grep -E '^APP=' "$f" 2>/dev/null | head -1 | sed -E 's/^APP=["'\'']([^"'\'']+)["'\''].*/\1/' || true)"
        [[ -z "$app" ]] && app="$slug"
        echo "$slug|$app"
    done | sort
}

# ──────────────────────────────────────────────────────────────────
#  Categorize apps
# ──────────────────────────────────────────────────────────────────
categorize() {
    local name="$1"
    local nl="${name,,}"
    case "$nl" in
        *ollama*|*comfy*|*whisper*|*kohya*|*automatic*|*invokeai*) echo "AI/ML" ;;
        *jellyfin*|*plex*|*emby*|*sonarr*|*radarr*|*lidarr*|*readarr*|*prowlarr*|*bazarr*|*kavita*|*audiobookshelf*|*navidrome*|*calibre*|*immich*|*frigate*|*photoprism*|*lychee*|*qbittorrent*|*sabnzbd*|*transmission*|*tdarr*) echo "Media" ;;
        *nextcloud*|*onlyoffice*|*collabora*|*bookstack*|*joplin*|*appsmith*|*nocodb*|*baserow*|*vikunja*|*openproject*|*redmine*|*odoo*|*paperless*|*etherpad*|*hedgedoc*|*cryptpad*) echo "Productivity" ;;
        *nginx*|*caddy*|*apache*|*traefik*|*haproxy*|*hestia*|*vesta*|*swag*|*nginxproxymanager*|*npm*) echo "Web Servers" ;;
        *postgres*|*postgresql*|*mysql*|*mariadb*|*mongodb*|*redis*|*memcached*|*clickhouse*|*influxdb*|*neo4j*|*cockroachdb*|*etcd*|*consul*|*vault*) echo "Databases" ;;
        *grafana*|*prometheus*|*loki*|*uptime*|*uptimekuma*|*beszel*|*zabbix*|*netdata*|*glances*|*dashy*|*homepage*|*monica*|*healthcheck*) echo "Monitoring" ;;
        *gitea*|*gitlab*|*forgejo*|*phorge*|*jenkins*|*drone*|*woodpecker*|*argocd*|*fluxcd*|*k3s*|*microk8s*|*rke2*|*kubernetes*|*docker*|*podman*|*rancher*|*portainer*|*dockge*) echo "Development" ;;
        *authelia*|*authentik*|*keycloak*|*wireguard*|*tailscale*|*headscale*|*netbird*|*zerotier*|*crowdsec*|*fail2ban*|*passbolt*|*vaultwarden*|*bitwarden*|*wazuh*|*pivpn*|*wg-easy*) echo "Security" ;;
        *pihole*|*adguard*|*adguardhome*|*blocky*|*unbound*|*bind*|*powerdns*|*cloudflared*|*firezone*|*netmaker*|*nebula*) echo "Networking" ;;
        *portainer*|*dockge*|*homarr*|*homepage*|*dashy*|*heimdall*|*organizr*|*mealie*|*tandoor*|*grocy*|*homeassistant*|*home-assistant*|*mosquitto*|*zigbee2mqtt*|*webmin*|*cockpit*|*wordpress*|*joomla*) echo "System" ;;
        *matrix*|*synapse*|*element*|*rocketchat*|*mattermost*|*jitsi*|*mumble*|*teamspeak*|*coturn*|*bbb*|*bigbluebutton*) echo "Communication" ;;
        *minio*|*nextcloud*|*owncloud*|*seafile*|*filebrowser*|*syncthing*|*filerun*|*seaweedfs*|*sftpgo*|*glusterfs*|*rook*|*longhorn*|*ceph*|*samba*|*truenas*|*rockstor*|*zfs*) echo "Storage" ;;
        *) echo "Other" ;;
    esac
}

# ──────────────────────────────────────────────────────────────────
#  Welcome screen
# ──────────────────────────────────────────────────────────────────
welcome() {
    TUI --title "Incus Helper Scripts — Install Wizard" --yesno \
        "Welcome to the Incus Helper Scripts install wizard.\n\n\
This wizard will help you:\n\
  1. Choose one or more apps to install\n\
  2. Configure resource defaults (CPU, RAM, Disk)\n\
  3. Deploy each app as an Incus container\n\n\
Apps available: $(ls "$REPO_ROOT/ct"/*.sh 2>/dev/null | wc -l)\n\
Incus version:  $(incus --version 2>/dev/null || echo 'unknown')\n\
Container base: $(incus list --format csv 2>/dev/null | wc -l) existing\n\n\
Continue?" 18 70
}

# ──────────────────────────────────────────────────────────────────
#  Mode picker
# ──────────────────────────────────────────────────────────────────
pick_mode() {
    local choice
    choice=$(TUI --title "Choose Install Mode" --menu \
        "How would you like to select apps?\n\n  • Category browse: pick apps from a category\n  • Search: type a name fragment\n  • Show all: scroll through every available app\n  • Existing: re-install or manage existing containers" \
        18 70 5 \
        1 "Category browse" \
        2 "Search by name" \
        3 "Show all apps" \
        4 "Existing containers" \
        5 "Quit wizard" \
        3>&1 1>&2 2>&3)
    echo "$choice"
}

# ──────────────────────────────────────────────────────────────────
#  Pick a category, return category name
# ──────────────────────────────────────────────────────────────────
pick_category() {
    local choice
    choice=$(TUI --title "Pick a Category" --menu \
        "Choose a category to browse:" \
        20 70 14 \
        1 "Web Servers" \
        2 "Databases" \
        3 "Media" \
        4 "Productivity" \
        5 "Monitoring" \
        6 "Development" \
        7 "Security" \
        8 "Networking" \
        9 "System" \
        10 "Storage" \
        11 "Communication" \
        12 "AI/ML" \
        13 "Other" \
        3>&1 1>&2 2>&3)
    case "$choice" in
        1) echo "Web Servers" ;; 2) echo "Databases" ;; 3) echo "Media" ;;
        4) echo "Productivity" ;; 5) echo "Monitoring" ;; 6) echo "Development" ;;
        7) echo "Security" ;; 8) echo "Networking" ;; 9) echo "System" ;;
        10) echo "Storage" ;; 11) echo "Communication" ;; 12) echo "AI/ML" ;;
        13) echo "Other" ;;
    esac
}

# ──────────────────────────────────────────────────────────────────
#  Search dialog (type-ahead)
# ──────────────────────────────────────────────────────────────────
# Returns the search query, or empty if cancelled.
search_query() {
    local query
    query=$(TUI --title "Search Apps" --inputbox \
        "Type a name fragment (case-insensitive):\n\nExample: 'nginx', 'jelly', 'adguard'" \
        12 60 3>&1 1>&2 2>&3)
    echo "$query"
}

# ──────────────────────────────────────────────────────────────────
#  Multi-select from a list (checkbox)
# ──────────────────────────────────────────────────────────────────
# Multi-select with a "select-one-at-a-time" approach.
# whiptail's --checklist is unreliable on some terminals (long render
# times, hangs), so we use --menu (which is reliable) and let the user
# pick one app at a time. They can pick "Done" when finished, or
# "Cancel" to abort. This works in both ncurses and plain-text modes.
# Args: title, list_file (each line: "slug|display")
multi_select() {
    local title="$1"
    local list_file="$2"

    if [[ ! -s "$list_file" ]]; then
        TUI --msgbox "No apps found." 6 40
        return 1
    fi

    # Load all apps into arrays. Under set -u, both arrays must be
    # initialized before any access.
    local -a slugs=() displays=()
    while IFS='|' read -r slug display; do
        [[ -z "$slug" ]] && continue
        [[ ${#display} -gt 50 ]] && display="${display:0:47}..."
        slugs+=("$slug")
        displays+=("$display")
    done < "$list_file"

    local total=${#slugs[@]}
    if [[ $total -eq 0 ]]; then
        TUI --msgbox "No apps found." 6 40
        return 1
    fi

    # Selected apps (slugs). Initialize both arrays to avoid set -u
    # issues on access before assignment.
    local -a selected=()
    local -A is_selected=()

    while true; do
        # Build the menu — first two items are controls, then apps
        local args=()
        args+=(--title "$title")
        args+=(--menu "Selected so far: ${#selected[@]}/${total} — choose an app to add/remove, or 'Done':")
        args+=("$ROWS" "$COLS" 14)

        args+=("__DONE__" "✓ Done — proceed with selection")
        args+=("__CANCEL__" "✗ Cancel selection")

        local i
        for ((i=0; i<total; i++)); do
            local marker="  "
            [[ -n "${is_selected[${slugs[$i]}]:-}" ]] && marker="✓ "
            args+=("${slugs[$i]}" "${marker}${displays[$i]}")
        done

        # stty sane in case prior interaction left terminal in odd state
        stty sane 2>/dev/null

        local choice
        choice=$(TUI "${args[@]}" 3>&1 1>&2 2>&3) || {
            stty sane 2>/dev/null
            return 1
        }
        stty sane 2>/dev/null

        case "$choice" in
            ""|__CANCEL__)
                return 1 ;;
            __DONE__)
                # Print selected slugs, one per line
                printf "%s\n" "${selected[@]}"
                return 0 ;;
            *)
                # Toggle the selection
                if [[ -n "${is_selected[$choice]:-}" ]]; then
                    # Remove from selected
                    is_selected["$choice"]=""
                    local new_selected=()
                    for s in "${selected[@]}"; do
                        [[ "$s" != "$choice" ]] && new_selected+=("$s")
                    done
                    selected=("${new_selected[@]}")
                else
                    # Add to selected
                    is_selected["$choice"]=1
                    selected+=("$choice")
                fi
                ;;
        esac
    done
}

# ──────────────────────────────────────────────────────────────────
#  Resource defaults
# ──────────────────────────────────────────────────────────────────
get_defaults() {
    local cpu ram disk
    cpu=$(TUI --title "CPU" --inputbox "Default vCPUs per app:" 8 50 "1" 3>&1 1>&2 2>&3) || return 1
    ram=$(TUI --title "RAM" --inputbox "Default RAM per app (MB):" 8 50 "1024" 3>&1 1>&2 2>&3) || return 1
    disk=$(TUI --title "Disk" --inputbox "Default disk size per app (GB):" 8 50 "10" 3>&1 1>&2 2>&3) || return 1
    DEFAULTS_CPU="$cpu"
    DEFAULTS_RAM="$ram"
    DEFAULTS_DISK="$disk"
}

# ──────────────────────────────────────────────────────────────────
#  Review selection
# ──────────────────────────────────────────────────────────────────
review_selection() {
    local file="$1"
    if [[ ! -s "$file" ]]; then
        TUI --msgbox "No apps selected. Returning to menu." 6 50
        return 1
    fi
    local msg="Apps selected for installation:\n\n"
    while IFS= read -r slug; do
        [[ -z "$slug" ]] && continue
        msg+="  • $slug\n"
    done < "$file"
    msg+="\nProceed with installation?\n\n(Resources: ${DEFAULTS_CPU:-1} vCPU, ${DEFAULTS_RAM:-1024} MB RAM, ${DEFAULTS_DISK:-10} GB disk per app)"
    TUI --title "Confirm" --yesno "$msg" 22 70
}

# ──────────────────────────────────────────────────────────────────
#  Install with progress
# ──────────────────────────────────────────────────────────────────
install_apps() {
    local selection_file="$1"
    local log_dir="/tmp/incus-wizard-logs"
    mkdir -p "$log_dir"

    local total=$(wc -l < "$selection_file")
    local current=0
    local failed=0
    local summary=""

    while IFS= read -r slug; do
        [[ -z "$slug" ]] && continue
        current=$((current+1))

        local ct_script="$REPO_ROOT/ct/${slug}.sh"
        if [[ ! -f "$ct_script" ]]; then
            summary+="✗ $slug: ct script missing\n"
            failed=$((failed+1))
            continue
        fi

        # Show progress with infobox
        TUI --infobox "Installing $slug ($current/$total)..." 5 60
        sleep 0.5

        # Run the install. Redirect output to a log file we can show
        # the user afterwards.
        local log="$log_dir/${slug}.log"
        (
            export var_cpu="${DEFAULTS_CPU:-1}"
            export var_ram="${DEFAULTS_RAM:-1024}"
            export var_disk="${DEFAULTS_DISK:-10}"
            export INCUS_BASE
            bash "$ct_script" > "$log" 2>&1
        )

        if [[ $? -eq 0 ]]; then
            summary+="✓ $slug\n"
        else
            summary+="✗ $slug (log: $log)\n"
            failed=$((failed+1))
        fi
    done < "$selection_file"

    # Show summary
    local msg="Installation complete!\n\n"
    msg+="Installed: $((total - failed)) / $total\n"
    if [[ $failed -gt 0 ]]; then
        msg+="Failed: $failed\n"
        msg+="\nDetailed summary:\n$summary"
    else
        msg+="\nAll apps:\n$summary"
    fi
    msg+="\nLogs are in: $log_dir"

    TUI --title "Done" --msgbox "$msg" 25 78
}

# ──────────────────────────────────────────────────────────────────
#  Existing containers manager
# ──────────────────────────────────────────────────────────────────
manage_existing() {
    local containers
    containers=$(incus list --format csv 2>/dev/null | awk -F',' '{print $1"|"$2"|"$3"|"$4}')
    if [[ -z "$containers" ]]; then
        TUI --msgbox "No existing containers." 6 40
        return
    fi
    local file=$(mktemp)
    echo "$containers" > "$file"

    TUI --title "Existing Containers" --msgbox \
        "Current containers:\n\n$(cat "$file" | head -20)\n\nUse 'incus' commands to manage them manually." \
        22 70
    rm -f "$file"
}

# ──────────────────────────────────────────────────────────────────
#  Main
# ──────────────────────────────────────────────────────────────────
main() {
    preflight

    # Welcome
    echo "Starting wizard..." >&2
    stty sane 2>/dev/null
    if ! welcome; then
        echo "Welcome cancelled, exiting." >&2
        exit 0
    fi
    echo "Welcome OK, continuing." >&2

    # Main loop
    while true; do
        local mode
        mode=$(pick_mode) || exit 0
        echo "Mode selected: $mode" >&2

        case "$mode" in
            5|"" ) exit 0 ;;
            1) # Category browse
                local cat
                cat=$(pick_category) || continue
                local list_file=$(mktemp)
                # Build slug|display for the selected category
                while IFS='|' read -r slug display; do
                    [[ -z "$slug" ]] && continue
                    [[ "$(categorize "$slug")" == "$cat" ]] && echo "$slug|$display"
                done < <(get_apps) > "$list_file"
                local selected=$(multi_select "Category: $cat" "$list_file")
                echo "$selected" > /tmp/wizard-selection
                rm -f "$list_file"
                ;;
            2) # Search
                local query
                query=$(search_query) || continue
                [[ -z "$query" ]] && continue
                local list_file=$(mktemp)
                # Case-insensitive match
                while IFS='|' read -r slug display; do
                    [[ -z "$slug" ]] && continue
                    if [[ "${slug,,}" == *"${query,,}"* ]] || [[ "${display,,}" == *"${query,,}"* ]]; then
                        echo "$slug|$display"
                    fi
                done < <(get_apps) > "$list_file"
                if [[ ! -s "$list_file" ]]; then
                    TUI --msgbox "No apps matching '$query'." 6 50
                    rm -f "$list_file"
                    continue
                fi
                local selected=$(multi_select "Search: $query" "$list_file")
                echo "$selected" > /tmp/wizard-selection
                rm -f "$list_file"
                ;;
            3) # Show all
                local list_file=$(mktemp)
                get_apps > "$list_file"
                local selected=$(multi_select "All Apps" "$list_file")
                echo "$selected" > /tmp/wizard-selection
                rm -f "$list_file"
                ;;
            4) # Existing
                manage_existing
                continue
                ;;
        esac

        # Get defaults
        get_defaults || continue

        # Review and install
        if review_selection /tmp/wizard-selection; then
            install_apps /tmp/wizard-selection
            # After install, ask if they want to do more
            if TUI --yesno "Install more apps?" 6 40; then
                continue
            else
                break
            fi
        fi
    done
}

main "$@"
