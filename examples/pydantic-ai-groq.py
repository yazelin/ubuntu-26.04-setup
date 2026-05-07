#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "pydantic-ai>=0.0.13",
#     "rich>=13",
# ]
# ///
"""
Local Ollama vs cloud Groq head-to-head — same prompt, same Pydantic
schema, two backends. Prints wall-clock time + tokens/sec for each.

The point: PydanticAI doesn't care where the OpenAI-compatible endpoint
lives. Switching from local CPU inference to Groq's LPU is two lines
of config and ~50x faster. Useful for picking which to use in real apps.

Run:
    ./examples/pydantic-ai-groq.py
    ./examples/pydantic-ai-groq.py --local-only      # skip Groq
    ./examples/pydantic-ai-groq.py --cloud-only      # skip local

API key resolution (in order):
    1. GROQ_API_KEY env var
    2. ~/.pi/agent/models.json (if you've set up Pi with a groq provider)
    3. Skip the cloud half with a clear error message
"""
from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

from pydantic import BaseModel, Field
from pydantic_ai import Agent
from pydantic_ai.models.openai import OpenAIChatModel
from pydantic_ai.providers.openai import OpenAIProvider
from rich import print
from rich.table import Table


class Product(BaseModel):
    name: str = Field(description="商品名稱")
    price_twd: int | None = Field(default=None, description="新台幣價格,沒提到留 None")
    tags: list[str] = Field(default_factory=list, description="3-5 個關鍵字 tag")
    in_stock: bool = Field(description="是否有庫存")


SYSTEM_PROMPT = (
    "你是電商資料萃取助手。從用戶提供的描述中抽出結構化商品資訊。"
    "若描述沒提到的欄位,留空或合理推論。"
)
DESCRIPTION = """
這款日本進口的純棉短袖 T-shirt(藍色 M 號),原價 NT$890 特價 NT$690,
適合夏天日常穿搭、運動、上班皆可。目前現貨充足。
"""


def get_groq_api_key() -> str | None:
    """Prefer env var; fall back to Pi's models.json. Never print the key."""
    if key := os.environ.get("GROQ_API_KEY"):
        return key
    pi_config = Path.home() / ".pi" / "agent" / "models.json"
    if not pi_config.exists():
        return None
    try:
        data = json.loads(pi_config.read_text())
        key = data.get("providers", {}).get("groq", {}).get("apiKey", "")
        if key and not key.startswith("REPLACE"):
            return key
    except (json.JSONDecodeError, OSError):
        pass
    return None


def run_one(label: str, model_name: str, base_url: str, api_key: str) -> tuple[Product, float]:
    """Run the agent once, return (output, wall_seconds)."""
    model = OpenAIChatModel(
        model_name,
        provider=OpenAIProvider(base_url=base_url, api_key=api_key),
    )
    agent = Agent(model, output_type=Product, system_prompt=SYSTEM_PROMPT)
    print(f"[dim]Running[/dim] [cyan]{label}[/cyan] [dim]({model_name})...[/dim]")
    t0 = time.monotonic()
    result = agent.run_sync(DESCRIPTION)
    elapsed = time.monotonic() - t0
    return result.output, elapsed


def main() -> None:
    args = set(sys.argv[1:])
    do_local = "--cloud-only" not in args
    do_cloud = "--local-only" not in args

    runs: list[tuple[str, str, Product, float]] = []

    if do_local:
        try:
            output, elapsed = run_one(
                label="Local Ollama (CPU)",
                model_name=os.environ.get("OLLAMA_MODEL", "qwen3:8b"),
                base_url="http://localhost:11434/v1",
                api_key="ollama",
            )
            runs.append(("Local Ollama (CPU)", os.environ.get("OLLAMA_MODEL", "qwen3:8b"), output, elapsed))
        except Exception as e:
            print(f"[red]Local Ollama failed:[/red] {type(e).__name__}: {e}")

    if do_cloud:
        groq_key = get_groq_api_key()
        if not groq_key:
            print(
                "[yellow]Skipping Groq:[/yellow] no GROQ_API_KEY env var, "
                "and no real key found in ~/.pi/agent/models.json.\n"
                "[dim]Either:  export GROQ_API_KEY=gsk_...[/dim]\n"
                "[dim]Or set up Pi (https://pi.dev) with a groq provider first.[/dim]"
            )
        else:
            try:
                output, elapsed = run_one(
                    label="Groq cloud (LPU)",
                    model_name=os.environ.get("GROQ_MODEL", "openai/gpt-oss-120b"),
                    base_url="https://api.groq.com/openai/v1",
                    api_key=groq_key,
                )
                runs.append(("Groq cloud (LPU)", os.environ.get("GROQ_MODEL", "openai/gpt-oss-120b"), output, elapsed))
            except Exception as e:
                print(f"[red]Groq failed:[/red] {type(e).__name__}: {e}")

    if not runs:
        sys.exit(1)

    table = Table(title="Comparison", show_lines=True)
    table.add_column("Backend", style="cyan")
    table.add_column("Model")
    table.add_column("Time", justify="right", style="green")
    table.add_column("Output (Product)")
    for label, model_name, output, elapsed in runs:
        table.add_row(
            label,
            model_name,
            f"{elapsed:.2f}s",
            f"name={output.name!r}\nprice={output.price_twd}\ntags={output.tags}\nin_stock={output.in_stock}",
        )
    print()
    print(table)

    if len(runs) == 2:
        speedup = runs[0][3] / runs[1][3]
        faster = "Groq" if speedup > 1 else "Local"
        print(f"\n[bold]{faster} is {abs(speedup) if speedup > 1 else 1/speedup:.1f}x faster[/bold]")


if __name__ == "__main__":
    main()
