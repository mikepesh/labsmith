from __future__ import annotations

from textual.app import ComposeResult
from textual.binding import Binding
from textual.screen import Screen
from textual.widgets import Button, Footer, RichLog, Static

from tui.paths import REPO_ROOT, TEST_PIPELINE
from tui.runner import stream_command_ansi


class TestScreen(Screen[None]):
    BINDINGS = [
        Binding("escape", "go_back", "Back", show=True),
    ]

    def compose(self) -> ComposeResult:
        yield Static("LabSmith — Run Tests", classes="screen-title")
        if TEST_PIPELINE.is_file():
            yield Static(
                "Runs test-pipeline.sh from the repo root (streams PASS/FAIL/SKIP).",
                classes="screen-subtitle",
            )
        else:
            yield Static(
                "test-pipeline.sh is not in this clone (often maintainer-only). "
                "Run tests from a checkout that includes it.",
                classes="screen-subtitle warn-text",
            )
        yield Button("Run test-pipeline.sh", id="btn_run", variant="primary")
        yield Static("Output", classes="log-label")
        yield RichLog(id="test_log", highlight=True, wrap=True, max_lines=8000)
        yield Footer()

    def action_go_back(self) -> None:
        self.app.pop_screen()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id != "btn_run":
            return
        log = self.query_one("#test_log", RichLog)
        if not TEST_PIPELINE.is_file():
            log.write("test-pipeline.sh not found.")
            return
        if getattr(self.app, "_test_busy", False):
            log.write("Already running.")
            return
        self.app._test_busy = True
        log.clear()

        def on_done(code: int) -> None:
            self.app._test_busy = False
            log.write("")
            log.write(f"— exit {code} —")

        cmd = ["bash", str(TEST_PIPELINE)]
        stream_command_ansi(self.app, cmd, REPO_ROOT, log, on_done)
