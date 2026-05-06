#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "pydantic-ai>=0.0.13",
#     "rich>=13",
# ]
# ///
"""
Multimodal demo — ask a vision-capable local model to extract structured
information from an image, validated against a Pydantic schema.

Usage:
    ./examples/pydantic-ai-image.py path/to/photo.jpg
    OLLAMA_MODEL=gemma4:e4b ./examples/pydantic-ai-image.py photo.png

Requires a model with vision support. As of 2026-05 on Ollama:
    - gemma4:e4b   (default, multimodal)
    - gemma4:e2b   (smaller, also multimodal)
    - gemma4:26b   (MoE, multimodal)
Text-only models like qwen3:* will refuse / produce garbage on images.

What this demonstrates:
- BinaryContent: PydanticAI's wrapper for non-text inputs (image bytes
  + media_type), passed alongside text in the prompt list.
- The same Pydantic-validated agent loop works for multimodal input —
  the schema constrains what the model returns regardless of input type.
- Ollama's OpenAI-compatible API translates BinaryContent into the
  standard image_url content part. No special config needed.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

from pydantic import BaseModel, Field
from pydantic_ai import Agent, BinaryContent
from pydantic_ai.models.openai import OpenAIChatModel
from pydantic_ai.providers.openai import OpenAIProvider
from rich import print


class ImageDescription(BaseModel):
    summary: str = Field(description="一句話總結這張圖在拍什麼")
    objects: list[str] = Field(description="圖中出現的主要物件,3-7 個")
    setting: str = Field(description="場景類型:室內 / 戶外 / 夜景 / 其他")
    has_text: bool = Field(description="圖中是否有可辨識的文字")
    extracted_text: str | None = Field(
        default=None,
        description="若 has_text=True,把文字內容抄下來;否則 None",
    )
    mood: str = Field(description="整體氛圍 (例如:溫馨、繁忙、寧靜、緊張)")


MODEL_NAME = os.environ.get("OLLAMA_MODEL", "gemma4:e4b")
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434/v1")

MEDIA_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".gif": "image/gif",
}


def main() -> None:
    if len(sys.argv) < 2:
        print("[red]Usage:[/red] ./pydantic-ai-image.py <image_path>")
        print(
            "[dim]Defaults to OLLAMA_MODEL=gemma4:e4b. "
            "Use a non-text-only Ollama model for vision input.[/dim]"
        )
        sys.exit(1)

    image_path = Path(sys.argv[1]).expanduser()
    if not image_path.exists():
        print(f"[red]File not found:[/red] {image_path}")
        sys.exit(1)

    suffix = image_path.suffix.lower()
    if suffix not in MEDIA_TYPES:
        print(f"[red]Unsupported image type:[/red] {suffix}")
        print(f"[dim]Supported: {', '.join(MEDIA_TYPES)}[/dim]")
        sys.exit(1)

    image_bytes = image_path.read_bytes()
    media_type = MEDIA_TYPES[suffix]

    model = OpenAIChatModel(
        MODEL_NAME,
        provider=OpenAIProvider(base_url=OLLAMA_URL, api_key="ollama"),
    )
    agent = Agent(
        model,
        output_type=ImageDescription,
        system_prompt=(
            "你是圖片分析助手。從用戶提供的圖片抽取結構化描述。"
            "所有欄位用繁體中文,如果某欄位無法判斷請給最合理的推論。"
        ),
    )

    print(f"[dim]Model:[/dim] [cyan]{MODEL_NAME}[/cyan] @ {OLLAMA_URL}")
    print(f"[dim]Image:[/dim] {image_path} ({len(image_bytes):,} bytes, {media_type})")
    print("[dim]Inferring... (CPU mode is slow on multimodal — give it a minute)[/dim]\n")

    result = agent.run_sync(
        ["請分析這張圖片", BinaryContent(data=image_bytes, media_type=media_type)]
    )

    print("[green]Structured output:[/green]")
    print(result.output)


if __name__ == "__main__":
    main()
