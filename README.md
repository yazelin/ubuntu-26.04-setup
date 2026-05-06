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

## Examples

Runnable demos pairing the local Ollama install with Python tooling — see [`examples/`](examples/).

- [`examples/pydantic-ai-hello.py`](examples/pydantic-ai-hello.py) — PydanticAI + Ollama, schema-validated structured extraction

## Notes

- [`notes/wayland-vs-xorg.md`](notes/wayland-vs-xorg.md) — Why 26.04 dropped Xorg and what that means for input methods

## Known issues

### Gemma 4 + Intel Arc + Vulkan = garbled output

**Symptom**: running `gemma4:*` (e2b, e4b, 26b, 31b) on a machine with only an Intel iGPU (Arc Graphics, Meteor Lake / Lunar Lake) produces garbled output and repetition loops. CPU mode is fine.

**Cause**: numerical instability (NaN in attention / KV cache) in the Vulkan shader path for Gemma 4's architecture as of 2026-05. Mesa Vulkan and llama.cpp's Vulkan backend haven't fully caught up.

**Fix**:
- Verified on Ubuntu 26.04 + Intel Core Ultra 7 155H (Arc iGPU)
- `setup-ollama.sh` auto-detects this combo and falls back to CPU. No action needed for fresh installs as of this writing.
- If you hit it after switching models post-install:
  ```bash
  sudo rm /etc/systemd/system/ollama.service.d/override.conf
  sudo systemctl daemon-reload && sudo systemctl restart ollama
  ```
  Or re-run `sudo bash scripts/setup-ollama.sh --no-vulkan`.
- For Vulkan acceleration on Intel Arc, use a non-Gemma-4 model (`qwen3:7b` is verified stable).
- To override the auto-downgrade and use Vulkan with Gemma 4 anyway: `--force-vulkan`.

## Tooling choices

- **Browser**: Chromium (snap), no Firefox
- **Editor**: VS Code only
- **Node.js**: managed via `fnm`, not system apt
- **Python**: managed via `uv` (handles Python versions, venvs, packages)
- **Git**: system apt (already installed by default on Ubuntu)

## Checklist

- [x] fcitx5 + Boshiamy input
- [x] Chromium (remove Firefox)
- [x] VS Code
- [x] Node.js via fnm
- [x] Python via uv
- [x] Docker + Compose v2
- [x] Ollama (local LLM runtime, GPU auto-detected)
