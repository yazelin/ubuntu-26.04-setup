#!/usr/bin/env bash
# Install uv (Astral's fast Python package + venv manager) for the current user.
# uv handles Python version installs, virtualenvs, and pip-compatible package management.
# Run as your normal user, NOT with sudo:
#   bash scripts/setup-python.sh

set -e

if [ "$EUID" -eq 0 ]; then
    echo "Do NOT run this with sudo — uv installs into your user home."
    exit 1
fi

echo "==> 1/2  Installing uv"
if command -v uv >/dev/null 2>&1; then
    echo "    uv already installed, upgrading"
    uv self update || true
else
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Make uv available in this shell
export PATH="$HOME/.local/bin:$PATH"

echo "==> 2/2  Verifying"
uv --version

echo ""
echo "Done. uv is in ~/.local/bin (added to PATH by the installer's shell hook)."
echo ""
echo "Common usage:"
echo "  uv python install 3.13     # install a Python version"
echo "  uv venv                    # create .venv in current dir"
echo "  uv pip install <pkg>       # pip-compatible package install"
echo "  uv init my-project         # new project with pyproject.toml"
echo "  uv run script.py           # run with auto-managed env"
