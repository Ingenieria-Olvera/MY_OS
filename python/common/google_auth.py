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
CALENDAR_SCOPES = ["https://www.googleapis.com/auth/calendar.readonly"]
GOOGLE_SCOPES = GMAIL_SCOPES + CALENDAR_SCOPES


def load_credentials(client_secret_file: str, token_file: str, scopes: List[str]) -> Credentials:
    creds = None
    if os.path.exists(token_file):
        creds = Credentials.from_authorized_user_file(token_file, scopes)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(client_secret_file, scopes)
            creds = flow.run_local_server(port=0)
        with open(token_file, "w", encoding="utf-8") as f:
            f.write(creds.to_json())

    return creds
