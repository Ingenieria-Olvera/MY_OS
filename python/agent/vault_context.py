"""Builds a compact text context from the vault + digests to feed the local
agent, so it can answer questions or suggest a plan without re-reading
everything in the vault on every request."""
import json
import os
from typing import Optional


def _read_json(path: Optional[str]) -> Optional[dict]:
    if not path or not os.path.exists(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def _summarize_todos(todos_digest: Optional[dict]) -> str:
    if not todos_digest:
        return "No todos digest available yet."
    lines = ["Today's todos:"]
    lines += [f"- {t.get('text')}" for t in todos_digest.get("today", [])[:20]]
    lines.append("Overarching todos:")
    lines += [f"- {t.get('text')}" for t in todos_digest.get("overarching", [])[:20]]
    return "\n".join(lines)


def _summarize_calendar(calendar_digest: Optional[dict]) -> str:
    if not calendar_digest:
        return "No calendar digest available yet."
    lines = ["Today's schedule:"]
    lines += [
        f"- {e.get('start')} {e.get('summary')} ({e.get('label')})"
        for e in calendar_digest.get("events", [])[:20]
    ]
    lines.append("Suggested open blocks:")
    lines += [
        f"- {s.get('start')}-{s.get('end')}: {s.get('type')} — {s.get('reason')}"
        for s in calendar_digest.get("suggestions", [])[:10]
    ]
    return "\n".join(lines)


def _walk_notes_by_mtime(vault_root: str) -> list:
    """(mtime, rel_path) for every vault Markdown note, newest first."""
    notes = []
    for root, dirs, files in os.walk(vault_root):
        dirs[:] = [d for d in dirs if not d.startswith(".") and d != "_inbox"]
        for name in files:
            if not name.endswith(".md"):
                continue
            path = os.path.join(root, name)
            try:
                notes.append((os.path.getmtime(path), os.path.relpath(path, vault_root)))
            except OSError:
                continue
    notes.sort(reverse=True)
    return notes


def _recent_notes(vault_root: Optional[str], limit: int = 5) -> str:
    if not vault_root or not os.path.isdir(vault_root):
        return "No vault access configured."

    notes = _walk_notes_by_mtime(vault_root)
    return "\n".join(f"- {rel}" for _, rel in notes[:limit]) or "No notes found."


def recent_notes_with_content(vault_root: Optional[str], limit: int = 5) -> list:
    """(rel_path, content) for the `limit` most recently-modified vault notes."""
    if not vault_root or not os.path.isdir(vault_root):
        return []

    results = []
    for _, rel_path in _walk_notes_by_mtime(vault_root)[:limit]:
        path = os.path.join(vault_root, rel_path)
        try:
            with open(path, "r", encoding="utf-8") as f:
                results.append((rel_path, f.read()))
        except OSError:
            continue
    return results


def build_context(vault_root: Optional[str], vault_inbox_dir: Optional[str]) -> str:
    todos = _read_json(os.path.join(vault_inbox_dir, "todos_digest.json")) if vault_inbox_dir else None
    calendar = _read_json(os.path.join(vault_inbox_dir, "calendar_digest.json")) if vault_inbox_dir else None

    sections = [
        _summarize_todos(todos),
        _summarize_calendar(calendar),
        "Recently edited notes:\n" + _recent_notes(vault_root),
    ]
    return "\n\n".join(sections)
