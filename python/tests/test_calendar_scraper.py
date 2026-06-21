import os
import sys
import unittest
from datetime import datetime

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from calendar_scraper import build_day_layout, compute_gaps, suggest_for_gap  # noqa: E402


def _dt(hour, minute=0):
    return datetime(2026, 6, 21, hour, minute)


class ComputeGapsTests(unittest.TestCase):
    def test_finds_gap_between_events(self):
        events = [
            {"start": _dt(9).isoformat(), "end": _dt(10).isoformat(), "all_day": False},
            {"start": _dt(12).isoformat(), "end": _dt(13).isoformat(), "all_day": False},
        ]
        gaps = compute_gaps(events, _dt(8), _dt(18), min_gap_minutes=30)
        self.assertIn((_dt(10), _dt(12)), gaps)

    def test_ignores_all_day_events(self):
        events = [{"start": "2026-06-21", "end": "2026-06-22", "all_day": True}]
        gaps = compute_gaps(events, _dt(8), _dt(18), min_gap_minutes=30)
        self.assertEqual(gaps, [(_dt(8), _dt(18))])

    def test_skips_gaps_shorter_than_minimum(self):
        events = [
            {"start": _dt(9).isoformat(), "end": _dt(10).isoformat(), "all_day": False},
            {"start": _dt(10, 10).isoformat(), "end": _dt(11).isoformat(), "all_day": False},
        ]
        gaps = compute_gaps(events, _dt(9), _dt(11), min_gap_minutes=30)
        self.assertEqual(gaps, [])


class SuggestForGapTests(unittest.TestCase):
    def test_evening_gap_suggests_wind_down(self):
        suggestion = suggest_for_gap(_dt(20), _dt(21), has_exercise_today=False)
        self.assertEqual(suggestion["type"], "wind_down")

    def test_daytime_gap_with_no_exercise_suggests_exercise(self):
        suggestion = suggest_for_gap(_dt(14), _dt(14, 45), has_exercise_today=False)
        self.assertEqual(suggestion["type"], "exercise")

    def test_daytime_gap_with_exercise_already_done_suggests_study(self):
        suggestion = suggest_for_gap(_dt(14), _dt(15), has_exercise_today=True)
        self.assertEqual(suggestion["type"], "study")


class BuildDayLayoutTests(unittest.TestCase):
    def test_only_suggests_exercise_once(self):
        events = [
            {"start": _dt(10).isoformat(), "end": _dt(10, 15).isoformat(), "all_day": False, "summary": "Sync"},
            {"start": _dt(11).isoformat(), "end": _dt(11, 15).isoformat(), "all_day": False, "summary": "Review"},
        ]
        suggestions = build_day_layout(events, _dt(9), _dt(18), min_gap_minutes=30)
        exercise_suggestions = [s for s in suggestions if s["type"] == "exercise"]
        self.assertEqual(len(exercise_suggestions), 1)

    def test_existing_workout_event_skips_exercise_suggestion(self):
        events = [{"start": _dt(8).isoformat(), "end": _dt(8, 30).isoformat(), "all_day": False, "summary": "Gym"}]
        suggestions = build_day_layout(events, _dt(9), _dt(18), min_gap_minutes=30)
        self.assertFalse(any(s["type"] == "exercise" for s in suggestions))


if __name__ == "__main__":
    unittest.main()
