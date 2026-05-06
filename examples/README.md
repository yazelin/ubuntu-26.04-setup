# Examples

Runnable demos pairing local Ollama models with Python tooling. Self-contained
— each script declares its dependencies inline (PEP 723) so `uv run` handles
everything.

## Prerequisites

1. **Ollama running** with at least one model pulled
   ```bash
   sudo bash scripts/setup-ollama.sh
   ```
2. **uv installed**
   ```bash
   bash scripts/setup-python.sh
   ```

## Demos

| File | What it shows | Run |
|---|---|---|
| [`pydantic-ai-hello.py`](pydantic-ai-hello.py) | PydanticAI + Ollama: schema-validated structured extraction from free-form text | `./examples/pydantic-ai-hello.py` |
| [`pydantic-ai-image.py`](pydantic-ai-image.py) | Multimodal: pass an image to a vision-capable model (Gemma 4) and get structured `ImageDescription` back | `./examples/pydantic-ai-image.py path/to/photo.jpg` |

## Switching the model

All demos respect `OLLAMA_MODEL` env var:

```bash
OLLAMA_MODEL=qwen3:8b      ./examples/pydantic-ai-hello.py   # 5.2GB, text-only
OLLAMA_MODEL=gemma4:e2b    ./examples/pydantic-ai-hello.py   # 7.2GB, multimodal
OLLAMA_MODEL=gemma4:26b    ./examples/pydantic-ai-hello.py   # 18GB MoE
```

If the model isn't pulled yet, do `ollama pull <name>` first.

## Why PydanticAI for local models

Local 4B–9B models are smart but sloppy — they often produce *almost-correct*
JSON. PydanticAI wraps the model output in a Pydantic schema and auto-retries
on validation failure, which is what makes small-model agents actually
reliable. See the script for the minimum viable wiring.
