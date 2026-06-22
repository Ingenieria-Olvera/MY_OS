"""Fetch today's events across your Google calendars (work/personal/school,
or however you've split them, possibly spanning several Google accounts) and
write a merged day-layout digest with suggested gaps for exercise, winding
down, or studying.

Each configured account (see GOOGLE_ACCOUNTS in python/.env.example) shares
its OAuth scopes with gmail_scraper.py (see common/google_auth.py) — the
first run of either script against a given account requests both scopes
together, so only one browser consent per account is ever needed. See
python/README.md for setup and the GOOGLE_CALENDAR_IDS / GOOGLE_CALENDAR_LABELS
/ GOOGLE_CALENDAR_ACCOUNT env vars used to list your calendars.
"""
import os
import sys
from datetime import datetime, timedelta
from typing import List, Tuple

from common.config import Config, load_config
from common.digest_writer import write_digest, write_markdown_digest


def fetch_events_for_calendar(
    service, calendar_id: str, label: str, time_min: datetime, time_max: datetime
) -> List[dict]:
    events = []
    resp = service.events().list(
        calendarId=calendar_id,
        timeMin=time_min.isoformat(),
        timeMax=time_max.isoformat(),
        singleEvents=True,
        orderBy="startTime",
    ).execute()

    for item in resp.get("items", []):
        start = item.get("start", {})
        end = item.get("end", {})
        events.append({
            "label": label,
            "summary": item.get("summary", "(no title)"),
            "start": start.get("dateTime") or start.get("date"),
            "end": end.get("dateTime") or end.get("date"),
            "all_day": "date" in start,
        })
    return events


def compute_gaps(
    events: List[dict], day_start: datetime, day_end: datetime, min_gap_minutes: int
) -> List[Tuple[datetime, datetime]]:
    """Free windows of at least `min_gap_minutes` between timed events."""
    timed = sorted((e for e in events if not e["all_day"]), key=lambda e: e["start"])
    min_gap = timedelta(minutes=min_gap_minutes)

    gaps = []
    cursor = day_start
    for event in timed:
        start = datetime.fromisoformat(event["start"])
        end = datetime.fromisoformat(event["end"])
        if start > cursor and (start - cursor) >= min_gap:
            gaps.append((cursor, start))
        cursor = max(cursor, end)
    if day_end > cursor and (day_end - cursor) >= min_gap:
        gaps.append((cursor, day_end))
    return gaps


def suggest_for_gap(gap_start: datetime, gap_end: datetime, has_exercise_today: bool) -> dict:
    """Heuristic: evenings wind down, the first open daytime gap is exercise
    (if nothing exercise-related is already on the calendar today), and
    everything else defaults to study/focused work."""
    duration = gap_end - gap_start
    hour = gap_start.hour

    if hour >= 19 or hour < 6:
        kind, reason = "wind_down", "Evening gap — good time to read or wind down before bed."
    elif not has_exercise_today and duration >= timedelta(minutes=30):
        kind, reason = "exercise", "Open block with no workout logged yet today."
    elif duration >= timedelta(minutes=45):
        kind, reason = "study", "Solid open block — good for focused study or project work."
    else:
        kind, reason = "study", "Short gap — good for a quick study or admin task."

    return {
        "start": gap_start.isoformat(),
        "end": gap_end.isoformat(),
        "type": kind,
        "reason": reason,
    }


def build_day_layout(
    events: List[dict], day_start: datetime, day_end: datetime, min_gap_minutes: int
) -> List[dict]:
    has_exercise_today = any(
        "exercise" in e["summary"].lower() or "gym" in e["summary"].lower() or "workout" in e["summary"].lower()
        for e in events
    )

    suggestions = []
    for gap_start, gap_end in compute_gaps(events, day_start, day_end, min_gap_minutes):
        suggestion = suggest_for_gap(gap_start, gap_end, has_exercise_today)
        suggestions.append(suggestion)
        if suggestion["type"] == "exercise":
            has_exercise_today = True  # only suggest exercise once per day
    return suggestions


def _calendar_pairs(config: Config) -> List[Tuple[str, str, str]]:
    """(calendar_id, label, account) triples, positionally aligned across
    GOOGLE_CALENDAR_IDS/GOOGLE_CALENDAR_LABELS/GOOGLE_CALENDAR_ACCOUNT. A
    short labels list pads with the calendar id itself; a short accounts
    list pads by repeating its last entry."""
    ids = config.google_calendar_ids
    labels = config.google_calendar_labels
    accounts = config.google_calendar_accounts
    if len(labels) < len(ids):
        labels = labels + ids[len(labels):]
    if len(accounts) < len(ids):
        accounts = accounts + [accounts[-1]] * (len(ids) - len(accounts))
    return list(zip(ids, labels, accounts))


def main() -> int:
    # Imported lazily: these pull in network/crypto libs only needed here,
    # not by the pure scheduling logic above (which is unit tested).
    from googleapiclient.discovery import build
    from common.google_auth import GOOGLE_SCOPES, load_credentials

    config = load_config()
    account_files = {account: (cf, tf) for account, cf, tf in config.google_account_triples()}

    now = datetime.now().astimezone()
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start + timedelta(days=1)

    services: dict = {}
    events: List[dict] = []
    for calendar_id, label, account in _calendar_pairs(config):
        if account not in services:
            if account not in account_files:
                print(
                    f"Calendar '{calendar_id}' references unknown account '{account}'; "
                    "using the first configured account instead",
                    file=sys.stderr,
                )
            creds_file, token_file = account_files.get(account, next(iter(account_files.values())))
            creds = load_credentials(creds_file, token_file, GOOGLE_SCOPES)
            services[account] = build("calendar", "v3", credentials=creds)

        for event in fetch_events_for_calendar(services[account], calendar_id, label, day_start, day_end):
            event["account"] = account
            events.append(event)

    events.sort(key=lambda e: e["start"])

    suggestions = build_day_layout(events, max(day_start, now), day_end, config.calendar_min_gap_minutes)

    write_digest(
        os.path.join(config.vault_inbox_dir, "calendar_digest.json"),
        {"events": events, "suggestions": suggestions},
    )
    
    # Generate calendar_digest.md for Obsidian
    md_content = f"# 📅 Calendar Digest\n*Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*\n\n"
    md_content += "## Today's Schedule\n"
    if not events:
        md_content += "No events scheduled for today.\n"
    else:
        for event in events:
            time_str = ""
            if event.get("all_day"):
                time_str = "All Day"
            else:
                try:
                    start_dt = datetime.fromisoformat(event["start"])
                    end_dt = datetime.fromisoformat(event["end"])
                    time_str = f"{start_dt.strftime('%H:%M')} - {end_dt.strftime('%H:%M')}"
                except Exception:
                    time_str = event["start"]
            
            md_content += f"- **{time_str}** [{event.get('label', '')}] {event.get('summary', '')}\n"
            
    md_content += "\n## Gap Suggestions\n"
    if not suggestions:
        md_content += "No suggestions for today.\n"
    else:
        for sug in suggestions:
            try:
                start_dt = datetime.fromisoformat(sug["start"])
                end_dt = datetime.fromisoformat(sug["end"])
                time_str = f"{start_dt.strftime('%H:%M')} - {end_dt.strftime('%H:%M')}"
            except Exception:
                time_str = sug["start"]
            
            emoji = "🏋️" if sug["type"] == "exercise" else ("🛌" if sug["type"] == "wind_down" else "📖")
            md_content += f"- **{time_str}**: {emoji} **{sug['type'].upper()}** - {sug['reason']}\n"
            
    write_markdown_digest(
        os.path.join(config.vault_inbox_dir, "calendar_digest.md"),
        md_content
    )
    
    print(f"Wrote {len(events)} events and {len(suggestions)} suggestions to {config.vault_inbox_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
