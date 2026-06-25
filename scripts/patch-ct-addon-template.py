#!/usr/bin/env python3
"""
Patch scripts/regen-from-upstream.py to add CT_ADDON_TEMPLATE for addon apps.
"""
import sys
import pathlib

TARGET = pathlib.Path(__file__).parent / "regen-from-upstream.py"

TQS = "'''"  # triple single quote

# 1) Insert CT_ADDON_TEMPLATE definition right after CT_TEMPLATE closes.
# CT_TEMPLATE ends with a line `echo ""` then TQS on its own line. We anchor
# on the last unique line of CT_TEMPLATE (the "deployed" echo) and insert
# after the following TQS line.

ANCHOR_CT_END = (
    'echo -e "${{GR}}{pretty} deployed on ${{var_instance}} (${{IP}})${{NC}}"\n'
    'echo ""\n'
    + TQS + '\n'
)

CT_ADDON_TEMPLATE = (
    TQS + '\n'
    '#!/usr/bin/env bash\n'
    '# ct/{app}.sh — {pretty} (addon, Docker-based)\n'
    '# Generated for Incus from upstream ProxmoxVE Community Scripts (tools/addon/)\n'
    '# Our wrapper code is MIT; upstream content retains its original license.\n'
    '#\n'
    '# Set INCUS_BASE to override the raw content provider:\n'
    '#   INCUS_BASE=https://raw.githubusercontent.com/luna-dj/incus-scripts/main\n'
    '\n'
    'INCUS_BASE="${{INCUS_BASE:-{our_base}}}"\n'
    '# Export so it survives subshells (pipes, incus_exec_stdin)\n'
    'export INCUS_BASE\n'
    'source /dev/stdin <<<"$(curl -fsSL --http1.1 ${{INCUS_BASE}}/common.sh?v=$(date +%s))"\n'
    'source /dev/stdin <<<"$(curl -fsSL --http1.1 ${{INCUS_BASE}}/misc/incus-build.func?v=$(date +%s))"\n'
    '\n'
    'APP="{pretty}"\n'
    'var_tags="${{var_tags:-}}"\n'
    'var_cpu="${{var_cpu:-1}}"\n'
    'var_ram="${{var_ram:-2048}}"\n'
    'var_disk="${{var_disk:-20}}"\n'
    'var_os="${{var_os:-ubuntu}}"\n'
    'var_version="${{var_version:-24.04}}"\n'
    '\n'
    'header_info "$APP"\n'
    'variables\n'
    'check_existing_instance\n'
    'create_instance\n'
    '\n'
    '# Fetch the install script content on the host, then push it into the\n'
    '# container and run it with "bash -s" (which reads the script from stdin).\n'
    'INSTALL_SCRIPT=$(curl -fsSL --http1.1 "${{INCUS_BASE}}/install/{app}-install.sh" 2>/dev/null) || {{\n'
    '    log_error "Failed to fetch install script for {app}"\n'
    '    exit 1\n'
    '}}\n'
    'printf \'%s\\n\' "INCUS_BASE=${{INCUS_BASE}}" "$INSTALL_SCRIPT" | incus_exec_stdin "$var_instance"\n'
    '\n'
    'IP=$(get_instance_ip "$var_instance")\n'
    'echo ""\n'
    '\n'
    '# Verify the addon\'s Docker container is actually running. The upstream\n'
    '# addon can silently exit ("Installation cancelled") if a `read` prompt\n'
    '# receives empty input — we want to detect that instead of reporting\n'
    '# success. Poll `docker ps` for up to 60s for a container whose name\n'
    '# matches the app slug.\n'
    'if incus_exec_stdin "$var_instance" bash -c \'\n'
    '    for i in $(seq 1 30); do\n'
    '        if docker ps --format "{{{{.Names}}}}" 2>/dev/null | grep -qi "{app}"; then\n'
    '            echo "OK"\n'
    '            exit 0\n'
    '        fi\n'
    '        sleep 2\n'
    '    done\n'
    '    echo "TIMEOUT"\n'
    '    exit 1\n'
    '\' 2>/dev/null | grep -q "^OK$"; then\n'
    '    echo -e "${{GR}}{pretty} deployed on ${{var_instance}} (${{IP}})${{NC}}"\n'
    'else\n'
    '    echo -e "${{YL}}{pretty} install did not start a Docker container on ${{var_instance}} (${{IP}}).${{NC}}"\n'
    '    echo -e "${{YL}}Check: incus exec ${{var_instance}} -- docker ps -a${{NC}}"\n'
    '    exit 1\n'
    'fi\n'
    'echo ""\n'
    + TQS + '\n'
)


def main():
    src = TARGET.read_text()

    # Step 1: add CT_ADDON_TEMPLATE
    if 'CT_ADDON_TEMPLATE' in src:
        print("CT_ADDON_TEMPLATE already defined.", file=sys.stderr)
    else:
        if ANCHOR_CT_END not in src:
            print("ERROR: CT_TEMPLATE anchor not found", file=sys.stderr)
            return 1
        # IMPORTANT: prepend the assignment; the template body alone is
        # just a string literal that wouldn't bind to the name.
        new_block = ANCHOR_CT_END + "\nCT_ADDON_TEMPLATE = (\n" + CT_ADDON_TEMPLATE + ")\n"
        src = src.replace(ANCHOR_CT_END, new_block)
        print("Added CT_ADDON_TEMPLATE")

    # Step 2: add render_ct_addon()
    OLD_RENDER = (
        'def render_ct(app, pretty):\n'
        '    return CT_TEMPLATE.format(app=app, pretty=pretty, our_base=OUR_BASE_DEFAULT)\n'
        '\n'
        '\n'
        'def render_install(app, pretty):\n'
    )
    NEW_RENDER = (
        'def render_ct(app, pretty):\n'
        '    return CT_TEMPLATE.format(app=app, pretty=pretty, our_base=OUR_BASE_DEFAULT)\n'
        '\n'
        '\n'
        'def render_ct_addon(app, pretty):\n'
        '    return CT_ADDON_TEMPLATE.format(app=app, pretty=pretty, our_base=OUR_BASE_DEFAULT)\n'
        '\n'
        '\n'
        'def render_install(app, pretty):\n'
    )
    if 'def render_ct_addon' in src:
        print("render_ct_addon already defined.", file=sys.stderr)
    else:
        if OLD_RENDER not in src:
            print("ERROR: render_ct block not found", file=sys.stderr)
            return 1
        src = src.replace(OLD_RENDER, NEW_RENDER)
        print("Added render_ct_addon()")

    # Step 3: switch addon-loop to render_ct_addon
    OLD_LOOP = (
        '        # Generate ct/<app>.sh (same template as install/ apps)\n'
        '        ct_path = CT_DIR / f\'{app}.sh\'\n'
        '        ct_content = render_ct(app, pretty)\n'
    )
    NEW_LOOP = (
        '        # Generate ct/<app>.sh (addon template with Docker container check)\n'
        '        ct_path = CT_DIR / f\'{app}.sh\'\n'
        '        ct_content = render_ct_addon(app, pretty)\n'
    )
    if 'ct_content = render_ct_addon(app, pretty)' in src:
        print("Addon loop already switched.", file=sys.stderr)
    else:
        if OLD_LOOP not in src:
            print("ERROR: addon ct loop not found", file=sys.stderr)
            return 1
        src = src.replace(OLD_LOOP, NEW_LOOP)
        print("Switched addon ct loop to render_ct_addon")

    # Step 4: upgrade YW -> YL inside CT_ADDON_TEMPLATE.
    # YW (yellow warning) is not in our color palette; YL (yellow) is.
    # In the Python template source, color vars are doubled-braced (${{YW}})
    # so .format() emits a literal ${YW} in the generated bash file.
    yw_count = src.count('${{YW}}')
    if yw_count == 0:
        print("No YW references in template.", file=sys.stderr)
    else:
        src = src.replace('${{YW}}', '${{YL}}')
        print(f"Upgraded {yw_count} YW -> YL references in template")

    TARGET.write_text(src)
    return 0


if __name__ == "__main__":
    sys.exit(main())