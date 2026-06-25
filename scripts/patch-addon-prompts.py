#!/usr/bin/env python3
"""
Patch ADDON_INSTALL_TEMPLATE in scripts/regen-from-upstream.py to auto-answer
the interactive install/update/uninstall prompts from upstream addon scripts.

Upstream `tools/addon/*.sh` use `read -r install_prompt` / `update_prompt` /
`uninstall_prompt` and exit with "Installation cancelled" if the read gets
empty input (which it does when piped via `incus exec ... bash -s`).

Fix: after fetching UPSTREAM_SCRIPT, replace each prompt-read with a direct
assignment `prompt=y` so the addon proceeds without user interaction.
"""
import sys
import pathlib

TARGET = pathlib.Path(__file__).parent / "regen-from-upstream.py"

OLD = """# Remove upstream function sourcing (provided by incus-compat)
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/core.func)/: # (core.func)}}"
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/tools.func)/: # (tools.func)}}"
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/error_handler.func)/: # (error_handler.func)}}"

# Disable 'set -u' around eval of upstream
set +u
eval "$UPSTREAM_SCRIPT"
set -u"""

NEW = """# Remove upstream function sourcing (provided by incus-compat)
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/core.func)/: # (core.func)}}"
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/tools.func)/: # (tools.func)}}"
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/error_handler.func)/: # (error_handler.func)}}"

# Auto-answer upstream interactive prompts. Addon scripts run inside
# `incus exec ... bash -s` so there is no TTY for `read -r`. Without this
# every prompt receives empty input and the addon exits with "Installation
# cancelled". Force-yes for install/uninstall, force-no for update (we're
# doing a fresh install, not an update).
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//read -r install_prompt/install_prompt=y}}"
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//read -r install_docker_prompt/install_docker_prompt=y}}"
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//read -r update_prompt/update_prompt=n}}"
UPSTREAM_SCRIPT="${{UPSTREAM_SCRIPT//read -r uninstall_prompt/uninstall_prompt=n}}"

# Disable 'set -u' around eval of upstream
set +u
eval "$UPSTREAM_SCRIPT"
set -u"""

def main():
    src = TARGET.read_text()
    if NEW in src:
        print("Already patched.", file=sys.stderr)
        return 0
    if OLD not in src:
        print("ERROR: could not find expected block in", TARGET, file=sys.stderr)
        return 1
    src = src.replace(OLD, NEW)
    TARGET.write_text(src)
    print("Patched", TARGET)
    return 0

if __name__ == "__main__":
    sys.exit(main())