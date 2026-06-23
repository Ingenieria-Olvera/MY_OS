"""Runs the vault scrapers + todos aggregator on a fixed interval in a
background thread, as an alternative to cron for keeping the digests fresh.

Cron (python/README.md's documented approach) doesn't exist on Windows, so
this lets `agent/server.py` — already a long-running process once you start
it — drive the same scrapers itself. Enable it by setting
AUTO_SCRAPE_INTERVAL_MINUTES in .env (see python/.env.example); leave it at
0 (the default) to keep scheduling scrapers some other way (cron, Task
Scheduler, manual runs).
"""
import sys
import threading
import time
import traceback
from typing import Callable

from common.config import Config

# Imported lazily inside run_once() rather than at module load time so that
# importing agent.scheduler (e.g. from tests) doesn't require every
# scraper's third-party deps (slack_sdk, googleapiclient, ...) to be
# installed and configured just to exercise the loop itself.


def _run_step(name: str, fn: Callable[[], int]) -> None:
    try:
        fn()
    except Exception:
        # A single scraper failing (expired token, no network, an account
        # that was never granted consent) must never take down the others
        # or stop the loop from trying again next interval.
        print(f"[scheduler] {name} failed:", file=sys.stderr)
        traceback.print_exc()


def run_once() -> None:
    """Runs every scraper once, todos_aggregator last so it folds the
    others' digests in."""
    import calendar_scraper
    import gmail_scraper
    import slack_scraper
    import todos_aggregator

    _run_step("slack_scraper", slack_scraper.main)
    _run_step("gmail_scraper", gmail_scraper.main)
    _run_step("calendar_scraper", calendar_scraper.main)
    _run_step("todos_aggregator", todos_aggregator.main)


def start_background(config: Config) -> None:
    """Starts the periodic-scrape loop on a daemon thread if
    AUTO_SCRAPE_INTERVAL_MINUTES is set; a no-op otherwise."""
    if config.auto_scrape_interval_minutes <= 0:
        return

    interval_seconds = config.auto_scrape_interval_minutes * 60

    def _loop() -> None:
        while True:
            run_once()
            time.sleep(interval_seconds)

    threading.Thread(target=_loop, name="scraper-scheduler", daemon=True).start()
    print(
        f"[scheduler] running scrapers every {config.auto_scrape_interval_minutes} "
        "minute(s) in the background"
    )
