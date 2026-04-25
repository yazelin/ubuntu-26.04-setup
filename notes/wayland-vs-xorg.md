# Wayland vs Xorg on Ubuntu 26.04

Ubuntu 26.04 LTS (released 2026-04-23) is the first Ubuntu LTS to ship **without an Xorg session**. GNOME 49 removed all X11 support code, so GNOME 50 (which Ubuntu 26.04 ships) has no native X11 session — only Wayland.

XWayland still runs as a compatibility layer for legacy X11 apps, but the login screen no longer offers "Ubuntu on Xorg".

## Implication for Chinese input methods

- **ibus** is the GNOME default and works out of the box on Wayland.
- **fcitx5** works on GNOME-Wayland via the `text-input-v3` protocol, but:
  - GNOME does not implement the older `input-method` protocol that fcitx5 uses for its candidate popup.
  - Workaround: install `gnome-shell-extension-kimpanel` for the candidate window UI.
- ibus does **not** package Boshiamy (嘸蝦米) — only fcitx/fcitx5 do (`fcitx5-table-boshiamy`). So Boshiamy users must use fcitx5.

## Steps to make fcitx5 the active IM on GNOME-Wayland

See [`../scripts/setup-fcitx5-boshiamy.sh`](../scripts/setup-fcitx5-boshiamy.sh).

Key actions:
1. Mask the GNOME ibus systemd unit so it doesn't auto-start.
2. Add fcitx5 to user autostart.
3. Set `GTK_IM_MODULE` / `QT_IM_MODULE` / `XMODIFIERS` to `fcitx` in `/etc/environment.d/`.
4. Install `gnome-shell-extension-kimpanel`.
5. Log out and back in.
