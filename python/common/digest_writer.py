"""Atomic JSON writer for the vault inbox digests.

Writes to a temp file in the same directory and renames it into place, so a
sync client (e.g. Syncthing) watching the vault never observes a half-written
file.
"""
import json
import os
import tempfile
from datetime import datetime, timezone


def write_digest(path: str, payload: dict) -> None:
    full_payload = {"generated_at": datetime.now(timezone.utc).isoformat(), **payload}
    directory = os.path.dirname(path)
    os.makedirs(directory, exist_ok=True)

    fd, tmp_path = tempfile.mkstemp(dir=directory, prefix=".tmp_", suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(full_payload, f, ensure_ascii=False, indent=2)
        os.replace(tmp_path, path)
    except Exception:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        raise
