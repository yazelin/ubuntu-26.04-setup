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
| [`scripts/setup-ollama.sh`](scripts/setup-ollama.sh) | Install [Ollama](https://ollama.com) with auto GPU detection (CUDA / ROCm / Intel Vulkan / CPU). Optional `--with-pi` for [Pi](https://pi.dev) coding agent. Supports `--uninstall`. Run `--help` for use-case examples. | `sudo bash` |
| [`scripts/setup-rust.sh`](scripts/setup-rust.sh) | Install Rust toolchain via [rustup](https://rustup.rs) (user-level, latest stable). Supports `--update` and `--uninstall`. | `bash` (no sudo) |
| [`scripts/setup-tauri-deps.sh`](scripts/setup-tauri-deps.sh) | Install Linux system libraries needed to build [Tauri 2](https://v2.tauri.app) apps (WebKitGTK, etc). | `sudo bash` |

## Examples

Runnable demos pairing the local Ollama install with Python tooling — see [`examples/`](examples/).

- [`examples/pydantic-ai-hello.py`](examples/pydantic-ai-hello.py) — PydanticAI + Ollama, schema-validated structured extraction

## Notes

- [`notes/wayland-vs-xorg.md`](notes/wayland-vs-xorg.md) — Why 26.04 dropped Xorg and what that means for input methods

## Known issues

### Intel Arc + Vulkan + Ollama = broken (2026-05)

**Symptom**: any LLM running through the Vulkan backend on an Intel Arc iGPU (Meteor Lake / Lunar Lake) misbehaves:
- `gemma4:e4b` → garbled output, repetition loops
- `qwen3:8b` → stuck at 100% GPU with no output emitted (NaN loop)

**Verified on**:
- Ubuntu 26.04 LTS
- Intel Core Ultra 7 155H, Intel Arc Graphics (MTL)
- Mesa 26.0.3-1ubuntu1 (latest available May 2026)
- Ollama 0.23.1 (latest as of 2026-05-05)

**Cause**: bug in either Mesa's Intel Vulkan compute path or llama.cpp's Vulkan compute shaders (or both). NaN propagates through attention / KV cache after a short generation length.

**CPU performance reference** (Ultra 7 155H, no GPU):
- `qwen3:8b` → 7 tok/s
- `gemma4:e4b` → ~8–12 tok/s (estimate, varies with prompt)

**What `setup-ollama.sh` does**: auto-detects Intel Arc and **defaults to CPU**, no Vulkan override written. Works correctly out of the box for fresh installs.

**If you already have Vulkan enabled and want to switch back**:
```bash
sudo rm /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload && sudo systemctl restart ollama
```
Or re-run `sudo bash scripts/setup-ollama.sh` (default behaviour now removes the override).

**To attempt Vulkan anyway** (e.g. once a future Mesa release fixes it):
```bash
sudo bash scripts/setup-ollama.sh --force-vulkan
```
At your own risk — re-test with a long prompt (300+ tokens) before trusting it.

## Tooling choices

- **Browser**: Chromium (snap), no Firefox
- **Editor**: VS Code only
- **Node.js**: managed via `fnm`, not system apt
- **Python**: managed via `uv` (handles Python versions, venvs, packages)
- **Rust**: managed via `rustup` (handles Rust versions, components, targets)
- **Git**: system apt (already installed by default on Ubuntu)

## Checklist

- [x] fcitx5 + Boshiamy input
- [x] Chromium (remove Firefox)
- [x] VS Code
- [x] Node.js via fnm
- [x] Python via uv
- [x] Docker + Compose v2
- [x] Ollama (local LLM runtime, GPU auto-detected)
- [x] Rust via rustup
- [x] Tauri 2 build dependencies
