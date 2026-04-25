#!/bin/bash
# Install Docker Engine + Compose v2 on Ubuntu 26.04 from Docker's official apt repo.
# Includes: docker-ce, CLI, containerd, buildx, compose v2 plugin.
# Run with: sudo bash scripts/setup-docker.sh

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as: sudo bash $0"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"

echo "==> 1/6  Removing old / conflicting Docker packages (if any)"
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
        DEBIAN_FRONTEND=noninteractive apt-get remove -y "$pkg" || true
    fi
done

echo "==> 2/6  Installing prerequisites"
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg

echo "==> 3/6  Adding Docker's official GPG key"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "==> 4/6  Adding Docker apt repo"
# Use the Ubuntu codename from /etc/os-release. If 26.04's codename isn't yet
# served by Docker, fall back to the previous LTS (noble = 24.04).
. /etc/os-release
CODENAME="${VERSION_CODENAME:-resolute}"
REPO_URL="https://download.docker.com/linux/ubuntu"
if ! curl -fsSL "${REPO_URL}/dists/${CODENAME}/Release" >/dev/null 2>&1; then
    echo "    Docker repo for '${CODENAME}' not found, falling back to 'noble' (24.04)"
    CODENAME="noble"
fi
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${REPO_URL} ${CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

echo "==> 5/6  Installing Docker Engine + Compose v2"
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

echo "==> 6/6  Adding '$REAL_USER' to docker group + enabling service"
groupadd -f docker
usermod -aG docker "$REAL_USER"
systemctl enable --now docker

echo ""
echo "Versions:"
docker --version
docker compose version
echo ""
echo "Done. IMPORTANT: log out and back in (or run 'newgrp docker') for"
echo "the docker group membership to take effect — otherwise you'll still"
echo "need sudo for docker commands."
echo ""
echo "Test with:  docker run --rm hello-world"
