"""Tiny local HTTP server that lets the phone app chat with the local Ollama
agent over the home network. Run this on the same machine as Ollama (and the
scrapers) — see python/README.md.

It is unauthenticated, so only bind AGENT_HOST to a trusted home network —
the default is localhost-only.
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

from agent.ollama_client import OllamaError, generate
from agent.vault_context import build_context
from common.config import Config, load_config

SYSTEM_PREAMBLE = (
    "You are a personal secretary AI. You inform the user of what's "
    "important; you never claim to have taken an action on their behalf. "
    "Use the context to answer the user's question concisely.\n\n"
)


class ChatHandler(BaseHTTPRequestHandler):
    config: Config

    def _send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:
        if self.path != "/chat":
            self._send_json(404, {"error": "not found"})
            return

        length = int(self.headers.get("Content-Length", "0"))
        try:
            payload = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
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
            self._send_json(502, {"error": str(e)})
            return

        self._send_json(200, {"reply": reply.strip()})

    def log_message(self, format: str, *args) -> None:
        sys.stderr.write("agent: " + (format % args) + "\n")


def main() -> int:
    config = load_config()
    ChatHandler.config = config
    server = HTTPServer((config.agent_host, config.agent_port), ChatHandler)
    print(f"Agent chat server listening on http://{config.agent_host}:{config.agent_port}/chat")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
