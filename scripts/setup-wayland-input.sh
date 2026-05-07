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
# After install you must REBOOT (or fully log out of the GNOME desktop
# session) so the `input` group is applied to your systemd user manager.
# Re-opening a terminal or SSH-relog is NOT enough — systemd --user
# persists across those, and ydotoold will keep failing with
# "failed to open uinput device: Permission denied" until the manager
# itself restarts with the new group.
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

# Candidate packages. `ydotool` already ships /usr/bin/ydotoold and the
# systemd unit on Ubuntu — there is no separate `ydotoold` package on
# 26.04 (Resolute). We still filter against apt-cache madison so the
# script degrades gracefully if some entry vanishes in a future release.
CANDIDATES=(wl-clipboard ydotool)

if [ "$ACTION" = "uninstall" ]; then
    echo "==> 1/3  Stopping ydotool user service (if present)"
    USER_UID="$(id -u "$REAL_USER")"
    RUNTIME_DIR="/run/user/$USER_UID"
    if [ -d "$RUNTIME_DIR" ]; then
        sudo -u "$REAL_USER" \
            XDG_RUNTIME_DIR="$RUNTIME_DIR" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus" \
            systemctl --user disable --now ydotool 2>/dev/null || true
    fi

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
    # apt-cache madison prints nothing for "no installation candidate",
    # which is more reliable than `apt-cache show` (which can succeed
    # for virtual / referenced-only package names).
    if [ -n "$(apt-cache madison "$pkg" 2>/dev/null)" ]; then
        TO_INSTALL+=("$pkg")
    else
        echo "    (skipping '$pkg' — no installation candidate on this release)"
    fi
done
if [ "${#TO_INSTALL[@]}" -eq 0 ]; then
    echo "Nothing installable found. Aborting."
    exit 1
fi
DEBIAN_FRONTEND=noninteractive apt-get install -y "${TO_INSTALL[@]}"

echo "==> 3/4  Adding '$REAL_USER' to 'input' group (for /dev/uinput access)"
groupadd -f input
usermod -aG input "$REAL_USER"

echo "==> 4/4  Enabling ydotoold daemon (user-level systemd unit)"
# Ubuntu 26.04's `ydotool` package ships only a USER-level unit at
# /usr/lib/systemd/user/ydotool.service (note: file name is ydotool.service,
# not ydotoold.service — the binary inside is ydotoold). We enable it on
# the real user's behalf so the daemon auto-starts at login.
#
# Note: the *first* start will likely fail with `Permission denied` on
# /dev/uinput because the user's systemd manager was started before this
# script added them to the `input` group, and systemd-user inherits its
# supplementary groups from PAM session creation time. A full GNOME
# logout (or reboot) is required for the manager to pick up the new group.
USER_UID="$(id -u "$REAL_USER")"
RUNTIME_DIR="/run/user/$USER_UID"
if [ -d "$RUNTIME_DIR" ]; then
    if sudo -u "$REAL_USER" \
        XDG_RUNTIME_DIR="$RUNTIME_DIR" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus" \
        systemctl --user enable --now ydotool 2>&1; then
        echo "    ydotool.service (user) enabled. (Will start cleanly after"
        echo "    you reboot / fully log out of GNOME — see message below.)"
    else
        echo "    Could not enable user unit non-interactively — run this"
        echo "    after rebooting / fully logging back in:"
        echo "      systemctl --user enable --now ydotool"
    fi
else
    echo "    No active user systemd manager (no $RUNTIME_DIR) — enable"
    echo "    after your next login:"
    echo "      systemctl --user enable --now ydotool"
fi

echo ""
echo "Done."
echo ""
echo "============================================================"
echo " IMPORTANT: REBOOT (or fully log out of GNOME and log back in)"
echo "============================================================"
echo ""
echo "The 'input' group must be applied to your systemd user manager,"
echo "not just to new shell sessions. SSH-relog or reopening a terminal"
echo "is NOT enough — systemd --user persists across those. ydotoold"
echo "will fail with 'failed to open uinput device: Permission denied'"
echo "until you reboot or log out of the GNOME desktop session."
echo ""
echo "After reboot, smoke test:"
echo "  systemctl --user is-active ydotool            # should print 'active'"
echo "  echo hello | wl-copy && wl-paste              # clipboard roundtrip"
echo "  wl-paste --primary                            # read mouse selection"
echo "  # (skip the ydotool key smoke test — it will type into your focused window)"
