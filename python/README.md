# Vault scrapers + local agent

Standalone scripts that pull Slack DMs/@-mentions, important Gmail messages,
your day's Google Calendar layout, and a combined todos list, writing them
as JSON into a `_inbox` folder inside your Obsidian vault. That folder is
synced to the phone (e.g. via Syncthing) the same way your notes are, so the
MY OS app can read the digests without any networking of its own — these
run wherever you have Python and network access (a laptop, a home server,
a Raspberry Pi), not on the phone.

The `agent/` package additionally runs a small local AI (via [Ollama]) on
that same machine: it writes a daily plan digest and exposes a chat
endpoint the phone app can talk to over your home Wi-Fi.

[Ollama]: https://ollama.com

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
- `VAULT_ROOT_DIR` — the vault itself (the parent of `VAULT_INBOX_DIR`),
  used by the todos aggregator and the agent to read your notes.

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

### Google Calendar

1. In the same Google Cloud project, enable the **Calendar API**.
2. By default the calendar scraper reuses `GMAIL_CLIENT_SECRET_FILE`; set
   `GOOGLE_CALENDAR_CLIENT_SECRET_FILE` instead if you'd rather use a
   separate OAuth client.
3. Set `GOOGLE_CALENDAR_IDS` to your calendars (comma-separated — `primary`
   is your main calendar; others look like
   `xxxx@group.calendar.google.com`, found under each calendar's
   **Settings → Integrate calendar**), and `GOOGLE_CALENDAR_LABELS` with a
   matching label per calendar (e.g. `personal,work,school`).

### Todos

No setup beyond `VAULT_ROOT_DIR` — it scans your vault's Markdown files for
open checkboxes (`- [ ] ...`). See `todos_aggregator.py`'s module docstring
for the due-date/tag syntax it understands. Tag a checkbox `#hw` to have it
surface in the app's Academics screen as outstanding homework.

### Local agent

1. Install [Ollama](https://ollama.com) on the machine that'll run the
   scrapers, and pull a small model: `ollama pull llama3.2` (or a Kimi/Qwen
   model — anything that fits your hardware, e.g. a Jetson Nano).
2. Set `OLLAMA_MODEL` to whatever you pulled.
3. Leave `AGENT_HOST=127.0.0.1` if you only want to test locally, or set it
   to `0.0.0.0` so your phone can reach it over the home network. The chat
   endpoint is unauthenticated — only do this on a trusted home network.

## Running

```bash
python slack_scraper.py
python gmail_scraper.py
python calendar_scraper.py
python todos_aggregator.py        # run after the two scrapers above
python -m agent.plan_digest       # one-shot: writes today's plan digest
python -m agent.server            # long-running: chat endpoint at /chat
```

The first Gmail/Calendar run opens a browser window for the OAuth consent
screen; afterwards they refresh silently from the cached token.

## Scheduling

Run the scrapers and the todos aggregator on a cron schedule so the digests
stay fresh, e.g. every 15 minutes (todos last, since it folds the others in):

```cron
*/15 * * * * cd /path/to/MY_OS/python && .venv/bin/python slack_scraper.py >> scraper.log 2>&1
*/15 * * * * cd /path/to/MY_OS/python && .venv/bin/python gmail_scraper.py >> scraper.log 2>&1
*/15 * * * * cd /path/to/MY_OS/python && .venv/bin/python calendar_scraper.py >> scraper.log 2>&1
*/16 * * * * cd /path/to/MY_OS/python && .venv/bin/python todos_aggregator.py >> scraper.log 2>&1
0 7 * * * cd /path/to/MY_OS/python && .venv/bin/python -m agent.plan_digest >> agent.log 2>&1
```

Run the agent's chat server as a long-lived service instead (e.g. a systemd
unit or `screen`/`tmux` session) rather than from cron:

```bash
.venv/bin/python -m agent.server
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

`<VAULT_INBOX_DIR>/calendar_digest.json`:

```json
{
  "generated_at": "2026-06-20T15:00:00+00:00",
  "events": [
    {
      "label": "work",
      "summary": "Standup",
      "start": "2026-06-20T09:00:00-04:00",
      "end": "2026-06-20T09:15:00-04:00",
      "all_day": false
    }
  ],
  "suggestions": [
    {
      "start": "2026-06-20T09:15:00-04:00",
      "end": "2026-06-20T11:00:00-04:00",
      "type": "exercise",
      "reason": "Open block with no workout logged yet today."
    }
  ]
}
```

`<VAULT_INBOX_DIR>/todos_digest.json`:

```json
{
  "generated_at": "2026-06-20T15:00:00+00:00",
  "today": [
    {
      "id": "a1b2c3d4e5f6a7b8",
      "text": "Standup (work) at 2026-06-20T09:00:00-04:00",
      "source": "calendar",
      "due": "2026-06-20",
      "origin": "work"
    }
  ],
  "overarching": [
    {
      "id": "9f8e7d6c5b4a3f2e",
      "text": "Keep applying to internships #ongoing",
      "source": "vault",
      "due": null,
      "origin": "Career/job-search.md"
    }
  ]
}
```

`<VAULT_INBOX_DIR>/plan_digest.json`:

```json
{
  "generated_at": "2026-06-20T07:00:00+00:00",
  "summary": "- Standup at 9am, then a free block — good time for a workout.\n- Lab report due Thursday, not urgent today.\n..."
}
```

All files are written atomically (temp file + rename), so a sync client
never observes a half-written file.
