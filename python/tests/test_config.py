import os
import sys
import unittest
from dataclasses import replace

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

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


class GoogleAccountTriplesTests(unittest.TestCase):
    def test_single_default_account(self):
        config = _config()
        self.assertEqual(
            config.google_account_triples(),
            [("default", "credentials.json", "google_token.json")],
        )

    def test_multiple_accounts_with_own_files(self):
        config = _config(
            google_accounts=["personal", "uni", "work"],
            google_credentials_files=["personal_creds.json", "uni_creds.json", "work_creds.json"],
            google_token_files=["personal_token.json", "uni_token.json", "work_token.json"],
        )
        self.assertEqual(
            config.google_account_triples(),
            [
                ("personal", "personal_creds.json", "personal_token.json"),
                ("uni", "uni_creds.json", "uni_token.json"),
                ("work", "work_creds.json", "work_token.json"),
            ],
        )

    def test_shared_credentials_file_padded_across_accounts(self):
        config = _config(
            google_accounts=["personal", "uni", "work"],
            google_credentials_files=["shared_creds.json"],
            google_token_files=["personal_token.json", "uni_token.json", "work_token.json"],
        )
        triples = config.google_account_triples()
        self.assertEqual([t[1] for t in triples], ["shared_creds.json"] * 3)
        self.assertEqual([t[2] for t in triples], ["personal_token.json", "uni_token.json", "work_token.json"])


if __name__ == "__main__":
    unittest.main()
