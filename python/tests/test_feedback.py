import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from agent.feedback import record_feedback


class RecordFeedbackTests(unittest.TestCase):
    def test_creates_file_with_header_on_first_write(self):
        with tempfile.TemporaryDirectory() as vault_root:
            record_feedback(vault_root, "Reply to bank email", "work", "personal", "today", "today", "it's my own account")
            path = os.path.join(vault_root, "Feedback Log.md")
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            self.assertIn("# Feedback Log", content)
            self.assertIn("Reply to bank email", content)
            self.assertIn("it's my own account", content)

    def test_appends_without_duplicating_header(self):
        with tempfile.TemporaryDirectory() as vault_root:
            record_feedback(vault_root, "First item", "work", "work", "today", "today")
            record_feedback(vault_root, "Second item", "personal", "other", "this_week", "overarching", "end of month thing")
            path = os.path.join(vault_root, "Feedback Log.md")
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            self.assertEqual(content.count("# Feedback Log"), 1)
            self.assertIn("First item", content)
            self.assertIn("Second item", content)
            self.assertIn("end of month thing", content)

    def test_pipe_characters_in_reason_are_escaped(self):
        with tempfile.TemporaryDirectory() as vault_root:
            record_feedback(vault_root, "Item", None, None, None, None, "a | b")
            path = os.path.join(vault_root, "Feedback Log.md")
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            self.assertIn("a \\| b", content)


if __name__ == "__main__":
    unittest.main()
