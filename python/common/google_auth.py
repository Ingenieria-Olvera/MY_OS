"""Shared Google OAuth helper, used by both the Gmail and Calendar scrapers.

Handles the installed-app flow on first run and silently refreshes the
cached token on subsequent runs (e.g. from cron).

Gmail and Calendar share one `credentials.json` OAuth client and one cached
token: GMAIL_SCOPES + CALENDAR_SCOPES are requested together up front, so
the interactive consent screen only has to be granted once, covering both
scrapers from then on.
"""
import os
from typing import List

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow

GMAIL_SCOPES = ["https://www.googleapis.com/auth/gmail.readonly"]
CALENDAR_SCOPES = ["https://www.googleapis.com/auth/calendar"]
GOOGLE_SCOPES = GMAIL_SCOPES + CALENDAR_SCOPES


def load_credentials(client_secret_file: str, token_file: str, scopes: List[str]) -> Credentials:
    creds = None
    if os.path.exists(token_file):
        try:
            creds = Credentials.from_authorized_user_file(token_file, scopes)
        except Exception:
            # Stale or corrupted token file; force re-authentication
            creds = None

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except Exception:
                # Refresh failed (e.g. token revoked); force re-authentication
                creds = None

        # Re-check in case refresh failed
        if not creds or not creds.valid:
            if not os.path.exists(client_secret_file):
                raise FileNotFoundError(
                    f"\n[GOOGLE AUTH ERROR] Client secrets file not found at: {os.path.abspath(client_secret_file)}\n"
                    "Please download the OAuth 2.0 Client ID JSON (Desktop App type) from your Google Cloud Console, "
                    "save it as 'credentials.json' in the 'python/' folder, or configure GOOGLE_CREDENTIALS_FILE "
                    "in your 'python/.env' file. See python/README.md for details."
                )
            is_test_mode = os.environ.get("TEST_MODE", "False").lower() in ("true", "1", "yes", "t")
            is_production_mode = os.environ.get("PRODUCTION_MODE", "False").lower() in ("true", "1", "yes", "t")

            if not is_production_mode or is_test_mode:
                link_account = input(f"\n[TEST_MODE] Google credentials missing or expired for {client_secret_file}. Link account now? (y/n): ")
                if link_account.lower() == 'y':
                    print("\nStarting Google OAuth flow. Please follow the authorization link provided below or in your browser...")
                    flow = InstalledAppFlow.from_client_secrets_file(client_secret_file, scopes)
                    creds = flow.run_local_server(port=0)
                else:
                    raise Exception("Authentication skipped by user. Cannot proceed without linking a Google account.")
            else:
                raise Exception(
                    "[PRODUCTION_MODE] Valid Google credentials not found or expired. "
                    "Interactive authentication is disabled in production mode. "
                    "Please run the script with TEST_MODE=True to authorize your account."
                )
            
        with open(token_file, "w", encoding="utf-8") as f:
            f.write(creds.to_json())

    return creds
