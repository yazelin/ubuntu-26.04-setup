# Ubuntu 26.04 Setup

Personal notes and scripts for things I configured after a fresh Ubuntu 26.04 LTS (Resolute Raccoon) install.

## System

- Ubuntu 26.04 LTS — `Resolute Raccoon`
- GNOME Shell 50
- Wayland-only (Xorg session removed in 26.04)

## Scripts

| Script | What it does |
|---|---|
| [`scripts/setup-fcitx5-boshiamy.sh`](scripts/setup-fcitx5-boshiamy.sh) | Install & configure fcitx5 with Boshiamy (嘸蝦米) input method on GNOME-Wayland |

Run any script with:

```bash
sudo bash scripts/<script-name>.sh
```

## Notes

- [`notes/wayland-vs-xorg.md`](notes/wayland-vs-xorg.md) — Why 26.04 dropped Xorg and what that means for input methods

## Checklist

- [x] fcitx5 + Boshiamy input
- [ ] Browser (Chrome / Firefox profile)
- [ ] Editor (VS Code / Neovim)
- [ ] Dev tools (git, node, python, …)
- [ ] Terminal / shell setup
- [ ] Other apps
