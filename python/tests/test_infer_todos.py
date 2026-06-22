import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from agent.infer_todos import infer_todos_from_notes  # noqa: E402


class InferTodosFromNotesTests(unittest.TestCase):
    @patch("agent.infer_todos.generate")
    @patch("agent.infer_todos.recent_notes_with_content")
    def test_parses_json_array_response_into_todos(self, mock_notes, mock_generate):
        mock_notes.return_value = [("daily/2026-06-22.md", "Need to call the landlord about rent")]
        mock_generate.return_value = (
            '[{"text": "Call the landlord about rent", "category": "personal"}]'
        )

        todos = infer_todos_from_notes("/vault", "http://localhost:11434", "llama3.2")

        self.assertEqual(len(todos), 1)
        self.assertEqual(todos[0]["text"], "Call the landlord about rent")
        self.assertEqual(todos[0]["category"], "personal")
        self.assertEqual(todos[0]["source"], "vault_inferred")
        self.assertEqual(todos[0]["origin"], "daily/2026-06-22.md")

    @patch("agent.infer_todos.generate")
    @patch("agent.infer_todos.recent_notes_with_content")
    def test_malformed_json_response_returns_empty_list(self, mock_notes, mock_generate):
        mock_notes.return_value = [("note.md", "some prose")]
        mock_generate.return_value = "not valid json"

        todos = infer_todos_from_notes("/vault", "http://localhost:11434", "llama3.2")

        self.assertEqual(todos, [])

    @patch("agent.infer_todos.generate")
    @patch("agent.infer_todos.recent_notes_with_content")
    def test_no_notes_skips_model_call_entirely(self, mock_notes, mock_generate):
        mock_notes.return_value = []

        todos = infer_todos_from_notes("/vault", "http://localhost:11434", "llama3.2")

        self.assertEqual(todos, [])
        mock_generate.assert_not_called()

    @patch("agent.infer_todos.generate")
    @patch("agent.infer_todos.recent_notes_with_content")
    def test_empty_array_response_returns_empty_list(self, mock_notes, mock_generate):
        mock_notes.return_value = [("note.md", "nothing actionable here")]
        mock_generate.return_value = "[]"

        todos = infer_todos_from_notes("/vault", "http://localhost:11434", "llama3.2")

        self.assertEqual(todos, [])


if __name__ == "__main__":
    unittest.main()
