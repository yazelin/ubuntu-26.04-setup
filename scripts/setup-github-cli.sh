#!/bin/bash
# Install GitHub CLI (gh) from GitHub's official apt repo.
# Run with: sudo bash scripts/setup-github-cli.sh
# After install, authenticate with: gh auth login

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as: sudo bash $0"
    exit 1
fi

echo "==> 1/4  Installing prerequisites"
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y wget gpg

echo "==> 2/4  Adding GitHub CLI signing key"
install -d -m 755 /etc/apt/keyrings
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

echo "==> 3/4  Adding GitHub CLI apt repo"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list

echo "==> 4/4  Installing gh"
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y gh

echo ""
echo "Done. gh $(gh --version | head -1)"
echo ""
echo "Next step — authenticate:"
echo "  gh auth login"
