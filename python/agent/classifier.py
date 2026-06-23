"""Lightweight, zero-dependency Naive Bayes classifier trained on the user's
own feedback corrections recorded in `Feedback Log.md`.

The classifier learns two independent tasks:
  - category:  personal | work | uni | other
  - urgency:   today | this_week | overarching

It is intentionally simple (word-tokenised, Laplace-smoothed multinomial NB)
so it runs instantly with no third-party packages, trains from a handful of
corrections, and degrades gracefully.
"""
from __future__ import annotations

import csv
import io
import math
import os
import re
from collections import defaultdict
from typing import Dict, List, Optional, Tuple

FEEDBACK_FILE = "Feedback Log.md"

VALID_CATEGORIES = {"personal", "work", "uni", "project", "other"}
VALID_URGENCIES  = {"today", "this_week", "overarching"}

MIN_EXAMPLES = 3
LOG_MARGIN = 0.5

_STOP = {
    "a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for",
    "of", "with", "from", "by", "is", "it", "its", "this", "that", "be",
    "was", "are", "were", "as", "s", "re",
}

def _tokenise(text: str) -> List[str]:
    raw = re.sub(r"[^\w\s]", " ", text.lower())
    return [w for w in raw.split() if len(w) > 2 and w not in _STOP]

def _parse_feedback_log(inbox_dir: str, vault_root: Optional[str] = None) -> List[dict]:
    path = os.path.join(inbox_dir, FEEDBACK_FILE)
    if not os.path.exists(path) and vault_root:
        path = os.path.join(vault_root, FEEDBACK_FILE)
    if not os.path.exists(path):
        return []

    rows = []
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
    except OSError:
        return []

    table_lines = [ln.strip() for ln in content.splitlines() if ln.strip().startswith("|")]
    if len(table_lines) < 3:
        return []

    for line in table_lines[2:]:
        stripped = line.strip("|")
        reader = csv.reader(io.StringIO(stripped), delimiter="|")
        try:
            cells = [c.strip() for c in next(reader)]
        except StopIteration:
            continue

        if len(cells) < 7:
            continue

        rows.append({
            "text":               cells[1],
            "suggested_category": cells[2] or None,
            "chosen_category":    cells[3] or None,
            "suggested_urgency":  cells[4] or None,
            "chosen_urgency":     cells[5] or None,
        })
    return rows

class _NaiveBayes:
    def __init__(self) -> None:
        self.word_counts: Dict[str, Dict[str, int]] = defaultdict(lambda: defaultdict(int))
        self.class_totals: Dict[str, int] = defaultdict(int)
        self.class_docs:   Dict[str, int] = defaultdict(int)
        self.vocab: set = set()
        self.n_docs = 0

    def fit(self, texts: List[str], labels: List[str]) -> None:
        for text, label in zip(texts, labels):
            tokens = _tokenise(text)
            self.class_docs[label] += 1
            self.n_docs += 1
            for tok in tokens:
                self.word_counts[label][tok] += 1
                self.class_totals[label] += 1
                self.vocab.add(tok)

    def predict(self, text: str) -> Optional[str]:
        if self.n_docs < MIN_EXAMPLES:
            return None
        tokens = _tokenise(text)
        vocab_size = len(self.vocab) or 1
        scores: Dict[str, float] = {}

        for label, doc_count in self.class_docs.items():
            log_prior = math.log(doc_count / self.n_docs)
            log_likelihood = 0.0
            total = self.class_totals[label]
            for tok in tokens:
                count = self.word_counts[label].get(tok, 0)
                log_likelihood += math.log((count + 1) / (total + vocab_size))
            scores[label] = log_prior + log_likelihood

        best  = max(scores, key=scores.__getitem__)
        ranks = sorted(scores.values(), reverse=True)
        margin = ranks[0] - ranks[1] if len(ranks) > 1 else float("inf")
        return best if margin >= LOG_MARGIN else None

class FeedbackClassifier:
    def __init__(self, cat_clf: _NaiveBayes, urg_clf: _NaiveBayes) -> None:
        self._cat = cat_clf
        self._urg = urg_clf

    @classmethod
    def from_feedback_log(cls, inbox_dir: str, vault_root: Optional[str] = None) -> "FeedbackClassifier":
        cat_clf = _NaiveBayes()
        urg_clf = _NaiveBayes()

        if not inbox_dir:
            return cls(cat_clf, urg_clf)

        rows = _parse_feedback_log(inbox_dir, vault_root)
        cat_texts, cat_labels = [], []
        urg_texts, urg_labels = [], []

        for row in rows:
            text = row["text"]
            if not text:
                continue
            cat = row["chosen_category"]
            urg = row["chosen_urgency"]
            
            # The user requested 'uni' along with personal/work
            if cat in VALID_CATEGORIES:
                cat_texts.append(text)
                cat_labels.append(cat)
            if urg in VALID_URGENCIES:
                urg_texts.append(text)
                urg_labels.append(urg)

        if cat_texts:
            cat_clf.fit(cat_texts, cat_labels)
        if urg_texts:
            urg_clf.fit(urg_texts, urg_labels)

        return cls(cat_clf, urg_clf)

    def classify(self, text: str) -> Tuple[Optional[str], Optional[str]]:
        return self._cat.predict(text), self._urg.predict(text)
