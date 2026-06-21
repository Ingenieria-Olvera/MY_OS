"""Minimal client for a local Ollama instance, using only the standard
library so the agent stays easy to run on something as small as a Jetson
Nano (no extra pip dependencies)."""
import json
import urllib.error
import urllib.request


class OllamaError(RuntimeError):
    pass


def generate(prompt: str, host: str, model: str, timeout: int = 60) -> str:
    url = f"{host.rstrip('/')}/api/generate"
    body = json.dumps({"model": model, "prompt": prompt, "stream": False}).encode("utf-8")
    request = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            data = json.loads(response.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
        raise OllamaError(
            f"Could not reach Ollama at {host} with model '{model}': {e}"
        ) from e

    return data.get("response", "")
