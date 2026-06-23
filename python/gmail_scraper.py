"""Fetch important/unread Gmail messages across one or more Google accounts
and write them to the vault inbox as JSON for the MY OS app to read.

Each configured account (see GOOGLE_ACCOUNTS in python/.env.example) shares
its OAuth scopes with calendar_scraper.py (see common/google_auth.py) — the
first run of either script against a given account requests both scopes
together, so only one browser consent per account is ever needed. After
that, the account's cached token file makes subsequent (e.g. cron) runs
non-interactive. See python/README.md.
"""
import os
from email.utils import parsedate_to_datetime
from typing import List, Tuple

from common.config import load_config
from common.digest_writer import write_digest, write_markdown_digest


def _header(headers: List[dict], name: str) -> str:
    for h in headers:
        if h["name"].lower() == name.lower():
            return h["value"]
    return ""


def fetch_important_emails(service, queries: List[Tuple[str, str]], max_results: int) -> List[dict]:
    """Run each (label, query) search and merge the results, de-duplicated by
    message id — a message matching more than one query (e.g. both the
    "important" and "keyword" searches) is kept once, tagged with every
    label that matched it."""
    emails_by_id = {}

    for label, query in queries:
        if not query:
            continue
        resp = service.users().messages().list(userId="me", q=query, maxResults=max_results).execute()

        for item in resp.get("messages", []):
            existing = emails_by_id.get(item["id"])
            if existing:
                existing["matched"].append(label)
                continue

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

            emails_by_id[msg["id"]] = {
                "id": msg["id"],
                "sender": _header(headers, "From"),
                "subject": _header(headers, "Subject"),
                "snippet": msg.get("snippet", ""),
                "received_at": received_at,
                "labels": msg.get("labelIds", []),
                "link": f"https://mail.google.com/mail/u/0/#inbox/{msg['id']}",
                "matched": [label],
            }

    return list(emails_by_id.values())


def main() -> int:
    from googleapiclient.discovery import build

    from common.google_auth import GOOGLE_SCOPES, load_credentials

    config = load_config()
    queries = [("important", config.gmail_query)]
    if config.gmail_keyword_query:
        queries.append(("keyword", config.gmail_keyword_query))

    emails = []
    for account, creds_file, token_file in config.google_account_triples():
        creds = load_credentials(creds_file, token_file, GOOGLE_SCOPES)
        service = build("gmail", "v1", credentials=creds)
        account_emails = fetch_important_emails(service, queries, config.gmail_max_results)
        for email in account_emails:
            email["account"] = account
        emails += account_emails

    emails.sort(key=lambda e: e["received_at"] or "", reverse=True)

    write_digest(
        os.path.join(config.vault_inbox_dir, "email_digest.json"),
        {"emails": emails},
    )
    
    # Generate email_digest.md for Obsidian
    from datetime import datetime
    md_content = f"# ✉️ Email Digest\n*Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*\n\n"
    if not emails:
        md_content += "No unread/important emails.\n"
    for email in emails:
        sender = email.get("sender", "Unknown")
        subject = email.get("subject", "No Subject")
        snippet = email.get("snippet", "")
        link = email.get("link", "")
        matched = email.get("matched", [])
        tag = " 🔑" if "keyword" in matched else ""
        md_content += f"- [ ] **{sender}**: {subject}{tag}\n"
        if snippet:
            md_content += f"  > {snippet}\n"
        if link:
            md_content += f"  > [View in Gmail]({link})\n"
        md_content += "\n"
        
    write_markdown_digest(
        os.path.join(config.vault_inbox_dir, "email_digest.md"),
        md_content
    )
    
    print(f"Wrote {len(emails)} emails to {config.vault_inbox_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
