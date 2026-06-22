# MY_OS — What This App Is

A personal "secretary" dashboard. It **informs**, it doesn't act on your behalf — you stay the one deciding what to do, the app just keeps you from missing things or losing track of what matters.

## How it's built, end to end

1. **Python scripts run on your own hardware** (laptop, mini PC, or eventually a Jetson Nano) — not in any cloud or sandbox. They have real network access and real credentials (Slack token, Google OAuth, etc).
2. Each script scrapes one source and writes a small **JSON "digest" file** into your Obsidian vault's `_inbox/` folder:
   - `slack_digest.json` — DMs and @mentions (already built)
   - `email_digest.json` — important Gmail (already built)
   - `calendar_digest.json` — work / personal / school calendars merged into one day-layout, with suggested gaps for exercise, winding down, or studying (**new**)
   - `todos_digest.json` — todos pulled out of your Obsidian notes, calendar (time-linked items like meetings become timed todos), and email action items — split into "today" vs. "important, ongoing" (**new**)
3. Your vault (notes + all the digest files above) **syncs to your phone via Syncthing** — the same way it does today.
4. **The Flutter app only ever reads local files on your phone.** It does no networking itself. It reads the digests and your notes, and presents them.
5. A **local AI agent** (Ollama, running on the same home hardware as the scrapers) reads your vault and all the digests, and:
   - writes its own `plan_digest.json` with daily suggestions, the same way the scrapers do, and
   - runs a small local server you can talk to — the phone app has a **chat screen** that asks it questions directly when you're on the same network.

So: scraping/AI happens at home, where there's power, internet, and a model. The phone app is a lightweight reader/chat-client over files that sync in.

## Screens (Core — front and center)

- **Today** (home): the day's layout from your calendars, suggested windows for exercise/reading/studying, and the agent's top suggestions.
- **Todos**: today's todos + overarching todos to chip away at, including ones auto-created from timed calendar events.
- **Inbox**: Slack + Gmail items that need a response (already built, kept as-is).
- **Agent Chat**: ask the local agent to find something in your notes or help you re-plan.
- **Academics**: kept and reworked — instead of manual grade entry only, it also surfaces homework assignments still outstanding (from email/calendar/notes) and calculates what grades you'd need going forward to hit a target GPA.
- **Notes**: your existing Obsidian vault browser, unchanged.

## Screens (Optional — moved off the main dashboard)

Tucked into a secondary "More" area so they don't compete with Core:

- **Financial**: spending, investments (Yahoo Finance), opportunity alerts.
- **Health**: sleep/workout data (Samsung Health / Google Health), plus a quick stress check-in.

## What already exists vs. what's new

| Piece | Status |
|---|---|
| Slack/Gmail scrapers + Inbox screen | Already built, kept |
| Calendar (3 calendars, day-layout) | Currently live in-app OAuth — moving to a Python scraper + digest, like Slack/Gmail |
| Todos | Currently a placeholder UI with no data — building the real engine |
| Local AI agent + chat | New |
| Academics overhaul | New logic on top of existing GPA screen |
| Financial / Health | Already built, just relocating in the nav |

If this matches what you had in mind, say so and I'll turn it into the full implementation plan.
