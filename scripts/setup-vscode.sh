#!/bin/bash
# Install VS Code on Ubuntu 26.04 from Microsoft's official apt repo.
# Run with: sudo bash scripts/setup-vscode.sh

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as: sudo bash $0"
    exit 1
fi

echo "==> 1/4  Installing prerequisites"
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y wget gpg apt-transport-https

echo "==> 2/4  Adding Microsoft signing key"
install -d -m 755 /etc/apt/keyrings
wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor --yes -o /etc/apt/keyrings/packages.microsoft.gpg
chmod 644 /etc/apt/keyrings/packages.microsoft.gpg

echo "==> 3/4  Adding VS Code apt repo"
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    > /etc/apt/sources.list.d/vscode.list

echo "==> 4/4  Installing VS Code"
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y code

echo ""
echo "Done. Launch with: code"
