#!/usr/bin/env bash
# Install fnm (Fast Node Manager) and latest Node.js LTS for the current user.
# Run as your normal user, NOT with sudo:
#   bash scripts/setup-nodejs.sh

set -e

if [ "$EUID" -eq 0 ]; then
    echo "Do NOT run this with sudo — fnm installs into your user home."
    exit 1
fi

echo "==> 1/3  Installing fnm"
if ! command -v fnm >/dev/null 2>&1 && [ ! -d "$HOME/.local/share/fnm" ]; then
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
else
    echo "    fnm already installed, skipping"
fi

# Make fnm available in this shell
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env --use-on-cd --shell bash)"

echo "==> 2/3  Adding fnm init to ~/.bashrc (if not present)"
BASHRC="$HOME/.bashrc"
if ! grep -q 'fnm env' "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" <<'EOF'

# fnm (Fast Node Manager)
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env --use-on-cd --shell bash)"
EOF
    echo "    appended fnm init to ~/.bashrc"
else
    echo "    fnm init already in ~/.bashrc, skipping"
fi

echo "==> 3/3  Installing latest Node LTS"
fnm install --lts
fnm default "$(fnm current)"

echo ""
echo "Done. Versions:"
node --version
npm --version
echo ""
echo "Open a new terminal (or 'source ~/.bashrc') to use fnm/node."
