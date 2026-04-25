# Ubuntu 26.04 Setup

Personal notes and scripts for things I configured after a fresh Ubuntu 26.04 LTS (Resolute Raccoon) install.

## System

- Ubuntu 26.04 LTS — `Resolute Raccoon`
- GNOME Shell 50
- Wayland-only (Xorg session removed in 26.04)

## Scripts

| Script | What it does | Run with |
|---|---|---|
| [`scripts/setup-fcitx5-boshiamy.sh`](scripts/setup-fcitx5-boshiamy.sh) | Install & configure fcitx5 with Boshiamy (嘸蝦米) input method on GNOME-Wayland | `sudo bash` |
| [`scripts/setup-chromium.sh`](scripts/setup-chromium.sh) | Remove Firefox snap, install Chromium snap | `sudo bash` |
| [`scripts/setup-vscode.sh`](scripts/setup-vscode.sh) | Install VS Code from Microsoft's official apt repo | `sudo bash` |
| [`scripts/setup-nodejs.sh`](scripts/setup-nodejs.sh) | Install [fnm](https://github.com/Schniz/fnm) (Node version manager) + latest Node LTS | `bash` (no sudo) |
| [`scripts/setup-python.sh`](scripts/setup-python.sh) | Install [uv](https://github.com/astral-sh/uv) — Astral's fast Python venv + package manager | `bash` (no sudo) |
| [`scripts/setup-docker.sh`](scripts/setup-docker.sh) | Install Docker Engine + Compose v2 from Docker's official apt repo, add user to `docker` group | `sudo bash` |

## Notes

- [`notes/wayland-vs-xorg.md`](notes/wayland-vs-xorg.md) — Why 26.04 dropped Xorg and what that means for input methods

## Tooling choices

- **Browser**: Chromium (snap), no Firefox
- **Editor**: VS Code only
- **Node.js**: managed via `fnm`, not system apt
- **Python**: managed via `uv` (handles Python versions, venvs, packages)
- **Git**: system apt (already installed by default on Ubuntu)

## Checklist

- [x] fcitx5 + Boshiamy input
- [ ] Chromium (remove Firefox)
- [ ] VS Code
- [ ] Node.js via fnm
- [ ] Python via uv
- [ ] Docker + Compose v2
