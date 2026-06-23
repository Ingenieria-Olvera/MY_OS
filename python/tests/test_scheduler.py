import os
import sys
import types
import unittest
from dataclasses import replace
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from agent import scheduler  # noqa: E402
from common.config import Config  # noqa: E402


def _config(**overrides) -> Config:
    base = Config(
        vault_inbox_dir="/tmp/inbox",
        slack_user_token=None,
        slack_lookback_hours=24,
        gmail_query="is:unread",
        gmail_max_results=25,
    )
    return replace(base, **overrides)


def _fake_module(name: str, main: MagicMock) -> types.ModuleType:
    module = types.ModuleType(name)
    module.main = main
    return module


class RunOnceTests(unittest.TestCase):
    def setUp(self):
        # Stand in for the real scraper modules so run_once()'s `import
        # slack_scraper` etc. picks these up from sys.modules instead of
        # executing the real files, which pull in slack_sdk/googleapiclient
        # (real network-facing dependencies irrelevant to the loop's own
        # ordering/error-isolation behavior under test here).
        self.slack_main = MagicMock()
        self.gmail_main = MagicMock()
        self.calendar_main = MagicMock()
        self.todos_main = MagicMock()
        modules = {
            "slack_scraper": _fake_module("slack_scraper", self.slack_main),
            "gmail_scraper": _fake_module("gmail_scraper", self.gmail_main),
            "calendar_scraper": _fake_module("calendar_scraper", self.calendar_main),
            "todos_aggregator": _fake_module("todos_aggregator", self.todos_main),
        }
        patcher = patch.dict(sys.modules, modules)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_runs_every_scraper_with_todos_aggregator_last(self):
        calls = []
        self.slack_main.side_effect = lambda: calls.append("slack")
        self.gmail_main.side_effect = lambda: calls.append("gmail")
        self.calendar_main.side_effect = lambda: calls.append("calendar")
        self.todos_main.side_effect = lambda: calls.append("todos")

        scheduler.run_once()

        self.assertEqual(calls, ["slack", "gmail", "calendar", "todos"])

    def test_one_scraper_raising_does_not_stop_the_others(self):
        self.slack_main.side_effect = RuntimeError("expired token")

        scheduler.run_once()

        self.gmail_main.assert_called_once()
        self.calendar_main.assert_called_once()
        self.todos_main.assert_called_once()


class StartBackgroundTests(unittest.TestCase):
    def test_disabled_by_default_starts_no_thread(self):
        with patch("agent.scheduler.threading.Thread") as thread_cls:
            scheduler.start_background(_config(auto_scrape_interval_minutes=0))
        thread_cls.assert_not_called()

    def test_positive_interval_starts_a_daemon_thread(self):
        with patch("agent.scheduler.threading.Thread") as thread_cls:
            scheduler.start_background(_config(auto_scrape_interval_minutes=15))
        thread_cls.assert_called_once()
        _, kwargs = thread_cls.call_args
        self.assertTrue(kwargs["daemon"])
        thread_cls.return_value.start.assert_called_once()


if __name__ == "__main__":
    unittest.main()
