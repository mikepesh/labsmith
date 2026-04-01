"""LabSmith Textual application entry."""

from __future__ import annotations

import argparse
from pathlib import Path

from textual.app import App

from tui.paths import REPO_ROOT
from tui.screens.main_menu import MainMenuScreen


class LabSmithApp(App[None]):
    """Terminal UI for Marker, chunker, query, and tests."""

    TITLE = "LabSmith"
    CSS_PATH = Path(__file__).parent / "styles" / "app.tcss"

    def __init__(self, db_path: Path) -> None:
        super().__init__()
        self.db_path = db_path

    def on_mount(self) -> None:
        self.push_screen(MainMenuScreen())


def main() -> None:
    parser = argparse.ArgumentParser(description="LabSmith — workshop builder TUI")
    parser.add_argument(
        "--db",
        default="labsmith.db",
        help="SQLite database path (default: labsmith.db in repo root)",
    )
    args = parser.parse_args()
    db = Path(args.db)
    if not db.is_absolute():
        db = (REPO_ROOT / db).resolve()
    app = LabSmithApp(db_path=db)
    app.run()


if __name__ == "__main__":
    main()
