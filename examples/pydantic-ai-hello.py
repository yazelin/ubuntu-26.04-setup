#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "pydantic-ai>=0.0.13",
#     "rich>=13",
# ]
# ///
"""
PydanticAI + local Ollama hello-world.

Asks a local Ollama model to extract structured product info from a
free-form Chinese description, validated against a Pydantic schema.

Run:
    ./examples/pydantic-ai-hello.py
    # or with a different model:
    OLLAMA_MODEL=qwen3:7b ./examples/pydantic-ai-hello.py

Prereqs:
    1. Ollama running (localhost:11434) — `sudo bash scripts/setup-ollama.sh`
    2. The model pulled: `ollama pull gemma4:e4b` (or whatever you set)
    3. uv installed: `bash scripts/setup-python.sh`

What this demonstrates:
- PydanticAI talks to Ollama via its OpenAI-compatible endpoint
- The Pydantic schema forces the model into a structured response
- If the model returns malformed data, PydanticAI auto-retries
"""
from __future__ import annotations

import os
from pydantic import BaseModel, Field
from pydantic_ai import Agent
from pydantic_ai.models.openai import OpenAIModel
from pydantic_ai.providers.openai import OpenAIProvider
from rich import print


class Product(BaseModel):
    name: str = Field(description="商品名稱")
    price_twd: int | None = Field(default=None, description="新台幣價格,沒提到留 None")
    tags: list[str] = Field(default_factory=list, description="3-5 個關鍵字 tag")
    in_stock: bool = Field(description="是否有庫存")


MODEL_NAME = os.environ.get("OLLAMA_MODEL", "gemma4:e4b")
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434/v1")

model = OpenAIModel(
    MODEL_NAME,
    provider=OpenAIProvider(base_url=OLLAMA_URL, api_key="ollama"),
)
agent = Agent(model, output_type=Product, system_prompt=(
    "你是電商資料萃取助手。從用戶提供的描述中抽出結構化商品資訊。"
    "若描述沒提到的欄位,留空或合理推論。"
))

DESCRIPTION = """
這款日本進口的純棉短袖 T-shirt(藍色 M 號),原價 NT$890 特價 NT$690,
適合夏天日常穿搭、運動、上班皆可。目前現貨充足。
"""


def main() -> None:
    print(f"[dim]Using model:[/dim] [cyan]{MODEL_NAME}[/cyan] @ {OLLAMA_URL}")
    print(f"[dim]Input:[/dim]{DESCRIPTION}")
    result = agent.run_sync(DESCRIPTION)
    print("\n[green]Structured output:[/green]")
    print(result.output)


if __name__ == "__main__":
    main()
