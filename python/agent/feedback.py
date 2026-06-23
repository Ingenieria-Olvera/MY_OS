import os
from datetime import datetime
from typing import Optional

def record_feedback(
    inbox_dir: str,
    text: str,
    suggested_category: Optional[str],
    chosen_category: Optional[str],
    suggested_urgency: Optional[str],
    chosen_urgency: Optional[str],
    reason: Optional[str] = None
) -> None:
    """Append a feedback correction to Feedback Log.md in the vault inbox."""
    path = os.path.join(inbox_dir, "Feedback Log.md")
    
    # Create file with header if it doesn't exist
    if not os.path.exists(path):
        with open(path, "w", encoding="utf-8") as f:
            f.write("# Feedback Log\n\n")
            f.write("| Timestamp | Text | Suggested Category | Chosen Category | Suggested Urgency | Chosen Urgency | Reason |\n")
            f.write("|---|---|---|---|---|---|---|\n")

    # Format row
    now = datetime.now().isoformat(timespec='seconds')
    
    def _clean(s: Optional[str]) -> str:
        if not s:
            return ""
        # Remove pipes and newlines so it doesn't break the markdown table
        return str(s).replace("|", "-").replace("\n", " ").strip()

    row = (
        f"| {_clean(now)} | {_clean(text)} "
        f"| {_clean(suggested_category)} | {_clean(chosen_category)} "
        f"| {_clean(suggested_urgency)} | {_clean(chosen_urgency)} "
        f"| {_clean(reason)} |\n"
    )

    with open(path, "a", encoding="utf-8") as f:
        f.write(row)
