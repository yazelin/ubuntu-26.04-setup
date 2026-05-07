#!/bin/bash
# Install Wayland clipboard + input-emulation tooling for "select + dictate +
# auto-paste" style desktop AI tools (e.g. mori-desktop, Talon-like dictation,
# ZeroType-style inline rewrite).
#
# Two layers:
#   1. wl-clipboard       wl-copy / wl-paste, including `--primary` to read
#                         mouse-highlighted text without Ctrl+C.
#   2. ydotool + ydotoold input emulation via /dev/uinput. Used to send
#                         synthetic key events (e.g. Ctrl+V) so a tool can
#                         paste a result back over the user's selection.
#                         Required because GNOME Mutter does NOT implement
#                         the `zwp_virtual_keyboard_v1` Wayland protocol that
#                         `wtype` relies on — `wtype` silently does nothing
#                         on GNOME, while ydotool works because it operates
#                         at the kernel uinput layer (compositor-agnostic).
#
# ─── Usage ───────────────────────────────────────────────────────────
#
#   sudo bash setup-wayland-input.sh             # install
#   sudo bash setup-wayland-input.sh --uninstall # remove
#   bash setup-wayland-input.sh --help
#
# After install you must log out and back in once for the `input` group
# membership to apply (or run `newgrp input` in your current shell) —
# without it, ydotool will fail with a permission error on /dev/uinput.
#
# Reference:
#   https://github.com/bugaevc/wl-clipboard
#   https://github.com/ReimuNotMoe/ydotool

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

REAL_USER="${SUDO_USER:-$USER}"

# Candidate packages — `ydotoold` is sometimes split out, sometimes bundled
# inside the `ydotool` binary package; we filter against apt-cache before
# install so the script doesn't blow up on whichever Ubuntu we're on.
CANDIDATES=(wl-clipboard ydotool ydotoold)

if [ "$ACTION" = "uninstall" ]; then
    echo "==> 1/3  Stopping ydotoold service (if present)"
    systemctl disable --now ydotoold 2>/dev/null || true

    echo "==> 2/3  Removing '$REAL_USER' from input group"
    gpasswd -d "$REAL_USER" input 2>/dev/null || true

    echo "==> 3/3  Removing packages"
    INSTALLED=()
    for pkg in "${CANDIDATES[@]}"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
            INSTALLED+=("$pkg")
        fi
    done
    if [ "${#INSTALLED[@]}" -gt 0 ]; then
        DEBIAN_FRONTEND=noninteractive apt-get remove -y "${INSTALLED[@]}"
    fi
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y

    echo ""
    echo "Done. Existing shells may keep input-group membership until logout."
    exit 0
fi

echo "==> 1/4  apt update"
DEBIAN_FRONTEND=noninteractive apt-get update

echo "==> 2/4  Installing Wayland clipboard + input-emulation packages"
TO_INSTALL=()
for pkg in "${CANDIDATES[@]}"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
        TO_INSTALL+=("$pkg")
    else
        echo "    (skipping '$pkg' — not in apt; likely bundled in another pkg)"
    fi
done
DEBIAN_FRONTEND=noninteractive apt-get install -y "${TO_INSTALL[@]}"

echo "==> 3/4  Adding '$REAL_USER' to 'input' group (for /dev/uinput access)"
groupadd -f input
usermod -aG input "$REAL_USER"

echo "==> 4/4  Enabling ydotoold daemon"
# Ubuntu's ydotool package ships /lib/systemd/system/ydotoold.service.
# If for some reason it's not there, just print a hint — the daemon can
# still be invoked manually.
if systemctl list-unit-files 2>/dev/null | grep -q '^ydotoold\.service'; then
    systemctl enable --now ydotoold
    echo "    ydotoold systemd unit enabled."
else
    echo "    No ydotoold.service unit shipped — start the daemon manually:"
    echo "      sudo ydotoold &"
fi

echo ""
echo "Versions:"
wl-paste --version 2>&1 | head -1 || true
ydotool --version 2>&1 | head -1 || true
echo ""
echo "Done. IMPORTANT: log out and back in (or run 'newgrp input') for the"
echo "'input' group membership to take effect — without it, ydotool fails"
echo "with a permission error on /dev/uinput."
echo ""
echo "Quick smoke test (after relog):"
echo "  echo hello | wl-copy && wl-paste              # clipboard roundtrip"
echo "  wl-paste --primary                            # read mouse selection"
echo "  ydotool key 29:1 47:1 47:0 29:0               # send Ctrl+V"
