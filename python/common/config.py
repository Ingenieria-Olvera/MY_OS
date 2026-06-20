"""Shared configuration for the vault scrapers, loaded from environment variables.

Set these in a `.env` file (copy `.env.example`) or export them before running
the scripts / cron jobs.
"""
import os
from dataclasses import dataclass
from typing import Optional

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass


@dataclass
class Config:
    vault_inbox_dir: str
    slack_user_token: Optional[str]
    slack_lookback_hours: int
    gmail_client_secret_file: Optional[str]
    gmail_token_file: str
    gmail_query: str
    gmail_max_results: int


def load_config() -> Config:
    vault_inbox_dir = os.environ.get("VAULT_INBOX_DIR")
    if not vault_inbox_dir:
        raise RuntimeError(
            "VAULT_INBOX_DIR is not set. Point it at the '_inbox' folder inside "
            "your synced Obsidian vault, e.g. /path/to/Cross_Study/_inbox "
            "(see python/.env.example)."
        )
    return Config(
        vault_inbox_dir=vault_inbox_dir,
        slack_user_token=os.environ.get("SLACK_USER_TOKEN"),
        slack_lookback_hours=int(os.environ.get("SLACK_LOOKBACK_HOURS", "24")),
        gmail_client_secret_file=os.environ.get("GMAIL_CLIENT_SECRET_FILE"),
        gmail_token_file=os.environ.get("GMAIL_TOKEN_FILE", "gmail_token.json"),
        gmail_query=os.environ.get("GMAIL_QUERY", "is:unread is:important"),
        gmail_max_results=int(os.environ.get("GMAIL_MAX_RESULTS", "25")),
    )
