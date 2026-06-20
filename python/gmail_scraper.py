"""Fetch important/unread Gmail messages and write them to the vault inbox
as JSON for the MY OS app to read.

First run requires interactive OAuth consent (a browser window opens); after
that the refresh token is cached in GMAIL_TOKEN_FILE so subsequent (e.g.
cron) runs are non-interactive. See python/README.md for setup.
"""
import os
import sys
from email.utils import parsedate_to_datetime
from typing import List

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

from common.config import load_config
from common.digest_writer import write_digest

SCOPES = ["https://www.googleapis.com/auth/gmail.readonly"]


def _load_credentials(client_secret_file: str, token_file: str) -> Credentials:
    creds = None
    if os.path.exists(token_file):
        creds = Credentials.from_authorized_user_file(token_file, SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(client_secret_file, SCOPES)
            creds = flow.run_local_server(port=0)
        with open(token_file, "w", encoding="utf-8") as f:
            f.write(creds.to_json())

    return creds


def _header(headers: List[dict], name: str) -> str:
    for h in headers:
        if h["name"].lower() == name.lower():
            return h["value"]
    return ""


def fetch_important_emails(service, query: str, max_results: int) -> List[dict]:
    emails = []
    resp = service.users().messages().list(userId="me", q=query, maxResults=max_results).execute()

    for item in resp.get("messages", []):
        msg = service.users().messages().get(
            userId="me", id=item["id"], format="metadata",
            metadataHeaders=["From", "Subject", "Date"],
        ).execute()
        headers = msg.get("payload", {}).get("headers", [])
        date_str = _header(headers, "Date")
        try:
            received_at = parsedate_to_datetime(date_str).isoformat()
        except (TypeError, ValueError):
            received_at = None

        emails.append({
            "id": msg["id"],
            "sender": _header(headers, "From"),
            "subject": _header(headers, "Subject"),
            "snippet": msg.get("snippet", ""),
            "received_at": received_at,
            "labels": msg.get("labelIds", []),
            "link": f"https://mail.google.com/mail/u/0/#inbox/{msg['id']}",
        })

    return emails


def main() -> int:
    config = load_config()
    if not config.gmail_client_secret_file:
        print("GMAIL_CLIENT_SECRET_FILE is not set; see python/.env.example", file=sys.stderr)
        return 1

    creds = _load_credentials(config.gmail_client_secret_file, config.gmail_token_file)
    service = build("gmail", "v1", credentials=creds)

    emails = fetch_important_emails(service, config.gmail_query, config.gmail_max_results)
    emails.sort(key=lambda e: e["received_at"] or "", reverse=True)

    write_digest(
        os.path.join(config.vault_inbox_dir, "email_digest.json"),
        {"emails": emails},
    )
    print(f"Wrote {len(emails)} emails to {config.vault_inbox_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
