import os
import sys
import tempfile
import unittest
from datetime import date

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from todos_aggregator import classify, parse_vault_todos, todos_from_calendar, todos_from_emails  # noqa: E402


class ParseVaultTodosTests(unittest.TestCase):
    def test_parses_open_checkboxes_with_due_date_and_tags(self):
        with tempfile.TemporaryDirectory() as vault:
            with open(os.path.join(vault, "note.md"), "w", encoding="utf-8") as f:
                f.write(
                    "- [ ] Finish lab report 📅 2026-06-25\n"
                    "- [ ] Keep applying to internships #ongoing\n"
                    "- [x] Already done, should be skipped\n"
                )
            todos = parse_vault_todos(vault)

        self.assertEqual(len(todos), 2)
        due_todo = next(t for t in todos if "lab report" in t["text"])
        self.assertEqual(due_todo["due"], "2026-06-25")
        ongoing_todo = next(t for t in todos if "internships" in t["text"])
        self.assertTrue(ongoing_todo["ongoing"])

    def test_parses_personal_and_work_category_tags(self):
        with tempfile.TemporaryDirectory() as vault:
            with open(os.path.join(vault, "note.md"), "w", encoding="utf-8") as f:
                f.write(
                    "- [ ] Call mom #personal\n"
                    "- [ ] Ship the report #work\n"
                    "- [ ] Untagged item\n"
                )
            todos = parse_vault_todos(vault)

        categories = {t["text"]: t["category"] for t in todos}
        self.assertEqual(categories["Call mom #personal"], "personal")
        self.assertEqual(categories["Ship the report #work"], "work")
        self.assertIsNone(categories["Untagged item"])

    def test_skips_inbox_folder(self):
        with tempfile.TemporaryDirectory() as vault:
            inbox = os.path.join(vault, "_inbox")
            os.makedirs(inbox)
            with open(os.path.join(inbox, "scratch.md"), "w", encoding="utf-8") as f:
                f.write("- [ ] Should not be picked up\n")
            todos = parse_vault_todos(vault)

        self.assertEqual(todos, [])


class FromDigestTests(unittest.TestCase):
    def test_calendar_events_become_today_todos(self):
        digest = {"events": [{"summary": "Standup", "label": "work", "start": "2026-06-21T09:00:00", "all_day": False}]}
        todos = todos_from_calendar(digest, "2026-06-21")
        self.assertEqual(len(todos), 1)
        self.assertTrue(todos[0]["force_today"])

    def test_all_day_calendar_events_are_skipped(self):
        digest = {"events": [{"summary": "Birthday", "label": "personal", "start": "2026-06-21", "all_day": True}]}
        self.assertEqual(todos_from_calendar(digest, "2026-06-21"), [])

    def test_emails_become_today_todos(self):
        digest = {"emails": [{"id": "1", "subject": "Budget", "sender": "Alice"}]}
        todos = todos_from_emails(digest, "2026-06-21")
        self.assertEqual(len(todos), 1)
        self.assertIn("Budget", todos[0]["text"])


class ClassifyTests(unittest.TestCase):
    def test_buckets_by_due_date_and_tags(self):
        today = date(2026, 6, 21)
        todos = [
            {"id": "a", "text": "due today", "due": "2026-06-21", "ongoing": False, "force_today": False},
            {"id": "b", "text": "overdue", "due": "2026-06-01", "ongoing": False, "force_today": False},
            {"id": "c", "text": "future", "due": "2026-07-01", "ongoing": False, "force_today": False},
            {"id": "d", "text": "no date, ongoing tag", "due": None, "ongoing": True, "force_today": False},
            {"id": "e", "text": "no date at all", "due": None, "ongoing": False, "force_today": False},
            {"id": "f", "text": "forced today", "due": "2026-07-01", "ongoing": False, "force_today": True},
        ]
        buckets = classify(todos, today)

        self.assertEqual({t["id"] for t in buckets["today"]}, {"a", "b", "f"})
        self.assertEqual({t["id"] for t in buckets["overarching"]}, {"c", "d", "e"})

    def test_preserves_category_through_classification(self):
        today = date(2026, 6, 21)
        todos = [
            {
                "id": "a", "text": "work item", "due": "2026-06-21",
                "ongoing": False, "force_today": False, "category": "work",
            },
        ]
        buckets = classify(todos, today)
        self.assertEqual(buckets["today"][0]["category"], "work")


if __name__ == "__main__":
    unittest.main()
