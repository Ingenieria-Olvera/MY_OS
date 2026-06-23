"""Append-only log of user corrections to suggested categories/urgency, with
an optional free-text reason — the raw signal a future learned classifier
would train on.

Written to a vault-root note (not `_inbox`, which gets overwritten every
digest run) so Obsidian/Syncthing carries it like any other note, and so it
survives even if the app is reinstalled. The phone app posts here via
`agent/server.py`'s `/feedback` endpoint over the same home Wi-Fi link as
`/chat`.
"""
import os
import re
from datetime import datetime, timezone
from typing import Optional

FEEDBACK_FILE = "Feedback Log.md"

_HEADER = (
    "# Feedback Log\n\n"
    "Corrections to suggested categories/urgency, logged for future "
    "learning. Append-only — do not hand-edit past rows.\n\n"
    "| time | text | suggested category | chosen category | suggested urgency "
    "| chosen urgency | reason |\n"
    "|---|---|---|---|---|---|---|\n"
)


def _escape(value: Optional[str]) -> str:
    if not value:
        return ""
    return re.sub(r"\s+", " ", value).strip().replace("|", "\\|")


def record_feedback(
    vault_root: str,
    text: str,
    suggested_category: Optional[str],
    chosen_category: Optional[str],
    suggested_urgency: Optional[str],
    chosen_urgency: Optional[str],
    reason: Optional[str] = None,
) -> None:
    """Appends one row to `Feedback Log.md` in the vault root. Creates the
    file with a header on first use."""
    path = os.path.join(vault_root, FEEDBACK_FILE)
    is_new = not os.path.exists(path)

    timestamp = datetime.now(timezone.utc).isoformat()
    row = (
        f"| {timestamp} | {_escape(text)} | {_escape(suggested_category)} | "
        f"{_escape(chosen_category)} | {_escape(suggested_urgency)} | "
        f"{_escape(chosen_urgency)} | {_escape(reason)} |\n"
    )

    with open(path, "a", encoding="utf-8") as f:
        if is_new:
            f.write(_HEADER)
        f.write(row)
