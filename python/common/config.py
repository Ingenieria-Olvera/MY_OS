"""Shared configuration for the vault scrapers, loaded from environment variables.

Set these in a `.env` file (copy `.env.example`) or export them before running
the scripts / cron jobs.
"""
import os
from dataclasses import dataclass, field
from typing import List, Optional

try:
    from dotenv import load_dotenv
    load_dotenv()
    if os.path.exists("python/.env"):
        load_dotenv("python/.env")
    sibling_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
    if os.path.exists(sibling_env):
        load_dotenv(sibling_env, override=True)
except ImportError:
    pass


def _csv_env(name: str, default: List[str]) -> List[str]:
    raw = os.environ.get(name)
    if not raw:
        return default
    return [item.strip() for item in raw.split(",") if item.strip()]


@dataclass
class Config:
    vault_inbox_dir: str
    slack_user_token: Optional[str]
    slack_lookback_hours: int
    google_credentials_file: Optional[str]
    google_token_file: str
    gmail_query: str
    gmail_max_results: int

    # Obsidian vault root (parent of vault_inbox_dir) — used by the todos
    # aggregator and the local agent to read your notes.
    vault_root_dir: Optional[str] = None

    # Google Calendar — same OAuth client and cached token as Gmail (see
    # common/google_auth.py); both scopes are requested together so one
    # consent screen covers both scrapers.
    google_calendar_ids: List[str] = field(default_factory=lambda: ["primary"])
    google_calendar_labels: List[str] = field(default_factory=lambda: ["personal"])
    calendar_min_gap_minutes: int = 30

    # Local AI agent (Ollama running on the same home machine).
    ollama_host: str = "http://localhost:11434"
    ollama_model: str = "llama3.2"
    agent_host: str = "127.0.0.1"
    agent_port: int = 8765


def load_config() -> Config:
    vault_inbox_dir = os.environ.get("VAULT_INBOX_DIR")
    if not vault_inbox_dir:
        raise RuntimeError(
            "VAULT_INBOX_DIR is not set. Point it at the '_inbox' folder inside "
            "your synced Obsidian vault, e.g. /path/to/Cross_Study/_inbox "
            "(see python/.env.example)."
        )

    google_creds = os.environ.get("GOOGLE_CREDENTIALS_FILE")
    if not google_creds:
        if os.path.exists("credentials.json"):
            google_creds = "credentials.json"
        elif os.path.exists(os.path.join("python", "credentials.json")):
            google_creds = os.path.join("python", "credentials.json")
        else:
            google_creds = os.path.join(os.path.dirname(os.path.dirname(__file__)), "credentials.json")

    google_token = os.environ.get("GOOGLE_TOKEN_FILE")
    if not google_token:
        google_token = os.path.join(os.path.dirname(google_creds) or ".", "google_token.json")

    return Config(
        vault_inbox_dir=vault_inbox_dir,
        slack_user_token=os.environ.get("SLACK_USER_TOKEN"),
        slack_lookback_hours=int(os.environ.get("SLACK_LOOKBACK_HOURS", "24")),
        google_credentials_file=google_creds,
        google_token_file=google_token,
        gmail_query=os.environ.get("GMAIL_QUERY", "is:unread is:important"),
        gmail_max_results=int(os.environ.get("GMAIL_MAX_RESULTS", "25")),
        vault_root_dir=os.environ.get("VAULT_ROOT_DIR"),
        google_calendar_ids=_csv_env("GOOGLE_CALENDAR_IDS", ["primary"]),
        google_calendar_labels=_csv_env("GOOGLE_CALENDAR_LABELS", ["personal"]),
        calendar_min_gap_minutes=int(os.environ.get("CALENDAR_MIN_GAP_MINUTES", "30")),
        ollama_host=os.environ.get("OLLAMA_HOST", "http://localhost:11434"),
        ollama_model=os.environ.get("OLLAMA_MODEL", "llama3.2"),
        agent_host=os.environ.get("AGENT_HOST", "127.0.0.1"),
        agent_port=int(os.environ.get("AGENT_PORT", "8765")),
    )
