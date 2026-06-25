#!/usr/bin/env python3
"""
Patch ADDON_INSTALL_TEMPLATE to set TERM before eval of upstream addon
scripts. Without TERM, upstream header_info's `clear` command fails with
"General error / Operation not permitted", triggering upstream ERR trap
and exiting before the install can proceed.

NOTE: simply setting TERM="${TERM:-xterm-256color}" is not enough — many
containers have TERM=dumb (not unset). `dumb` doesn't know `clear` either.
We unconditionally force a real terminal type.
"""
import sys
import pathlib

TARGET = pathlib.Path(__file__).parent / "regen-from-upstream.py"

OLD = '''msg_info "Loading upstream addon script for {pretty}"
UPSTREAM_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/{app}.sh"
'''

NEW = '''# Ensure TERM is set and `clear` is a no-op so upstream header_info works.
# Inside `incus exec ... bash -s` there is no TTY; TERM may be `dumb` or
# unset, and `clear` exits 1 ("Operation not permitted") which trips the
# upstream ERR trap. Setting TERM alone isn't enough because `clear` also
# fails on non-tty stdout. Alias `clear` to true so the call succeeds.
TERM="xterm-256color"
export TERM
shopt -s expand_aliases
alias clear=true

msg_info "Loading upstream addon script for {pretty}"
UPSTREAM_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/{app}.sh"
'''


def main():
    src = TARGET.read_text()
    # Idempotency: if the new unconditional TERM + clear alias is present, done.
    if 'alias clear=true' in src:
        print("Already patched (TERM + clear alias).", file=sys.stderr)
        return 0
    # If we previously applied the conditional TERM-only patch, upgrade.
    if 'export TERM' in src:
        old_term = 'TERM="${TERM:-xterm-256color}"\nexport TERM\n'
        new_term = '''TERM="xterm-256color"
export TERM
shopt -s expand_aliases
alias clear=true
'''
        if old_term in src:
            src = src.replace(old_term, new_term)
            TARGET.write_text(src)
            print("Upgraded conditional TERM -> unconditional + clear alias")
            return 0
        old_term_plain = 'TERM="xterm-256color"\nexport TERM\n'
        if old_term_plain in src:
            src = src.replace(
                old_term_plain,
                old_term_plain + 'shopt -s expand_aliases\nalias clear=true\n',
            )
            TARGET.write_text(src)
            print("Added clear alias to existing TERM block")
            return 0
    # Fresh application.
    if OLD not in src:
        print("ERROR: could not find anchor", file=sys.stderr)
        return 1
    src = src.replace(OLD, NEW)
    TARGET.write_text(src)
    print("Patched", TARGET)
    return 0


if __name__ == "__main__":
    sys.exit(main())