<div align="center">
  <img src="https://linuxcontainers.org/static/img/incus.png" width="120" alt="Incus Logo"/>
  <h1>Incus Helper Scripts</h1>
  <p><strong>One-command application deployment for Incus containers</strong></p>
  <p>
    <a href="#-quick-start">Quick Start</a> •
    <a href="#-available-templates">Templates</a> •
    <a href="#-usage">Usage</a> •
    <a href="#-development">Development</a>
  </p>
  <p>
    <img src="https://img.shields.io/badge/incus-6.0%2B-blue?style=flat-square"/>
    <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square"/>
    <img src="https://img.shields.io/badge/templates-15+ apps-orange?style=flat-square"/>
  </p>
</div>

---

Inspired by the [Proxmox VE Community Helper Scripts](https://github.com/community-scripts/ProxmoxVE), this project provides ready-to-run scripts that deploy applications inside **Incus** containers with zero configuration.

Each application has two scripts:
- **`ct/<app>.sh`** — runs on the **Incus host**, creates the container with appropriate resources, then triggers the install
- **`install/<app>-install.sh`** — runs **inside the container**, installs the application and configures it

## ✨ Quick Start

```bash
# Deploy Nginx in 10 seconds
bash <(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/ct/nginx.sh)

# Deploy PostgreSQL
bash <(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/ct/postgresql.sh)

# Deploy Ollama (LLM inference)
bash <(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/ct/ollama.sh)
```

> **Prerequisites:** [Incus 6.0+](https://linuxcontainers.org/incus/docs/main/installing/) installed and initialized.

## 📦 Available Templates

| Category | Application | Port | Resources |
|----------|-------------|------|-----------|
| **Reverse Proxy** | [Nginx](ct/nginx.sh) | 80 | 1CPU / 512MB / 4GB |
| | [Nginx Proxy Manager](ct/nginxproxymanager.sh) | 81 | 1CPU / 1GB / 6GB |
| | [Traefik](ct/traefik.sh) | 8080 | 1CPU / 512MB / 4GB |
| **Database** | [PostgreSQL 16](ct/postgresql.sh) | 5432 | 2CPU / 1GB / 8GB |
| | [Redis](ct/redis.sh) | 6379 | 1CPU / 512MB / 4GB |
| | [MinIO (S3)](ct/minio.sh) | 9001 | 2CPU / 2GB / 20GB |
| **AI / LLM** | [Ollama](ct/ollama.sh) | 11434 | 4CPU / 8GB / 30GB |
| **Media** | [Jellyfin](ct/jellyfin.sh) | 8096 | 2CPU / 2GB / 20GB |
| | [Immich](ct/immich.sh) | 2283 | 4CPU / 4GB / 50GB |
| **Cloud** | [Nextcloud](ct/nextcloud.sh) | 80 | 2CPU / 2GB / 20GB |
| **Password Manager** | [Vaultwarden](ct/vaultwarden.sh) | 80 | 1CPU / 1GB / 8GB |
| **Smart Home** | [Home Assistant](ct/homeassistant.sh) | 8123 | 2CPU / 2GB / 20GB |
| **DNS** | [AdGuard Home](ct/adguard.sh) | 80 | 1CPU / 512MB / 4GB |
| **Dashboard** | [Homarr](ct/homarr.sh) | 7575 | 1CPU / 1GB / 6GB |
| **Monitoring** | [Uptime Kuma](ct/uptimekuma.sh) | 3001 | 1CPU / 1GB / 6GB |

<details>
<summary>📋 View full variable reference</summary>

Each script accepts these environment variables to override defaults:

| Variable | Default | Description |
|----------|---------|-------------|
| `var_cpu` | per-app | CPU cores (e.g., `2`) |
| `var_ram` | per-app | RAM in MB (e.g., `2048`) |
| `var_disk` | per-app | Disk in GB (e.g., `10`) |
| `var_os` | `ubuntu` | OS image (e.g., `alpine`, `debian`) |
| `var_version` | `24.04` | OS version (e.g., `12` for Debian) |
| `var_instance` | app name | Instance name override |
| `var_ipv4` | auto | Static IPv4 address (e.g., `10.0.0.50`) |
| `var_profile` | `default` | Incus profile to use |
| `var_tags` | per-app | Comma-separated tags for metadata |
| `var_unprivileged` | `true` | Run unprivileged container |
| `var_type` | `container` | `container` or `virtual-machine` |
| `var_image` | auto | Full image alias override |
| `var_storage` | auto | Storage pool name |
| `var_network` | auto | Network bridge name |

Example with overrides:

```bash
var_cpu=4 var_ram=4096 var_disk=50 var_ipv4=10.0.0.50 \
  bash <(curl -fsSL https://.../ct/postgresql.sh)
```

</details>

## 🚀 Usage

### Deploy an application

```bash
# Use the defaults
bash <(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/ct/nginx.sh)

# With custom resources
var_cpu=2 var_ram=2048 var_disk=20 \
  bash <(curl -fsSL https://...<app>.sh)
```

### Run install in an existing instance

```bash
incus exec <instance> -- bash -c "$(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/install/<app>-install.sh)"
```

### Manage instances

```bash
# List all instances
bash <(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/tools/incus-list.sh)

# Backup an instance
bash <(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/tools/incus-backup.sh) my-instance

# Backup all instances
bash <(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/tools/incus-backup.sh) --all

# Update all instances
bash <(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/tools/incus-update-all.sh)
```

### Profiles

Pre-defined profiles make it easy to standardize resources across instances:

```bash
# Load the app profile
incus profile create app
incus profile edit app < profiles/profile-templates.yaml
incus launch images:ubuntu/24.04 my-app --profile default --profile app
```

## 🏗 Project Structure

```
incus-helper-scripts/
├── ct/                      # Container creation scripts (run on host)
│   ├── nginx.sh
│   ├── postgresql.sh
│   └── ...
├── install/                 # In-container install scripts
│   ├── nginx-install.sh
│   ├── postgresql-install.sh
│   └── ...
├── misc/                    # Shared framework
│   ├── incus-build.func     # Container creation functions
│   └── incus-install.func   # In-container installation helpers
├── tools/                   # Utility scripts
│   ├── incus-list.sh
│   ├── incus-backup.sh
│   └── incus-update-all.sh
├── profiles/                # Incus profile templates
│   └── profile-templates.yaml
├── images/                  # Image reference docs
│   └── incus-image-aliases.md
├── common.sh                # Shared utilities (colors, logging, helpers)
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

## 🛠 Development

### Adding a new template

Each app needs two files:

1. **`ct/<app>.sh`** — Host-side script that creates the container:

```bash
#!/usr/bin/env bash
source /dev/stdin <<<"$(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/common.sh)"
source /dev/stdin <<<"$(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/misc/incus-build.func)"

APP="My App"
var_tags="${var_tags:-tag1,tag2}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-10}"

header_info "$APP"
variables
check_existing_instance
create_instance

INSTALL_URL="https://raw.githubusercontent.com/luna-dj/incus-scripts/main/install/myapp-install.sh"
incus_exec "$var_instance" -- bash -c "$(curl -fsSL "$INSTALL_URL")"

IP=$(get_instance_ip "$var_instance")
echo "Access: http://${IP}:<port>"
```

2. **`install/<app>-install.sh`** — In-container install script:

```bash
#!/usr/bin/env bash
source /dev/stdin <<<"$(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/common.sh)"
source /dev/stdin <<<"$(curl -fsSL https://raw.githubusercontent.com/luna-dj/incus-scripts/main/misc/incus-install.func)"

header_info "My App"
setting_up_container
network_check
configure_apt

# Install your app here...

print_completion "My App" "$IP" "<port>"
```

### Running locally (without the repo)

```bash
# Clone the repo
git clone https://github.com/luna-dj/incus-scripts
cd incus-helper-scripts

# Run a script directly
bash ct/nginx.sh

# Or source the functions
source common.sh
source misc/incus-build.func
# ... use functions directly
```

## 📚 Advanced

### Networking

Each container gets an IP via DHCP by default. For a static IP:

```bash
var_ipv4="10.0.0.50" bash ct/postgresql.sh
```

Proxy devices forward host ports to container ports:

```bash
incus config device add <instance> proxy-8080 proxy \
  listen=tcp:0.0.0.0:8080 connect=tcp:127.0.0.1:80
```

### Storage

Mount additional storage:

```bash
incus config device add <instance> media disk \
  source=/mnt/media path=/media
```

### Updates

Re-running a ct script on an existing instance triggers the `update_script` function (if implemented). Otherwise:

```bash
# Re-run just the install part
incus exec <instance> -- bash -c "$(curl -fsSL https://.../install/<app>-install.sh)"
```

## 🧪 Testing

```bash
# Check all scripts have the right header
grep -l "^#!/usr/bin/env bash" ct/*.sh | wc -l

# Shellcheck validation
shellcheck ct/*.sh install/*.sh misc/*.func tools/*.sh

# Check for common variables
grep "var_cpu=" ct/*.sh | wc -l
```

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

MIT — see [LICENSE](LICENSE).

## 🙏 Acknowledgements

- [Proxmox VE Helper Scripts](https://github.com/community-scripts/ProxmoxVE) for the inspiration and structure
- [Linux Containers](https://linuxcontainers.org/) for Incus
- All template authors and contributors
