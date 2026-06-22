"""Fetch direct messages and @-mentions from Slack and write them to the
vault inbox as JSON for the MY OS app to read.

Requires a Slack *user* token (not a bot token) with scopes:
    im:history, mpim:history, search:read, users:read

Run this on a schedule (cron) wherever it has network access; the output
JSON lands in the Obsidian vault folder that's synced to the phone.
"""
import os
import sys
from datetime import datetime, timedelta, timezone
from typing import Dict, List

from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

from common.config import load_config
from common.digest_writer import write_digest, write_markdown_digest


def _user_display_name(client: WebClient, user_cache: Dict[str, str], user_id: str) -> str:
    if not user_id:
        return "Unknown"
    if user_id in user_cache:
        return user_cache[user_id]
    try:
        info = client.users_info(user=user_id)["user"]
        name = info.get("real_name") or info.get("name") or user_id
    except SlackApiError:
        name = user_id
    user_cache[user_id] = name
    return name


def fetch_direct_messages(client: WebClient, since: datetime, user_cache: Dict[str, str]) -> List[dict]:
    messages = []
    oldest = str(since.timestamp())
    channel_cursor = None

    while True:
        channels_resp = client.conversations_list(types="im,mpim", cursor=channel_cursor, limit=200)
        for channel in channels_resp["channels"]:
            history_cursor = None
            while True:
                history_resp = client.conversations_history(
                    channel=channel["id"], oldest=oldest, cursor=history_cursor, limit=200
                )
                for msg in history_resp["messages"]:
                    if msg.get("subtype"):  # skip joins/leaves/system messages
                        continue
                    messages.append({
                        "id": msg["ts"],
                        "source": "dm",
                        "channel": channel["id"],
                        "sender": _user_display_name(client, user_cache, msg.get("user", "")),
                        "text": msg.get("text", ""),
                        "timestamp": datetime.fromtimestamp(float(msg["ts"]), tz=timezone.utc).isoformat(),
                    })
                history_cursor = history_resp.get("response_metadata", {}).get("next_cursor")
                if not history_cursor:
                    break
        channel_cursor = channels_resp.get("response_metadata", {}).get("next_cursor")
        if not channel_cursor:
            break

    return messages


def fetch_mentions(client: WebClient, since: datetime) -> List[dict]:
    me = client.auth_test()["user_id"]
    query = f"<@{me}> after:{since.strftime('%Y-%m-%d')}"
    messages = []
    page = 1

    while True:
        resp = client.search_messages(query=query, sort="timestamp", page=page, count=100)
        results = resp["messages"]
        for match in results["matches"]:
            messages.append({
                "id": match["ts"],
                "source": "mention",
                "channel": match.get("channel", {}).get("name", ""),
                "sender": match.get("username") or match.get("user", ""),
                "text": match.get("text", ""),
                "permalink": match.get("permalink"),
                "timestamp": datetime.fromtimestamp(float(match["ts"]), tz=timezone.utc).isoformat(),
            })
        paging = results.get("paging", {})
        if page >= paging.get("pages", 1):
            break
        page += 1

    return messages


def main() -> int:
    config = load_config()
    if not config.slack_user_token:
        print("SLACK_USER_TOKEN is not set; see python/.env.example", file=sys.stderr)
        return 1

    client = WebClient(token=config.slack_user_token)
    since = datetime.now(timezone.utc) - timedelta(hours=config.slack_lookback_hours)
    user_cache: Dict[str, str] = {}

    try:
        messages = fetch_direct_messages(client, since, user_cache)
        messages += fetch_mentions(client, since)
    except SlackApiError as e:
        print(f"Slack API error: {e.response['error']}", file=sys.stderr)
        return 1

    messages.sort(key=lambda m: m["timestamp"], reverse=True)
    write_digest(
        os.path.join(config.vault_inbox_dir, "slack_digest.json"),
        {"messages": messages},
    )
    
    # Generate slack_digest.md for Obsidian
    md_content = f"# 💬 Slack Digest\n*Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*\n\n"
    if not messages:
        md_content += "No new Slack messages or mentions.\n"
    for msg in messages:
        sender = msg.get("sender", "Unknown")
        channel = msg.get("channel", "")
        text = msg.get("text", "")
        permalink = msg.get("permalink", "")
        source_label = "DM" if msg.get("source") == "dm" else f"Mention in #{channel}"
        
        md_content += f"- [ ] **{sender}** ({source_label})\n"
        if text:
            md_content += f"  > {text}\n"
        if permalink:
            md_content += f"  > [Open in Slack]({permalink})\n"
        md_content += "\n"
        
    write_markdown_digest(
        os.path.join(config.vault_inbox_dir, "slack_digest.md"),
        md_content
    )
    
    print(f"Wrote {len(messages)} Slack messages to {config.vault_inbox_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
