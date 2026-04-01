from __future__ import annotations

from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Vertical
from textual.screen import Screen
from textual.widgets import Button, Footer, Static


class MainMenuScreen(Screen[None]):
    """Primary menu — Escape quits the app."""

    BINDINGS = [
        Binding("escape", "quit_app", "Quit", show=True),
    ]

    def compose(self) -> ComposeResult:
        yield Vertical(
            Static("LabSmith", classes="brand-title"),
            Static("Workshop builder — PDFs to searchable chunks", classes="brand-tagline"),
            Vertical(
                Button("Convert PDFs", id="menu_convert", variant="primary"),
                Button("Chunk to SQLite", id="menu_chunk", variant="primary"),
                Button("Query Database", id="menu_query", variant="primary"),
                Button("Run Tests", id="menu_test", variant="primary"),
                Button("Setup Info", id="menu_info", variant="default"),
                Button("Quit", id="menu_quit", variant="error"),
                classes="menu-buttons",
            ),
            classes="main-panel",
        )
        yield Footer()

    def action_quit_app(self) -> None:
        self.app.exit()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        from tui.screens.chunk import ChunkScreen
        from tui.screens.convert import ConvertScreen
        from tui.screens.info import InfoScreen
        from tui.screens.query_screen import QueryScreen
        from tui.screens.test_screen import TestScreen

        bid = event.button.id or ""
        if bid == "menu_quit":
            self.app.exit()
        elif bid == "menu_convert":
            self.app.push_screen(ConvertScreen())
        elif bid == "menu_chunk":
            self.app.push_screen(ChunkScreen())
        elif bid == "menu_query":
            self.app.push_screen(QueryScreen())
        elif bid == "menu_test":
            self.app.push_screen(TestScreen())
        elif bid == "menu_info":
            self.app.push_screen(InfoScreen())
