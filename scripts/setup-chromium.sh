#!/bin/bash
# Remove Firefox and install Chromium on Ubuntu 26.04.
# Run with: sudo bash scripts/setup-chromium.sh

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as: sudo bash $0"
    exit 1
fi

echo "==> 1/3  Removing Firefox snap (if installed)"
if snap list firefox >/dev/null 2>&1; then
    snap remove --purge firefox
else
    echo "    Firefox snap not installed, skipping"
fi

echo "==> 2/3  Removing firefox apt transitional package (if installed)"
if dpkg -l firefox 2>/dev/null | grep -q '^ii'; then
    DEBIAN_FRONTEND=noninteractive apt-get purge -y firefox
    apt-get autoremove -y
else
    echo "    firefox apt package not installed, skipping"
fi

echo "==> 3/3  Installing Chromium (snap)"
if snap list chromium >/dev/null 2>&1; then
    echo "    Chromium already installed, refreshing"
    snap refresh chromium
else
    snap install chromium
fi

echo ""
echo "Done. Launch with: chromium"
