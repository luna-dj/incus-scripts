# Contributing to Incus Helper Scripts

We love contributions! Here's how to get started.

## Adding a New Template

1. **Create the ct script** at `ct/<app>.sh`
2. **Create the install script** at `install/<app>-install.sh`
3. **Update the README** table with your app
4. **Test** your scripts on a real Incus host

## Script Requirements

- Start with `#!/usr/bin/env bash`
- Source `common.sh` and the appropriate `.func` file
- Use the provided functions (`msg_info`, `msg_ok`, etc.)
- Include a Copyright header
- Set sensible default resource limits

## Naming Convention

- App scripts: `ct/<app>.sh` (lowercase, hyphens for spaces)
- Install scripts: `install/<app>-install.sh`
- Both run via `bash <(curl ...)` — no local files needed

## Code Style

- Shellcheck must pass (`shellcheck ct/*.sh install/*.sh misc/*.func`)
- Single-quote heredoc markers if they contain variable expansions
- Use `$STD` wrapper for commands that should be silent normally
- Variables in ALL_CAPS for config, lowercase for locals

## Templates

```bash
# ct/<app>.sh
source /dev/stdin <<<"$(curl -fsSL .../common.sh)"
source /dev/stdin <<<"$(curl -fsSL .../misc/incus-build.func)"

APP="My App"
var_tags="${var_tags:-tag1,tag2}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-10}"
...
```

```bash
# install/<app>-install.sh
source /dev/stdin <<<"$(curl -fsSL .../common.sh)"
source /dev/stdin <<<"$(curl -fsSL .../misc/incus-install.func)"

header_info "My App"
setting_up_container
network_check
configure_apt
...
```

## Pull Request Process

1. Fork the repo
2. Create a feature branch
3. Add your template(s)
4. Open a PR with a clear description

## Questions?

Open a [Discussion](https://codeberg.org/luna-dj/incus-scripts/discussions) or an [Issue](https://codeberg.org/luna-dj/incus-scripts/issues).
