"""Combine Obsidian vault todos, calendar events, and important emails into
a single todos digest split into "today" and "overarching" buckets.

Vault todos are plain Markdown checkboxes: `- [ ] Do the thing`. Add a due
date with `📅 YYYY-MM-DD` (or `due: YYYY-MM-DD`), and mark something as a
longer-running item you want to keep chipping away at — regardless of date —
with `#ongoing`. Anything you want pinned to today's list no matter what gets
`#today`. Tag a checkbox `#personal` or `#work` to categorize it.

Set `TODOS_LLM_INFERENCE=true` (see python/.env.example) to also ask the
local Ollama agent to infer additional todos from recently-edited notes'
prose, for things you wrote down but never turned into a checkbox. These
come back tagged `source: "vault_inferred"` so the app can show them
distinctly from explicit checkboxes.

Run this after calendar_scraper.py and gmail_scraper.py so it can fold their
digests in — see python/README.md.
"""
import hashlib
import json
import os
import re
import sys
from datetime import date, datetime
from typing import List, Optional

from common.config import load_config
from common.digest_writer import write_digest, write_markdown_digest

# Lazily imported inside main() — only needed there, and avoids pulling in
# agent deps when unit-testing the pure aggregator logic above.
# from agent.classifier import FeedbackClassifier

CHECKBOX_RE = re.compile(r"^\s*-\s*\[ \]\s*(.+)$")
DUE_DATE_RE = re.compile(r"(?:📅|due:)\s*(\d{4}-\d{2}-\d{2})", re.IGNORECASE)
ONGOING_RE = re.compile(r"#(ongoing|overarching)\b", re.IGNORECASE)
TODAY_TAG_RE = re.compile(r"#today\b", re.IGNORECASE)
CATEGORY_RE = re.compile(r"#(personal|work|other)\b", re.IGNORECASE)


def _stable_id(*parts: str) -> str:
    return hashlib.sha1("|".join(parts).encode("utf-8")).hexdigest()[:16]


def _extract_category(text: str) -> Optional[str]:
    match = CATEGORY_RE.search(text)
    return match.group(1).lower() if match else None


def parse_vault_todos(vault_root: str) -> List[dict]:
    """Open checkboxes found anywhere in the vault, except the `_inbox`
    folder (that's scraper output, not your notes)."""
    todos = []
    if not vault_root or not os.path.isdir(vault_root):
        return todos

    for root, dirs, files in os.walk(vault_root):
        dirs[:] = [d for d in dirs if not d.startswith(".") and d != "_inbox"]
        for name in files:
            if not name.endswith(".md"):
                continue
            path = os.path.join(root, name)
            rel_path = os.path.relpath(path, vault_root)
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as f:
                    lines = f.readlines()
            except OSError:
                continue

            for line in lines:
                match = CHECKBOX_RE.match(line)
                if not match:
                    continue
                text = match.group(1).strip()
                due_match = DUE_DATE_RE.search(text)
                todos.append({
                    "id": _stable_id(rel_path, text),
                    "text": text,
                    "source": "vault",
                    "due": due_match.group(1) if due_match else None,
                    "ongoing": bool(ONGOING_RE.search(text)),
                    "force_today": bool(TODAY_TAG_RE.search(text)),
                    "category": _extract_category(text),
                    "origin": rel_path,
                })
    return todos


def todos_from_calendar(calendar_digest: Optional[dict], today_iso: str) -> List[dict]:
    """Timed calendar events become todos due at their start time — per the
    brief, a meeting on the calendar should also show up as a todo."""
    if not calendar_digest:
        return []
    todos = []
    for event in calendar_digest.get("events", []):
        if event.get("all_day"):
            continue
        label = event.get("label", "calendar")
        summary = event.get("summary", "Event")
        start = event.get("start", "")
        todos.append({
            "id": _stable_id("cal", label, summary, start),
            "text": f"{summary} ({label}) at {start}",
            "source": "calendar",
            "due": today_iso,
            "ongoing": False,
            "force_today": True,
            "category": label if label in ("personal", "work", "uni") else None,
            "origin": label,
        })
    return todos


def todos_from_emails(email_digest: Optional[dict], today_iso: str) -> List[dict]:
    if not email_digest:
        return []
    todos = []
    for email in email_digest.get("emails", []):
        todos.append({
            "id": _stable_id("mail", email.get("id", "")),
            "text": f"Reply: {email.get('subject', '(no subject)')} — {email.get('sender', 'unknown')}",
            "source": "email",
            "due": today_iso,
            "ongoing": False,
            "force_today": True,
            "category": None,
            "origin": email.get("link"),
        })
    return todos


def _apply_classifier(todos: list, clf) -> list:
    """Fill in missing category / urgency using the feedback classifier.
    A human tag always beats the classifier."""
    for todo in todos:
        text = todo.get("text", "")
        pred_cat, pred_urg = clf.classify(text)
        if not todo.get("category") and pred_cat:
            todo["category"] = pred_cat
        if not todo.get("urgency") and pred_urg:
            todo["urgency"] = pred_urg
    return todos


def classify(todos: List[dict], today: date) -> dict:
    """today: due today/overdue, or explicitly #today-tagged.
    overarching: everything else — future-dated, #ongoing, or undated.

    Also stamps an explicit `urgency` ("today" | "this_week" | "overarching")
    onto every todo so the app can show *why* something landed in a bucket,
    rather than re-deriving it from due/ongoing/force_today flags. An item
    already carrying an `urgency` (e.g. from LLM inference) keeps it."""
    buckets = {"today": [], "overarching": []}
    for todo in todos:
        if todo.get("force_today"):
            bucket = "today"
        elif todo.get("ongoing"):
            bucket = "overarching"
        elif todo.get("due"):
            due_date = datetime.strptime(todo["due"], "%Y-%m-%d").date()
            bucket = "today" if due_date <= today else "overarching"
        else:
            bucket = "overarching"

        urgency = todo.get("urgency") or bucket
        cleaned = {k: v for k, v in todo.items() if k not in ("ongoing", "force_today")}
        cleaned["urgency"] = urgency
        buckets[bucket].append(cleaned)
    return buckets


def _read_digest(vault_inbox_dir: str, filename: str) -> Optional[dict]:
    path = os.path.join(vault_inbox_dir, filename)
    if not os.path.exists(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def main() -> int:
    config = load_config()
    if not config.vault_root_dir:
        print("VAULT_ROOT_DIR is not set; see python/.env.example", file=sys.stderr)
        return 1

    from agent.classifier import FeedbackClassifier
    clf = FeedbackClassifier.from_feedback_log(config.vault_inbox_dir, config.vault_root_dir)

    today = date.today()
    today_iso = today.isoformat()

    calendar_digest = _read_digest(config.vault_inbox_dir, "calendar_digest.json")
    email_digest = _read_digest(config.vault_inbox_dir, "email_digest.json")

    todos = parse_vault_todos(config.vault_root_dir)
    todos += todos_from_calendar(calendar_digest, today_iso)
    todos += todos_from_emails(email_digest, today_iso)

    if config.todos_llm_inference:
        from agent.infer_todos import infer_todos_from_notes

        try:
            todos += infer_todos_from_notes(
                config.vault_root_dir,
                config.ollama_host,
                config.ollama_model,
                limit=config.todos_llm_inference_limit,
            )
        except Exception as e:
            # Ollama being unreachable/slow/wrong must never break the
            # checkbox-parsing pipeline, which runs every few minutes via cron.
            print(f"LLM todo inference failed, skipping: {e}", file=sys.stderr)

    todos = _apply_classifier(todos, clf)

    buckets = classify(todos, today)
    write_digest(os.path.join(config.vault_inbox_dir, "todos_digest.json"), buckets)
    
    # Generate todos_digest.md for Obsidian
    md_content = f"# 📋 Unified Todos\n*Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*\n\n"
    
    md_content += "## Today's Tasks\n"
    if not buckets["today"]:
        md_content += "No tasks for today — nice!\n"
    else:
        for todo in buckets["today"]:
            due_str = f" | Due: {todo['due']}" if todo.get("due") else ""
            md_content += f"- [ ] {todo['text']} *({todo['source']}{due_str})*\n"
            
    md_content += "\n## Overarching & Ongoing Tasks\n"
    if not buckets["overarching"]:
        md_content += "No overarching tasks.\n"
    else:
        for todo in buckets["overarching"]:
            due_str = f" | Due: {todo['due']}" if todo.get("due") else ""
            md_content += f"- [ ] {todo['text']} *({todo['source']}{due_str})*\n"
            
    write_markdown_digest(
        os.path.join(config.vault_inbox_dir, "todos_digest.md"),
        md_content
    )
    
    print(
        f"Wrote {len(buckets['today'])} today / {len(buckets['overarching'])} "
        f"overarching todos to {config.vault_inbox_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
