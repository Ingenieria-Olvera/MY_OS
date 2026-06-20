# Vault scrapers

Two standalone scripts that pull Slack DMs/@-mentions and important Gmail
messages, and write them as JSON into a `_inbox` folder inside your Obsidian
vault. That folder is synced to the phone (e.g. via Syncthing) the same way
your notes are, so the MY OS app's Inbox screen can read the digests without
any networking of its own — they run wherever you have Python and network
access (a laptop, a home server, a Raspberry Pi), not on the phone.

## Setup

```bash
cd python
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Edit `.env`:

- `VAULT_INBOX_DIR` — the `_inbox` folder inside your synced vault, e.g.
  `/path/to/Cross_Study/_inbox`. Created automatically if it doesn't exist.

### Slack

1. Create an app at <https://api.slack.com/apps> (or reuse one).
2. Under **OAuth & Permissions**, add these scopes to the **User** Token
   Scopes section (not Bot Token Scopes — bot tokens can't use
   `search.messages`): `im:history`, `mpim:history`, `search:read`,
   `users:read`.
3. Install the app to your workspace and copy the **User OAuth Token**
   (starts with `xoxp-`) into `SLACK_USER_TOKEN`.

### Gmail

1. In [Google Cloud Console](https://console.cloud.google.com/), enable the
   Gmail API for a project and create an OAuth client ID of type
   **Desktop app**.
2. Download its client secret JSON and point `GMAIL_CLIENT_SECRET_FILE` at
   it.
3. Set `GMAIL_TOKEN_FILE` to wherever you want the refresh token cached
   (created on first run).

## Running

```bash
python slack_scraper.py
python gmail_scraper.py
```

The first Gmail run opens a browser window for the OAuth consent screen;
afterwards it refreshes silently from the cached token.

## Scheduling

Run both on a cron schedule so the digests stay fresh, e.g. every 15
minutes:

```cron
*/15 * * * * cd /path/to/MY_OS/python && .venv/bin/python slack_scraper.py >> scraper.log 2>&1
*/15 * * * * cd /path/to/MY_OS/python && .venv/bin/python gmail_scraper.py >> scraper.log 2>&1
```

## Output format

`<VAULT_INBOX_DIR>/slack_digest.json`:

```json
{
  "generated_at": "2026-06-20T15:00:00+00:00",
  "messages": [
    {
      "id": "1718900000.000100",
      "source": "dm",
      "channel": "D0123ABC",
      "sender": "Jane Doe",
      "text": "Can you take a look at this?",
      "timestamp": "2026-06-20T14:55:00+00:00"
    }
  ]
}
```

`<VAULT_INBOX_DIR>/email_digest.json`:

```json
{
  "generated_at": "2026-06-20T15:00:00+00:00",
  "emails": [
    {
      "id": "18f2a...",
      "sender": "Alice <alice@example.com>",
      "subject": "Q3 budget review",
      "snippet": "Hi, can we sync on...",
      "received_at": "2026-06-20T13:40:00+00:00",
      "labels": ["IMPORTANT", "INBOX", "UNREAD"],
      "link": "https://mail.google.com/mail/u/0/#inbox/18f2a..."
    }
  ]
}
```

Both files are written atomically (temp file + rename), so a sync client
never observes a half-written file.
