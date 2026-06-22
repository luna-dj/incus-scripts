# Incus Image Aliases Reference
# ==============================
# Images available via `incus image list images:`
# Use with: var_image="images:ubuntu/24.04" in ct scripts
#
# Usage:
#   incus launch images:ubuntu/24.04 <instance-name>
#   incus launch images:alpine/3.20 <instance-name>
#   incus launch images:debian/12 <instance-name>

# ── Ubuntu ──────────────────────────────────
# Ubuntu 24.04 LTS (Noble Numbat)
images:ubuntu/24.04
images:ubuntu/24.04/cloud
# Ubuntu 22.04 LTS (Jammy Jellyfish)
images:ubuntu/22.04
images:ubuntu/22.04/cloud
# Ubuntu 20.04 LTS (Focal Fossa)
images:ubuntu/20.04

# ── Debian ──────────────────────────────────
images:debian/12      # Bookworm (stable)
images:debian/11      # Bullseye (oldstable)
images:debian/13      # Trixie (testing)

# ── Alpine ──────────────────────────────────
images:alpine/3.20    # Latest stable
images:alpine/3.19    # Previous stable
images:alpine/edge    # Edge

# ── Fedora ──────────────────────────────────
images:fedora/40
images:fedora/41

# ── Rocky Linux ─────────────────────────────
images:rockylinux/9
images:rockylinux/8

# ── AlmaLinux ───────────────────────────────
images:almalinux/9
images:almalinux/8

# ── Arch Linux ──────────────────────────────
images:archlinux/current

# ── OpenSUSE ────────────────────────────────
images:opensuse/15.6  # Leap
images:opensuse/tumbleweed

# ── OCI / Docker Images ─────────────────────
# Use Docker images directly (Incus 6.0+):
#   incus launch oci:docker.io/library/nginx:latest my-nginx
#   incus launch oci:docker.io/library/postgres:16 my-postgres
#   incus launch oci:docker.io/library/redis:7 my-redis
#
# OCI images don't require a rootfs — they use the Docker base image directly.
# Note: OCI images are minimal; you may need to install additional tools.

# ── Custom Image Builds ────────────────────
# Build custom images with distrobuilder:
#   git clone https://github.com/lxc/distrobuilder
#   cd distrobuilder
#   distrobuilder build-incus ubuntu.yaml
#   incus image import ubuntu-rootfs.tar.xz --alias my-custom-ubuntu

# ── Recommended Defaults ───────────────────
# For most applications, use:
#   var_os="ubuntu"
#   var_version="24.04"
#   var_image="images:ubuntu/24.04"
#
# For minimal footprint:
#   var_os="alpine"
#   var_version="3.20"
#   var_image="images:alpine/3.20"
