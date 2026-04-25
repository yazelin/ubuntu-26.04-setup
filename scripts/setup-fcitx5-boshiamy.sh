#!/bin/bash
# Set up fcitx5 with Boshiamy on Ubuntu 26.04 (GNOME Wayland)
# Run with: sudo bash ~/setup-fcitx5.sh

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as: sudo bash $0"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo "==> Setting up fcitx5 for user: $REAL_USER ($REAL_HOME)"

echo "==> 1/5  Masking ibus systemd unit"
sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$REAL_USER")" \
    systemctl --user mask org.freedesktop.IBus.session.GNOME.service || true

echo "==> 2/5  Adding fcitx5 to user autostart"
sudo -u "$REAL_USER" mkdir -p "$REAL_HOME/.config/autostart"
if [ -f /usr/share/applications/org.fcitx.Fcitx5.desktop ]; then
    sudo -u "$REAL_USER" cp /usr/share/applications/org.fcitx.Fcitx5.desktop \
        "$REAL_HOME/.config/autostart/"
else
    echo "    (fcitx5 .desktop not found, skipping)"
fi

echo "==> 3/5  Writing /etc/environment.d/fcitx5.conf"
mkdir -p /etc/environment.d
cat > /etc/environment.d/fcitx5.conf <<'EOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
EOF

echo "==> 4/5  Installing gnome-shell-extension-kimpanel"
DEBIAN_FRONTEND=noninteractive apt-get install -y gnome-shell-extension-kimpanel || \
    echo "    (kimpanel install failed — fcitx5 will still work, just without GNOME panel integration)"

echo "==> 5/5  Done."
echo ""
echo "Next steps:"
echo "  1. LOG OUT and log back in (required — env vars only load on new session)"
echo "  2. Run:  fcitx5-configtool"
echo "  3. In the right pane, click '+' and add 'Boshiamy'"
echo "  4. Toggle input with Ctrl+Space"
