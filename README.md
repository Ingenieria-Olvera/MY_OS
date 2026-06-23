# My OS (Agentic Secretary)

My OS is a personalized secretary application consisting of a Flutter frontend and a local Python backend that natively integrates with your Obsidian Vault, Google Calendar, Gmail, and Slack.

## Architecture

The project is split into two primary pieces:
1. **Flutter App (`lib/`)**: A mobile interface designed with premium Material UI cards, smooth swipe interactions, and tabbed dashboards to consume your daily digests.
2. **Python Backend (`python/`)**: A suite of scrapers (`gmail_scraper.py`, `slack_scraper.py`, `calendar_scraper.py`) and a local HTTP server (`server.py`) that acts as the bridge between your Flutter app and your data sources.

### Data Flow & Storage
All scraped data and model inferences are stored natively in your Obsidian vault.
- **`_inbox/`**: The backend automatically outputs `*_digest.json` files here, which the Flutter app fetches directly over your local network. `Feedback Log.md` and `Chat Log.md` also live here.
- **`Todos/`**: Checkboxes (`- [ ]`) written anywhere in your vault are tracked. Tapping a task in the Flutter app checks the box and moves it to `Todos/Finished.md`.

## Features

- **Unified Inbox**: Aggregates unread Slack mentions and Gmail threads into a clean, tabbed Material interface.
- **Timeline Scheduling**: Merges your Google Calendar events with AI-inferred free-time suggestions (e.g., Exercise, Study, Wind Down). You can Add or Delete events directly from the app.
- **Intelligent Todos**: Automatically tags your tasks (`personal`, `work`, `uni`, `project`) using a local Naive Bayes classifier.
- **Interactive Training**: Train the AI classifier via Tinder-style Swipe Cards, or an interactive List Trainer for manual tag and urgency corrections.
- **Local AI Chat**: Communicate directly with a local `Ollama` model, allowing natural language queries against your daily context.

## Setup Instructions

### Backend
1. Navigate to the `python/` directory and configure your `.env` file (see `python/.env.example`).
2. Run `python -m agent.server` to start the local bridge server (default: port 8000).
3. Set up a cron job or scheduled task to run the scrapers periodically (e.g., `todos_aggregator.py`, `gmail_scraper.py`).

### Frontend
1. Ensure the Flutter app is pointed at the correct `agent_base_url` (configured via the app's Settings/Chat screen).
2. Run `flutter build apk` or `flutter run` to deploy to your device.

