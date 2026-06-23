"""Shared configuration for the vault scrapers, loaded from environment variables.

Set these in a `.env` file (copy `.env.example`) or export them before running
the scripts / cron jobs.
"""
import os
from dataclasses import dataclass, field
from typing import List, Optional, Tuple

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


def _pad_to(items: List[str], length: int) -> List[str]:
    """Pad a shorter list by repeating its last item — e.g. several Google
    accounts sharing one credentials/token file."""
    if len(items) >= length:
        return items[:length]
    return items + [items[-1]] * (length - len(items))


def _default_credentials_file() -> str:
    """Best-effort guess at credentials.json if GOOGLE_CREDENTIALS_FILES
    isn't set, checked relative to common places the script might be run
    from rather than assuming the caller's cwd is python/."""
    if os.path.exists("credentials.json"):
        return "credentials.json"
    if os.path.exists(os.path.join("python", "credentials.json")):
        return os.path.join("python", "credentials.json")
    return os.path.join(os.path.dirname(os.path.dirname(__file__)), "credentials.json")


@dataclass
class Config:
    vault_inbox_dir: str
    slack_user_token: Optional[str]
    slack_lookback_hours: int
    gmail_query: str
    gmail_max_results: int

    # Obsidian vault root (parent of vault_inbox_dir) — used by the todos
    # aggregator and the local agent to read your notes.
    vault_root_dir: Optional[str] = None

    # Google accounts (Gmail + Calendar) — one or more Google logins (e.g.
    # personal/uni/work), each with its own OAuth client secret file and
    # cached token, positionally aligned by name. Accounts may point at the
    # same credentials file (one OAuth client, several consents) or distinct
    # ones. See common/google_auth.py.
    google_accounts: List[str] = field(default_factory=lambda: ["default"])
    google_credentials_files: List[str] = field(default_factory=lambda: ["credentials.json"])
    google_token_files: List[str] = field(default_factory=lambda: ["google_token.json"])

    # Google Calendar — one calendar per (id, label, account) triple, all
    # positionally aligned. An account may own more than one calendar.
    google_calendar_ids: List[str] = field(default_factory=lambda: ["primary"])
    google_calendar_labels: List[str] = field(default_factory=lambda: ["personal"])
    google_calendar_accounts: List[str] = field(default_factory=lambda: ["default"])
    calendar_min_gap_minutes: int = 30

    # Local AI agent (Ollama running on the same home machine).
    ollama_host: str = "http://localhost:11434"
    ollama_model: str = "llama3.2"
    agent_host: str = "127.0.0.1"
    agent_port: int = 8765

    # Opt-in: ask the local LLM to infer extra todos from recent vault notes,
    # not just explicit checkboxes. Off by default since it requires Ollama
    # to be reachable and adds latency to every todos_aggregator.py run.
    todos_llm_inference: bool = False
    todos_llm_inference_limit: int = 5

    # Opt-in: have `agent/server.py` run the scrapers + todos aggregator on
    # this interval itself, in a background thread, instead of relying on
    # cron (which Windows doesn't have). 0 (the default) disables this —
    # keep using cron/Task Scheduler/manual runs instead. See agent/scheduler.py.
    auto_scrape_interval_minutes: int = 0

    # Second Gmail search run alongside gmail_query, so day-to-day "unread +
    # important" mail doesn't crowd out messages Gmail itself wouldn't flag
    # as important but you'd still want surfaced (bank/financial alerts,
    # scholarship/financial-aid offers, recruiter/interview emails, etc.).
    # Results from both queries are merged and de-duplicated by message id.
    # Set to "" to disable.
    gmail_keyword_query: str = (
        'subject:(bank OR statement OR payment OR overdraft OR scholarship OR '
        '"financial aid" OR tuition OR refund OR invoice OR offer OR interview '
        'OR deadline OR application)'
    )

    def google_account_triples(self) -> List[Tuple[str, str, str]]:
        """(account_name, credentials_file, token_file) per configured
        Google account."""
        accounts = self.google_accounts
        creds = _pad_to(self.google_credentials_files, len(accounts))
        tokens = _pad_to(self.google_token_files, len(accounts))
        return list(zip(accounts, creds, tokens))


def load_config() -> Config:
    vault_inbox_dir = os.environ.get("VAULT_INBOX_DIR")
    if not vault_inbox_dir:
        raise RuntimeError(
            "VAULT_INBOX_DIR is not set. Point it at the '_inbox' folder inside "
            "your synced Obsidian vault, e.g. /path/to/Cross_Study/_inbox "
            "(see python/.env.example)."
        )

    default_creds = _default_credentials_file()
    default_token = os.path.join(os.path.dirname(default_creds) or ".", "google_token.json")

    return Config(
        vault_inbox_dir=vault_inbox_dir,
        slack_user_token=os.environ.get("SLACK_USER_TOKEN"),
        slack_lookback_hours=int(os.environ.get("SLACK_LOOKBACK_HOURS", "24")),
        gmail_query=os.environ.get("GMAIL_QUERY", "is:unread is:important"),
        gmail_max_results=int(os.environ.get("GMAIL_MAX_RESULTS", "25")),
        vault_root_dir=os.environ.get("VAULT_ROOT_DIR"),
        google_accounts=_csv_env("GOOGLE_ACCOUNTS", ["default"]),
        google_credentials_files=_csv_env("GOOGLE_CREDENTIALS_FILES", [default_creds]),
        google_token_files=_csv_env("GOOGLE_TOKEN_FILES", [default_token]),
        google_calendar_ids=_csv_env("GOOGLE_CALENDAR_IDS", ["primary"]),
        google_calendar_labels=_csv_env("GOOGLE_CALENDAR_LABELS", ["personal"]),
        google_calendar_accounts=_csv_env("GOOGLE_CALENDAR_ACCOUNT", ["default"]),
        calendar_min_gap_minutes=int(os.environ.get("CALENDAR_MIN_GAP_MINUTES", "30")),
        ollama_host=os.environ.get("OLLAMA_HOST", "http://localhost:11434"),
        ollama_model=os.environ.get("OLLAMA_MODEL", "llama3.2"),
        agent_host=os.environ.get("AGENT_HOST", "127.0.0.1"),
        agent_port=int(os.environ.get("AGENT_PORT", "8765")),
        todos_llm_inference=os.environ.get("TODOS_LLM_INFERENCE", "false").strip().lower() == "true",
        todos_llm_inference_limit=int(os.environ.get("TODOS_LLM_INFERENCE_LIMIT", "5")),
        auto_scrape_interval_minutes=int(os.environ.get("AUTO_SCRAPE_INTERVAL_MINUTES", "0")),
        gmail_keyword_query=os.environ.get(
            "GMAIL_KEYWORD_QUERY",
            'subject:(bank OR statement OR payment OR overdraft OR scholarship OR '
            '"financial aid" OR tuition OR refund OR invoice OR offer OR interview '
            'OR deadline OR application)',
        ),
    )
