"""Asks the local Ollama model for a short daily plan based on the vault and
digests, and writes it as plan_digest.json next to the other digests.

Run this on a schedule (e.g. once each morning) on the same machine as
Ollama — see python/README.md.
"""
import os
import sys

from agent.ollama_client import OllamaError, generate
from agent.vault_context import build_context
from common.config import load_config
from common.digest_writer import write_digest

PROMPT_TEMPLATE = """You are a personal secretary. You inform the user of \
what's important; you never take action on their behalf. Given the context \
below, write a short, prioritized plan for today (5 bullet points max): \
what to do first, what can wait, and any explicit reminders about specific \
meetings or assignments. Be concise and concrete.

Context:
{context}
"""


def main() -> int:
    config = load_config()
    context = build_context(config.vault_root_dir, config.vault_inbox_dir)
    prompt = PROMPT_TEMPLATE.format(context=context)

    try:
        summary = generate(prompt, host=config.ollama_host, model=config.ollama_model)
    except OllamaError as e:
        print(str(e), file=sys.stderr)
        return 1

    write_digest(
        os.path.join(config.vault_inbox_dir, "plan_digest.json"),
        {"summary": summary.strip()},
    )
    print("Wrote plan_digest.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
