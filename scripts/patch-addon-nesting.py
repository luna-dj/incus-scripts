#!/usr/bin/env python3
"""
Add `var_nesting` support so addon (Docker-based) containers can have
security.nesting=true. Without nesting, Docker inside an unprivileged
container can't write to /proc/sys/net/* and fails with
"OCI runtime create failed: ... permission denied".

Two changes:

1. misc/incus-build.func: introduce var_nesting (default false), respect
   it in create_instance() instead of hard-coding security.nesting=false.

2. CT_ADDON_TEMPLATE in scripts/regen-from-upstream.py: default
   var_nesting=true for addon apps.
"""
import sys
import pathlib

BUILD_FUNC = pathlib.Path(__file__).parent.parent / "misc" / "incus-build.func"

# Step 1: add var_nesting default after var_unprivileged default
OLD_DEFAULT = '''var_unprivileged="${var_unprivileged:-true}"
'''
NEW_DEFAULT = '''var_unprivileged="${var_unprivileged:-true}"
# Set to true for containers that need to run nested things (e.g. Docker
# inside an Incus container). Addon apps default this on via their ct
# template; regular apps leave it false for tighter isolation.
var_nesting="${var_nesting:-false}"
'''

# Step 2: respect var_nesting in create_instance()
OLD_NESTING = '''  # Security / unprivileged
  if [[ "$var_unprivileged" == "true" ]]; then
    launch_args+=(--config "security.privileged=false")
    launch_args+=(--config "security.nesting=false")
  else
    launch_args+=(--config "security.privileged=true")
  fi
'''
NEW_NESTING = '''  # Security / unprivileged
  if [[ "$var_unprivileged" == "true" ]]; then
    launch_args+=(--config "security.privileged=false")
    launch_args+=(--config "security.nesting=$var_nesting")
  else
    launch_args+=(--config "security.privileged=true")
  fi
'''


def patch_build_func():
    src = BUILD_FUNC.read_text()

    if "var_nesting=\"${var_nesting:-false}\"" in src:
        print("var_nesting default already present in incus-build.func", file=sys.stderr)
    else:
        if OLD_DEFAULT not in src:
            print("ERROR: var_unprivileged default not found", file=sys.stderr)
            return False
        src = src.replace(OLD_DEFAULT, NEW_DEFAULT)
        print("Added var_nesting default")

    if 'security.nesting=$var_nesting' in src:
        print("create_instance already uses var_nesting", file=sys.stderr)
    else:
        if OLD_NESTING not in src:
            print("ERROR: security.nesting block not found", file=sys.stderr)
            return False
        src = src.replace(OLD_NESTING, NEW_NESTING)
        print("Wired var_nesting into create_instance")

    BUILD_FUNC.write_text(src)
    return True


# Step 3: default var_nesting=true in CT_ADDON_TEMPLATE
def patch_addon_template():
    # This is in the script-rendered file (regen-from-upstream.py).
    # We add `var_nesting="${var_nesting:-true}"` next to the other var_*
    # defaults in CT_ADDON_TEMPLATE.
    REGEN = pathlib.Path(__file__).parent / "regen-from-upstream.py"
    src = REGEN.read_text()

    # Find CT_ADDON_TEMPLATE block start, then inject after the var_disk
    # default. Idempotent: skip if already patched.
    if 'var_nesting="${var_nesting:-true}"' in src:
        print("CT_ADDON_TEMPLATE already defaults var_nesting=true", file=sys.stderr)
        return True

    # CT_ADDON_TEMPLATE is a triple-quoted string with real newlines
    # (NOT Python string concat with backslash-n). Anchor on real newline.
    anchor = 'var_disk="${{var_disk:-20}}"\nvar_os="${{var_os:-ubuntu}}"'
    addition = (
        'var_disk="${{var_disk:-20}}"\n'
        'var_nesting="${{var_nesting:-true}}"\n'
        'var_os="${{var_os:-ubuntu}}"'
    )
    if anchor not in src:
        print("ERROR: CT_ADDON_TEMPLATE var_disk default not found", file=sys.stderr)
        return False
    src = src.replace(anchor, addition)
    REGEN.write_text(src)
    print("CT_ADDON_TEMPLATE now defaults var_nesting=true for addons")
    return True


def main():
    ok1 = patch_build_func()
    ok2 = patch_addon_template()
    return 0 if (ok1 and ok2) else 1


if __name__ == "__main__":
    sys.exit(main())