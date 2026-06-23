"""Tiny local HTTP server that lets the phone app chat with the local Ollama
agent over the home network. Run this on the same machine as Ollama (and the
scrapers) — see python/README.md.

It is unauthenticated, so only bind AGENT_HOST to a trusted home network —
the default is localhost-only.

GET /digest/<name>  — serves the named digest JSON from VAULT_INBOX_DIR.
  Valid names: email, calendar, todos, slack.
  The Flutter app uses these to fetch fresh digests directly from the machine
  running the scrapers, bypassing Syncthing latency.

POST /chat          — send a message to the local Ollama agent.
POST /feedback      — log a category/urgency correction to Feedback Log.md.
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Optional

from agent import scheduler
from agent.feedback import record_feedback
from agent.ollama_client import OllamaError, generate
from agent.vault_context import build_context
from common.config import Config, load_config

SYSTEM_PREAMBLE = (
    "You are a personal secretary AI. You inform the user of what's "
    "important; you never claim to have taken an action on their behalf. "
    "Use the context to answer the user's question concisely.\n\n"
)

# Map of URL path segment -> digest filename inside VAULT_INBOX_DIR
_DIGEST_FILES = {
    "email": "email_digest.json",
    "calendar": "calendar_digest.json",
    "todos": "todos_digest.json",
    "slack": "slack_digest.json",
}


class ChatHandler(BaseHTTPRequestHandler):
    config: Config

    def _send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:
        if self.path == "/chat":
            self._handle_chat()
        elif self.path == "/feedback":
            self._handle_feedback()
        else:
            self._send_json(404, {"error": "not found"})

    def _read_json_body(self) -> Optional[dict]:
        length = int(self.headers.get("Content-Length", "0"))
        try:
            return json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            return None

    def _handle_chat(self) -> None:
        payload = self._read_json_body()
        if payload is None:
            self._send_json(400, {"error": "invalid JSON body"})
            return

        message = (payload.get("message") or "").strip()
        if not message:
            self._send_json(400, {"error": "'message' is required"})
            return

        context = build_context(self.config.vault_root_dir, self.config.vault_inbox_dir)
        prompt = f"{SYSTEM_PREAMBLE}Context:\n{context}\n\nUser: {message}\nSecretary:"

        try:
            reply = generate(prompt, host=self.config.ollama_host, model=self.config.ollama_model)
        except OllamaError as e:
            # Return a friendly 200 so the app doesn't go into an error loop.
            self._send_json(200, {
                "reply": (
                    "⚠️ I can't reach the local AI model right now. "
                    f"Make sure Ollama is running on this machine "
                    f"(`ollama serve`) and that the model '{self.config.ollama_model}' "
                    f"is pulled (`ollama pull {self.config.ollama_model}`). "
                    "I'll be back as soon as it's available!"
                )
            })
            return

        reply_str = reply.strip()

        # Append to Chat Log.md in vault_inbox_dir
        if self.config.vault_inbox_dir:
            from datetime import datetime
            chat_log_path = os.path.join(self.config.vault_inbox_dir, "Chat Log.md")
            now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            mode = "a" if os.path.exists(chat_log_path) else "w"
            try:
                with open(chat_log_path, mode, encoding="utf-8") as f:
                    if mode == "w":
                        f.write("# Secretary Chat Log\n\n")
                    f.write(f"## {now}\n")
                    f.write(f"**User**: {message}\n\n")
                    f.write(f"**Secretary**: {reply_str}\n\n---\n\n")
            except OSError:
                pass

        self._send_json(200, {"reply": reply_str})

    def _handle_feedback(self) -> None:
        """Logs a correction to a suggested category/urgency (with an
        optional free-text reason) to `Feedback Log.md` in the vault — the
        app's "why wasn't this right" input lands here. See agent/feedback.py."""
        if not self.config.vault_inbox_dir:
            self._send_json(500, {"error": "VAULT_INBOX_DIR is not set"})
            return

        payload = self._read_json_body()
        if payload is None:
            self._send_json(400, {"error": "invalid JSON body"})
            return

        text = (payload.get("text") or "").strip()
        if not text:
            self._send_json(400, {"error": "'text' is required"})
            return

        record_feedback(
            self.config.vault_inbox_dir,
            text,
            payload.get("suggested_category"),
            payload.get("chosen_category"),
            payload.get("suggested_urgency"),
            payload.get("chosen_urgency"),
            payload.get("reason"),
        )
        self._send_json(200, {"ok": True})

    def _handle_todos_toggle(self) -> None:
        if not self.config.vault_root_dir:
            self._send_json(500, {"error": "VAULT_ROOT_DIR is not set"})
            return

        payload = self._read_json_body()
        if payload is None:
            self._send_json(400, {"error": "invalid JSON body"})
            return

        text = (payload.get("text") or "").strip()
        if not text:
            self._send_json(400, {"error": "'text' is required"})
            return

        todos_dir = os.path.join(self.config.vault_root_dir, "Todos")
        os.makedirs(todos_dir, exist_ok=True)
        finished_file = os.path.join(todos_dir, "Finished.md")
        
        found = False
        import re
        checkbox_re = re.compile(r"^(.*?-\s*\[) (\]\s*" + re.escape(text) + r".*)$", re.IGNORECASE)
        
        # Search all md files, but preferably Todos/ first
        for root, dirs, files in os.walk(self.config.vault_root_dir):
            dirs[:] = [d for d in dirs if not d.startswith(".") and d != "_inbox"]
            for name in files:
                if not name.endswith(".md"): continue
                path = os.path.join(root, name)
                try:
                    with open(path, "r", encoding="utf-8") as f:
                        lines = f.readlines()
                except OSError:
                    continue
                
                changed = False
                for i, line in enumerate(lines):
                    if checkbox_re.match(line):
                        # Replace [ ] with [x]
                        new_line = checkbox_re.sub(r"\1x\2", line)
                        lines.pop(i) # remove from current file
                        changed = True
                        
                        # Append to Finished.md
                        try:
                            mode = "a" if os.path.exists(finished_file) else "w"
                            with open(finished_file, mode, encoding="utf-8") as ff:
                                if mode == "w":
                                    ff.write("# Finished Todos\n\n")
                                ff.write(new_line.strip() + "\n")
                        except OSError as e:
                            self.log_message(f"Could not write to Finished.md: {e}")
                        
                        found = True
                        break # Only toggle first match
                
                if changed:
                    try:
                        with open(path, "w", encoding="utf-8") as f:
                            f.writelines(lines)
                    except OSError:
                        pass
                
                if found: break
            if found: break
            
        self._send_json(200, {"ok": True, "found": found})

    def _handle_calendar_add(self) -> None:
        payload = self._read_json_body()
        if not payload or not payload.get("summary") or not payload.get("start") or not payload.get("end"):
            self._send_json(400, {"error": "Missing summary, start, or end"})
            return
            
        account = payload.get("account")
        
        from googleapiclient.discovery import build
        from common.google_auth import GOOGLE_SCOPES, load_credentials
        
        account_files = {acc: (cf, tf) for acc, cf, tf in self.config.google_account_triples()}
        if not account or account not in account_files:
            account = next(iter(account_files.keys()))
            
        creds_file, token_file = account_files[account]
        creds = load_credentials(creds_file, token_file, GOOGLE_SCOPES)
        service = build("calendar", "v3", credentials=creds)
        
        event = {
            'summary': payload['summary'],
            'start': {'dateTime': payload['start']},
            'end': {'dateTime': payload['end']},
        }
        
        try:
            created_event = service.events().insert(calendarId='primary', body=event).execute()
            self._send_json(200, {"ok": True, "event": created_event})
        except Exception as e:
            self._send_json(500, {"error": str(e)})

    def _handle_calendar_delete(self) -> None:
        payload = self._read_json_body()
        if not payload or not payload.get("id"):
            self._send_json(400, {"error": "Missing event id"})
            return
            
        account = payload.get("account")
        from googleapiclient.discovery import build
        from common.google_auth import GOOGLE_SCOPES, load_credentials
        
        account_files = {acc: (cf, tf) for acc, cf, tf in self.config.google_account_triples()}
        if not account or account not in account_files:
            account = next(iter(account_files.keys()))
            
        creds_file, token_file = account_files[account]
        creds = load_credentials(creds_file, token_file, GOOGLE_SCOPES)
        service = build("calendar", "v3", credentials=creds)
        
        try:
            service.events().delete(calendarId='primary', eventId=payload['id']).execute()
            self._send_json(200, {"ok": True})
        except Exception as e:
            self._send_json(500, {"error": str(e)})

    def _handle_feedback(self) -> None:
        """Logs a correction to a suggested category/urgency (with an
        optional free-text reason) to `Feedback Log.md` in the vault — the
        app's "why wasn't this right" input lands here. See agent/feedback.py."""
        if not self.config.vault_root_dir:
            self._send_json(500, {"error": "VAULT_ROOT_DIR is not set"})
            return

        payload = self._read_json_body()
        if payload is None:
            self._send_json(400, {"error": "invalid JSON body"})
            return

        text = (payload.get("text") or "").strip()
        if not text:
            self._send_json(400, {"error": "'text' is required"})
            return

        record_feedback(
            self.config.vault_root_dir,
            text,
            payload.get("suggested_category"),
            payload.get("chosen_category"),
            payload.get("suggested_urgency"),
            payload.get("chosen_urgency"),
            payload.get("reason"),
        )
        self._send_json(200, {"ok": True})

    def log_message(self, format: str, *args) -> None:
        sys.stderr.write("agent: " + (format % args) + "\n")


import time

def _print_step(msg: str) -> None:
    print(f"[......] {msg}", end="\r", flush=True)
    time.sleep(0.2)
    print(f"[  OK  ] {msg}")

def main() -> int:
    print("Starting Secretary Agent...\n")
    
    _print_step("Loading configuration")
    config = load_config()
    ChatHandler.config = config
    scheduler.start_background(config)
    server = HTTPServer((config.agent_host, config.agent_port), ChatHandler)
    
    print("\n" + "="*50)
    print(f"✅ Agent chat server listening on http://{config.agent_host}:{config.agent_port}/chat")
    print(f"✅ Digest endpoints: /digest/{{email,calendar,todos,slack}}")
    print("="*50 + "\n")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
