#!/bin/bash
# Install Rust via the official rustup installer (user-level, no sudo).
#
# ─── Common scenarios ────────────────────────────────────────────────
#
#   I want Rust:
#       bash setup-rust.sh
#
#   I already have rustup, just want to update everything:
#       bash setup-rust.sh --update
#
#   I want to remove rustup completely (uninstall):
#       bash setup-rust.sh --uninstall
#
# ─── Why rustup, not `apt install cargo` ─────────────────────────────
#
#   apt cargo on 26.04 is 1.93.1 — works for most things but lags
#   behind. rustup gives the latest stable (1.94+ as of 2026-05),
#   easy multi-version switching (`rustup default nightly`), and a
#   one-command upgrade path (`rustup update`).
#
#   This matches the pattern in setup-nodejs.sh (fnm, not apt) and
#   setup-python.sh (uv, not apt) — language-official toolchain
#   managers over distro packages.
#
# ─── Flag reference ──────────────────────────────────────────────────
#
#   --update       Run `rustup update` (assumes rustup already installed)
#   --uninstall    Remove rustup + cargo + rustc + ~/.cargo + ~/.rustup
#   -h, --help     Print this help

set -e

for arg in "$@"; do
    if [ "$arg" = "-h" ] || [ "$arg" = "--help" ]; then
        sed -n '/^#!/,/^set -e$/p' "$0" \
            | sed -e '1d' -e '/^set -e$/,$d' -e 's/^# \{0,1\}//'
        exit 0
    fi
done

# This script runs as the user, NOT root — rustup installs into ~/.cargo/
if [ "$EUID" -eq 0 ]; then
    echo "Don't run this as root. rustup installs into your home directory."
    echo "Run as: bash $0 [flags]"
    exit 1
fi

ACTION="install"
for arg in "$@"; do
    case "$arg" in
        --update)    ACTION="update" ;;
        --uninstall) ACTION="uninstall" ;;
    esac
done

# --- UPDATE PATH ---
if [ "$ACTION" = "update" ]; then
    if ! command -v rustup >/dev/null 2>&1; then
        echo "rustup not found. Run without --update to install first."
        exit 1
    fi
    echo "==> rustup self update + toolchain update"
    rustup self update
    rustup update
    echo ""
    echo "Done. Versions:"
    rustc --version
    cargo --version
    exit 0
fi

# --- UNINSTALL PATH ---
if [ "$ACTION" = "uninstall" ]; then
    if command -v rustup >/dev/null 2>&1; then
        echo "==> rustup self uninstall (will remove ~/.cargo and ~/.rustup)"
        rustup self uninstall -y
    else
        echo "    rustup not found, removing dirs only"
        rm -rf "$HOME/.cargo" "$HOME/.rustup"
    fi
    echo ""
    echo "Done. You may want to remove the cargo PATH line from ~/.bashrc / ~/.profile if present."
    exit 0
fi

# --- INSTALL PATH ---
echo "==> 1/2  Installing rustup (official installer)"
if command -v rustup >/dev/null 2>&1; then
    echo "    rustup already installed at $(command -v rustup)"
    echo "    Use --update to upgrade, or --uninstall to remove."
else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable --profile default
fi

echo "==> 2/2  Loading PATH for this shell"
# shellcheck disable=SC1091
. "$HOME/.cargo/env"

echo ""
echo "Done."
echo ""
echo "Versions:"
rustc --version
cargo --version
rustup --version
echo ""
echo "Note: New shells will pick up cargo automatically (rustup added a"
echo "      line to your shell rc file). Existing shells need:"
echo "          source \"\$HOME/.cargo/env\""
echo ""
echo "Useful next:"
echo "  rustup component add rust-analyzer    # IDE language server"
echo "  rustup component add clippy rustfmt   # linter + formatter (already default)"
echo "  rustup target add wasm32-unknown-unknown   # for WASM builds"
