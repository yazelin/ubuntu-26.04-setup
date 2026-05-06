#!/bin/bash
# Set up fcitx5 with Boshiamy on Ubuntu 26.04 (GNOME Wayland)
# Run with: sudo bash ~/setup-fcitx5.sh
#
# Assumes a fresh Ubuntu install — installs fcitx5 packages from apt,
# sets it as the system default IM, and configures GNOME Wayland for it.

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as: sudo bash $0"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo "==> Setting up fcitx5 for user: $REAL_USER ($REAL_HOME)"

echo "==> 1/7  Installing fcitx5 + Boshiamy packages from apt"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    fcitx5 \
    fcitx5-config-qt \
    fcitx5-frontend-all \
    fcitx5-chinese-addons \
    fcitx5-table-boshiamy \
    im-config

echo "==> 2/7  Setting fcitx5 as system default input method (im-config)"
sudo -u "$REAL_USER" im-config -n fcitx5 || true

echo "==> 3/7  Masking ibus systemd unit"
sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$REAL_USER")" \
    systemctl --user mask org.freedesktop.IBus.session.GNOME.service || true

echo "==> 4/7  Adding fcitx5 to user autostart"
sudo -u "$REAL_USER" mkdir -p "$REAL_HOME/.config/autostart"
if [ -f /usr/share/applications/org.fcitx.Fcitx5.desktop ]; then
    sudo -u "$REAL_USER" cp /usr/share/applications/org.fcitx.Fcitx5.desktop \
        "$REAL_HOME/.config/autostart/"
else
    echo "    (fcitx5 .desktop not found, skipping)"
fi

echo "==> 5/7  Writing /etc/environment.d/fcitx5.conf"
mkdir -p /etc/environment.d
cat > /etc/environment.d/fcitx5.conf <<'EOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
EOF

# Belt-and-suspenders: also append to /etc/environment so non-systemd-user
# session paths (some login managers, ssh -X, snap apps) still pick it up.
echo "==> 6/7  Ensuring env vars in /etc/environment"
for line in \
    'GTK_IM_MODULE=fcitx' \
    'QT_IM_MODULE=fcitx' \
    'XMODIFIERS=@im=fcitx' \
    'SDL_IM_MODULE=fcitx'; do
    grep -qxF "$line" /etc/environment || echo "$line" >> /etc/environment
done

echo "==> 7/7  Installing kimpanel GNOME Shell extension (optional)"
# `gnome-shell-extension-kimpanel` was dropped from Ubuntu repos after 22.04,
# so we build from source. fcitx5 works fine without it — it only adds
# integration with the GNOME top-bar panel.
# The upstream repo (wengxt/gnome-shell-extension-kimpanel) uses CMake and
# produces a zip via `make install-zip`; we then unzip into the user's
# local extensions dir.
apt-get install -y cmake build-essential gettext zip unzip git || true

KIMPANEL_SRC="/tmp/gnome-shell-extension-kimpanel"
KIMPANEL_UUID="kimpanel@kde.org"
EXT_DIR="$REAL_HOME/.local/share/gnome-shell/extensions/$KIMPANEL_UUID"

rm -rf "$KIMPANEL_SRC"
if sudo -u "$REAL_USER" git clone --depth 1 \
    https://github.com/wengxt/gnome-shell-extension-kimpanel.git \
    "$KIMPANEL_SRC"; then
    if sudo -u "$REAL_USER" bash -c "
        set -e
        cd '$KIMPANEL_SRC'
        mkdir -p build
        cd build
        cmake ..
        make install-zip
    "; then
        ZIP_FILE=$(find "$KIMPANEL_SRC/build" -maxdepth 2 -name '*.zip' | head -1)
        if [ -n "$ZIP_FILE" ]; then
            sudo -u "$REAL_USER" mkdir -p "$EXT_DIR"
            sudo -u "$REAL_USER" unzip -o "$ZIP_FILE" -d "$EXT_DIR" >/dev/null
            echo "    kimpanel installed to $EXT_DIR"
            echo "    Enable after re-login with:  gnome-extensions enable $KIMPANEL_UUID"
        else
            echo "    (build produced no zip — skipping, fcitx5 still works)"
        fi
    else
        echo "    (kimpanel cmake/make failed — skipping, fcitx5 still works)"
    fi
else
    echo "    (kimpanel clone failed — skipping, fcitx5 still works)"
fi

echo ""
echo "==> Done."
echo ""
echo "Next steps:"
echo "  1. LOG OUT and log back in (required — env vars only load on new session)"
echo "  2. Run:  fcitx5-configtool"
echo "  3. In the right pane, click '+' and add 'Boshiamy' (嘸蝦米)"
echo "  4. Toggle input with Ctrl+Space"
