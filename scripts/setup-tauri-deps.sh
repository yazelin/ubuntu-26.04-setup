#!/bin/bash
# Install Linux system libraries needed to build Tauri 2 apps.
#
# Tauri 2 wraps a system WebView (WebKitGTK on Linux) — these packages
# provide the headers/libraries it links against. Without them, `cargo
# build` fails inside any Tauri crate with cryptic linker errors.
#
# ─── Usage ───────────────────────────────────────────────────────────
#
#   sudo bash setup-tauri-deps.sh             # install
#   sudo bash setup-tauri-deps.sh --uninstall # remove
#
# ─── What gets installed ─────────────────────────────────────────────
#
#   libwebkit2gtk-4.1-dev      WebView (WebKitGTK 4.1, current standard)
#   libssl-dev                 TLS for HTTPS calls
#   libayatana-appindicator3-dev   System tray icon support
#   librsvg2-dev               SVG rendering for icons
#   libsoup-3.0-dev            HTTP client used by WebKitGTK
#   javascriptcoregtk-4.1-dev  JS runtime headers
#   pkg-config build-essential curl wget file   build glue
#
# Reference: https://v2.tauri.app/start/prerequisites/#linux

set -e

for arg in "$@"; do
    if [ "$arg" = "-h" ] || [ "$arg" = "--help" ]; then
        sed -n '/^#!/,/^set -e$/p' "$0" \
            | sed -e '1d' -e '/^set -e$/,$d' -e 's/^# \{0,1\}//'
        exit 0
    fi
done

if [ "$EUID" -ne 0 ]; then
    echo "Please run as: sudo bash $0 [flags]"
    exit 1
fi

ACTION="install"
for arg in "$@"; do
    case "$arg" in
        --uninstall) ACTION="uninstall" ;;
    esac
done

PACKAGES=(
    libwebkit2gtk-4.1-dev
    libssl-dev
    libayatana-appindicator3-dev
    librsvg2-dev
    libsoup-3.0-dev
    libjavascriptcoregtk-4.1-dev
    pkg-config
    build-essential
    curl
    wget
    file
)

if [ "$ACTION" = "uninstall" ]; then
    echo "==> Removing Tauri build dependencies"
    DEBIAN_FRONTEND=noninteractive apt-get remove -y "${PACKAGES[@]}" 2>/dev/null || true
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
    echo "Done. Note: shared system libs that other apps depend on were not aggressively removed."
    exit 0
fi

echo "==> 1/2  apt update"
DEBIAN_FRONTEND=noninteractive apt-get update

echo "==> 2/2  Installing Tauri build dependencies"
DEBIAN_FRONTEND=noninteractive apt-get install -y "${PACKAGES[@]}"

echo ""
echo "Done. Now you can build any Tauri 2 app on this machine, e.g.:"
echo ""
echo "    git clone https://github.com/yazelin/mori-desktop.git"
echo "    cd mori-desktop"
echo "    npm install"
echo "    npm run tauri dev"
