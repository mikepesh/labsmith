from __future__ import annotations

from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import VerticalScroll
from textual.screen import Screen
from textual.widgets import Button, Footer, Static

from tui import dbutil
from tui.paths import MARKER_DIR, REPO_ROOT, VENV_PYTHON


class InfoScreen(Screen[None]):
    BINDINGS = [
        Binding("escape", "go_back", "Back", show=True),
    ]

    def compose(self) -> ComposeResult:
        yield Static("LabSmith — Setup Info", classes="screen-title")
        yield Static("Environment and database snapshot", classes="screen-subtitle")
        yield Button("Refresh", id="btn_refresh", variant="default")
        yield VerticalScroll(Static(id="info_body"), classes="info-scroll")
        yield Footer()

    def on_mount(self) -> None:
        self._render()

    def action_go_back(self) -> None:
        self.app.pop_screen()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "btn_refresh":
            self._render()

    def _render(self) -> None:
        body = self.query_one("#info_body", Static)
        db = self.app.db_path
        lines: list[str] = []
        lines.append(f"Repo root: {REPO_ROOT}")
        lines.append("")
        if VENV_PYTHON.is_file():
            lines.append(f"Marker venv: OK ({VENV_PYTHON.parent.parent})")
        else:
            lines.append("Marker venv: missing (run labsmith.sh to create)")
        lines.append(f"Database path: {db.resolve()}")
        sz = dbutil.db_file_size(db)
        if sz is None:
            lines.append("Database file: not found yet")
        else:
            lines.append(f"Database size: {sz / 1024:.1f} KB")
        n_chunks, n_lines = dbutil.chunk_stats(db)
        lines.append(f"Total chunks: {n_chunks}")
        lines.append(f"Sum of chunk line_count: {n_lines}")
        ws = dbutil.list_workshops(db)
        if ws:
            lines.append(f"Workshops in DB: {', '.join(ws)}")
        else:
            lines.append("Workshops in DB: (none)")
        lines.append("")
        lines.append(f"marker/to-process: {MARKER_DIR / 'to-process'}")
        lines.append(f"marker/output: {MARKER_DIR / 'output'}")
        body.update("\n".join(lines))
