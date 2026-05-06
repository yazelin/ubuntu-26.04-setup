#!/bin/bash
# Install (or remove) Ollama on Ubuntu 26.04 with smart GPU detection.
#
# ─── Common scenarios ────────────────────────────────────────────────
#
#   I just want Ollama, with a model ready to chat:
#       sudo bash setup-ollama.sh
#       (pulls gemma4:e4b — 9.6GB, multimodal: text+image+audio)
#
#   I want a smaller / faster first download:
#       sudo bash setup-ollama.sh --model gemma4:e2b   # 7.2GB
#       sudo bash setup-ollama.sh --model qwen3:7b     # ~4.7GB, text-only
#
#   I want my main model (32GB RAM, no dGPU):
#       sudo bash setup-ollama.sh --model gemma4:26b   # 18GB MoE
#
#   I want multiple models pre-downloaded:
#       sudo bash setup-ollama.sh --model gemma4:e4b,qwen3:7b
#
#   I'll pull models myself later:
#       sudo bash setup-ollama.sh --no-pull
#
#   I also want Pi (pi.dev) — a Claude-Code-style terminal coding agent
#   that can use my local models:
#       sudo bash setup-ollama.sh --with-pi
#
#   I want it gone (but keep my downloaded models, they're huge):
#       sudo bash setup-ollama.sh --uninstall
#
#   I want it gone AND delete the model cache (~/.ollama, can be 50GB+):
#       sudo bash setup-ollama.sh --uninstall --purge
#
#   I also installed Pi and want it gone too:
#       sudo bash setup-ollama.sh --uninstall --with-pi
#
# ─── Flag reference ──────────────────────────────────────────────────
#
#   --model X[,Y,Z]   Models to pre-pull. Default: gemma4:e4b
#   --no-pull         Skip model download entirely
#   --with-pi         Also install (or remove) Pi from pi.dev
#   --uninstall       Remove instead of install
#   --purge           Only with --uninstall: also delete ~/.ollama
#   -h, --help        Print this help
#
# ─── Model sizes (for picking --model) ───────────────────────────────
#
#   gemma4:e2b   7.2GB   small multimodal,  effective 2.3B params
#   gemma4:e4b   9.6GB   default, multimodal, effective 4.5B params
#   gemma4:26b    18GB   MoE (3.8B active), best CPU-only quality/speed
#   gemma4:31b    20GB   dense, needs GPU to be usable
#   qwen3:7b    ~4.7GB   text-only, strong CJK + code (HumanEval 76)
#
#   Gemma 4 sizes are larger than param count would suggest because
#   they bundle vision + audio encoders. Use qwen3 for text-only.
#
# ─── GPU detection (automatic, you don't need to do anything) ────────
#
#   nvidia-smi present  → Ollama uses CUDA (auto)
#   amdgpu / rocm       → Ollama uses ROCm (auto)
#   Intel iGPU only     → enable Vulkan (OLLAMA_VULKAN=1, e.g. Intel Arc)
#   none                → CPU only
#
#   Check what got picked after install:
#       systemctl show ollama | grep Environment

set -e

# --- handle --help before the root check, so users can read help without sudo ---
for arg in "$@"; do
    if [ "$arg" = "-h" ] || [ "$arg" = "--help" ]; then
        sed -n '/^#!/,/^set -e$/p' "$0" \
            | sed -e '1d' -e '/^set -e$/,$d' -e 's/^# \{0,1\}//'
        exit 0
    fi
done

if [ "$EUID" -ne 0 ]; then
    echo "Please run as: sudo bash $0 [flags]   (run with --help to see options)"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# --- arg parsing ---
ACTION="install"
WITH_PI=0
PURGE=0
NO_PULL=0
MODELS="gemma4:e4b"

while [ $# -gt 0 ]; do
    case "$1" in
        --uninstall) ACTION="uninstall" ;;
        --with-pi)   WITH_PI=1 ;;
        --purge)     PURGE=1 ;;
        --no-pull)   NO_PULL=1 ;;
        --model)     MODELS="$2"; shift ;;
        -h|--help) ;;  # handled above, before root check
        *) echo "Unknown flag: $1" >&2; exit 1 ;;
    esac
    shift
done

# --- GPU detection (only matters for install) ---
detect_gpu_backend() {
    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
        echo "cuda"
    elif command -v rocminfo >/dev/null 2>&1 && rocminfo >/dev/null 2>&1; then
        echo "rocm"
    elif lspci 2>/dev/null | grep -qiE 'vga.*(intel|amd|arc)'; then
        # has SOMETHING but no NV/ROCm → check if it's actually Intel iGPU
        if lspci 2>/dev/null | grep -qi 'vga.*intel'; then
            echo "vulkan-intel"
        else
            echo "cpu"
        fi
    else
        echo "cpu"
    fi
}

# --- INSTALL PATH ---
if [ "$ACTION" = "install" ]; then
    echo "==> 1/5  Installing Ollama (official installer)"
    if ! command -v ollama >/dev/null 2>&1; then
        curl -fsSL https://ollama.com/install.sh | sh
    else
        echo "    ollama already installed at $(command -v ollama), skipping installer"
    fi

    BACKEND=$(detect_gpu_backend)
    echo "==> 2/5  Detected GPU backend: $BACKEND"

    SERVICE_OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
    mkdir -p "$SERVICE_OVERRIDE_DIR"
    case "$BACKEND" in
        vulkan-intel)
            cat > "$SERVICE_OVERRIDE_DIR/override.conf" <<'EOF'
[Service]
Environment="OLLAMA_VULKAN=1"
EOF
            echo "    Wrote OLLAMA_VULKAN=1 to systemd override (Intel Arc/iGPU acceleration)"
            ;;
        cuda|rocm)
            # Remove any stale override from a previous Vulkan-mode install
            rm -f "$SERVICE_OVERRIDE_DIR/override.conf"
            echo "    Letting Ollama auto-detect $BACKEND (no env override)"
            ;;
        cpu)
            rm -f "$SERVICE_OVERRIDE_DIR/override.conf"
            echo "    No GPU detected — running on CPU only"
            ;;
    esac

    echo "==> 3/5  Enabling and (re)starting Ollama service"
    systemctl daemon-reload
    systemctl enable --now ollama
    systemctl restart ollama
    sleep 2

    echo "==> 4/5  Pre-pulling models: $MODELS"
    if [ "$NO_PULL" = "1" ]; then
        echo "    --no-pull set, skipping"
    else
        IFS=',' read -ra MODEL_ARR <<< "$MODELS"
        for m in "${MODEL_ARR[@]}"; do
            m=$(echo "$m" | xargs)  # trim whitespace
            echo "    Pulling $m ..."
            sudo -u "$REAL_USER" ollama pull "$m" || \
                echo "    (pull failed for $m — you can retry later with: ollama pull $m)"
        done
    fi

    if [ "$WITH_PI" = "1" ]; then
        echo "==> 5/5  Installing Pi (pi.dev) coding agent"
        if ! command -v pi >/dev/null 2>&1; then
            sudo -u "$REAL_USER" bash -c 'curl -fsSL https://pi.dev/install.sh | sh' || \
                echo "    (Pi install failed — install manually with: curl -fsSL https://pi.dev/install.sh | sh)"
        else
            echo "    pi already installed at $(command -v pi), skipping"
        fi
    else
        echo "==> 5/5  Skipping Pi install (use --with-pi to include)"
    fi

    echo ""
    echo "Done."
    echo ""
    echo "Verify:"
    echo "  ollama list"
    echo "  ollama run gemma4:e4b 'hello'"
    if [ "$WITH_PI" = "1" ]; then
        echo "  pi --help"
    fi
    echo ""
    echo "GPU backend in use: $BACKEND"
    echo "  (check live with:  systemctl show ollama | grep Environment)"
    exit 0
fi

# --- UNINSTALL PATH ---
if [ "$ACTION" = "uninstall" ]; then
    echo "==> Uninstalling Ollama"
    systemctl disable --now ollama 2>/dev/null || true
    rm -f /etc/systemd/system/ollama.service
    rm -rf /etc/systemd/system/ollama.service.d
    systemctl daemon-reload || true

    rm -f /usr/local/bin/ollama /usr/bin/ollama

    if id ollama >/dev/null 2>&1; then
        userdel ollama 2>/dev/null || true
    fi
    if getent group ollama >/dev/null; then
        groupdel ollama 2>/dev/null || true
    fi

    rm -rf /usr/share/ollama

    if [ "$PURGE" = "1" ]; then
        echo "    --purge: removing $REAL_HOME/.ollama (model cache, may be many GB)"
        rm -rf "$REAL_HOME/.ollama"
    else
        echo "    Preserving $REAL_HOME/.ollama (use --purge to delete model cache)"
    fi

    if [ "$WITH_PI" = "1" ]; then
        echo "==> Uninstalling Pi"
        # Pi installs as a global npm package OR via curl|sh into ~/.pi
        if command -v npm >/dev/null 2>&1; then
            sudo -u "$REAL_USER" npm uninstall -g @mariozechner/pi-coding-agent 2>/dev/null || true
        fi
        rm -rf "$REAL_HOME/.pi"
        # If installed via curl|sh it may have dropped a binary in ~/.local/bin
        rm -f "$REAL_HOME/.local/bin/pi"
    fi

    echo ""
    echo "Done. Removed Ollama$([ "$WITH_PI" = "1" ] && echo " and Pi")."
    exit 0
fi
