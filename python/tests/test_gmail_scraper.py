import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from gmail_scraper import fetch_important_emails  # noqa: E402


class _Execute:
    def __init__(self, result):
        self._result = result

    def execute(self):
        return self._result


class FakeService:
    """Stands in for the Gmail API client (service.users().messages()...).

    `list_results` maps a query string to the message ids it returns;
    `messages` maps a message id to the metadata `.get()` would return.
    """

    def __init__(self, list_results: dict, messages: dict):
        self.list_results = list_results
        self.message_metadata = messages
        self.get_calls = []

    def users(self):
        return self

    def messages(self):
        return self

    def list(self, userId, q, maxResults):
        ids = self.list_results.get(q, [])
        return _Execute({"messages": [{"id": i} for i in ids]})

    def get(self, userId, id, format, metadataHeaders):
        self.get_calls.append(id)
        return _Execute(self.message_metadata[id])


def _message(msg_id, sender, subject, date="Mon, 1 Jun 2026 10:00:00 +0000"):
    return {
        "id": msg_id,
        "snippet": "snippet",
        "labelIds": ["INBOX"],
        "payload": {
            "headers": [
                {"name": "From", "value": sender},
                {"name": "Subject", "value": subject},
                {"name": "Date", "value": date},
            ]
        },
    }


class FetchImportantEmailsTests(unittest.TestCase):
    def test_single_query_tags_matched_label(self):
        service = FakeService(
            list_results={"is:important": ["m1"]},
            messages={"m1": _message("m1", "Alice <a@x.com>", "Hello")},
        )

        emails = fetch_important_emails(service, [("important", "is:important")], max_results=25)

        self.assertEqual(len(emails), 1)
        self.assertEqual(emails[0]["id"], "m1")
        self.assertEqual(emails[0]["matched"], ["important"])

    def test_message_matching_two_queries_is_deduplicated_and_tagged_with_both(self):
        service = FakeService(
            list_results={
                "is:important": ["m1"],
                "subject:bank": ["m1"],
            },
            messages={"m1": _message("m1", "Bank <b@bank.com>", "Statement ready")},
        )

        emails = fetch_important_emails(
            service,
            [("important", "is:important"), ("keyword", "subject:bank")],
            max_results=25,
        )

        self.assertEqual(len(emails), 1)
        self.assertEqual(service.get_calls, ["m1"])  # fetched metadata only once
        self.assertEqual(emails[0]["matched"], ["important", "keyword"])

    def test_distinct_messages_from_each_query_are_both_kept(self):
        service = FakeService(
            list_results={
                "is:important": ["m1"],
                "subject:bank": ["m2"],
            },
            messages={
                "m1": _message("m1", "Alice <a@x.com>", "Hello"),
                "m2": _message("m2", "Bank <b@bank.com>", "Statement ready"),
            },
        )

        emails = fetch_important_emails(
            service,
            [("important", "is:important"), ("keyword", "subject:bank")],
            max_results=25,
        )

        self.assertEqual({e["id"] for e in emails}, {"m1", "m2"})

    def test_empty_query_is_skipped(self):
        service = FakeService(list_results={}, messages={})

        emails = fetch_important_emails(
            service,
            [("important", "is:important"), ("keyword", "")],
            max_results=25,
        )

        self.assertEqual(emails, [])
        self.assertEqual(service.get_calls, [])


if __name__ == "__main__":
    unittest.main()
