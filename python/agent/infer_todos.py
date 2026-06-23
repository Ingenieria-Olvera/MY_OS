"""Ask the local Ollama model to spot action items buried in recent notes'
prose — things you wrote down but never turned into a `- [ ]` checkbox.

Used by todos_aggregator.py when TODOS_LLM_INFERENCE=true (see
python/.env.example). Never raises: a malformed or missing model response
just means no inferred todos this run, since this must not break the
checkbox-parsing pipeline that runs every few minutes via cron.
"""
import hashlib
import json
from typing import List, Optional

from agent.ollama_client import generate
from agent.vault_context import recent_notes_with_content

PROMPT_TEMPLATE = """You are a personal secretary reading someone's notes. \
Find any action items implied by the prose below — things the person wrote \
down but never turned into a checkbox todo. For each, decide:
- category: "personal", "work", "other", or null if unclear.
- urgency: "today" if it reads as due immediately or blocking something else \
today (e.g. an email that needs a same-day reply); "overarching" if it reads \
as a longer-running or recurring goal with no hard deadline (e.g. "by the end \
of the month", "eventually", a habit); otherwise "this_week".

Respond with ONLY a JSON array, no other text. Each item: \
{{"text": "...", "category": "personal" | "work" | "other" | null, \
"urgency": "today" | "this_week" | "overarching"}}. \
If you find nothing actionable, respond with [].

Notes:
{notes}
"""


def _stable_id(*parts: str) -> str:
    return hashlib.sha1("|".join(parts).encode("utf-8")).hexdigest()[:16]


def _format_notes(notes: List[tuple]) -> str:
    return "\n\n".join(f"### {rel_path}\n{content}" for rel_path, content in notes)


def _parse_items(raw: str) -> List[dict]:
    try:
        data = json.loads(raw.strip())
    except ValueError:
        return []
    if not isinstance(data, list):
        return []
    return [item for item in data if isinstance(item, dict) and item.get("text")]


def infer_todos_from_notes(
    vault_root: Optional[str], host: str, model: str, limit: int = 5
) -> List[dict]:
    notes = recent_notes_with_content(vault_root, limit)
    if not notes:
        return []

    prompt = PROMPT_TEMPLATE.format(notes=_format_notes(notes))
    raw = generate(prompt, host=host, model=model)
    items = _parse_items(raw)

    # All notes go into a single combined prompt, so the response isn't tied
    # to one specific note; attribute everything to the most recently edited
    # one (notes[0], since recent_notes_with_content returns newest first).
    origin = notes[0][0]
    todos = []
    for item in items:
        text = str(item["text"]).strip()
        category = item.get("category")
        urgency = item.get("urgency")
        todos.append({
            "id": _stable_id("inferred", origin, text),
            "text": text,
            "source": "vault_inferred",
            "due": None,
            "ongoing": urgency == "overarching",
            "force_today": urgency == "today",
            "category": category if category in ("personal", "work", "other") else None,
            "urgency": urgency if urgency in ("today", "this_week", "overarching") else None,
            "origin": origin,
        })
    return todos
