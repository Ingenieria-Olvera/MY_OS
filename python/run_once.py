"""One-shot entrypoint: runs every scraper + todos_aggregator a single time,
then exits. Same code path `agent/scheduler.py`'s background loop uses (see
`agent/scheduler.run_once`), but as a short-lived process — meant to be
triggered by Windows Task Scheduler on workstation unlock/wake, so digests
refresh immediately instead of waiting for the next interval tick.
"""
from agent.scheduler import run_once


def main() -> int:
    run_once()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
