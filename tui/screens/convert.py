from __future__ import annotations

from pathlib import Path

from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, VerticalScroll
from textual.screen import Screen
from textual.widgets import Button, Footer, RichLog, SelectionList, Static

from tui.paths import PROCESS_SCRIPT, REPO_ROOT, TOPROC_DIR
from tui.runner import stream_command


class ConvertScreen(Screen[None]):
    BINDINGS = [
        Binding("escape", "go_back", "Back", show=True),
    ]

    def compose(self) -> ComposeResult:
        yield Static("LabSmith — Convert PDFs", classes="screen-title")
        yield Static(
            "Runs marker/process-now.sh on PDFs in marker/to-process/",
            classes="screen-subtitle",
        )
        yield VerticalScroll(SelectionList[str](id="pdf_list"), classes="selection-scroll")
        yield Horizontal(
            Button("Convert selected", id="btn_sel", variant="primary"),
            Button("Convert all", id="btn_all", variant="success"),
            classes="action-row",
        )
        yield Static("Log", classes="log-label")
        yield RichLog(id="convert_log", highlight=True, wrap=True, max_lines=5000)
        yield Footer()

    def on_mount(self) -> None:
        self._refresh_pdfs()

    def _refresh_pdfs(self) -> None:
        lst = self.query_one("#pdf_list", SelectionList)
        lst.clear_options()
        TOPROC_DIR.mkdir(parents=True, exist_ok=True)
        pdfs = sorted(TOPROC_DIR.glob("*.pdf")) + sorted(TOPROC_DIR.glob("*.PDF"))
        for p in pdfs:
            lst.add_option((p.name, p.name))
        log = self.query_one("#convert_log", RichLog)
        if not pdfs:
            log.write("No PDF files in marker/to-process/")

    def action_go_back(self) -> None:
        self.app.pop_screen()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        log = self.query_one("#convert_log", RichLog)
        lst = self.query_one("#pdf_list", SelectionList)

        if event.button.id == "btn_all":
            self._run_convert_all(log)
        elif event.button.id == "btn_sel":
            sel = list(lst.selected)
            if not sel:
                log.write("Select at least one PDF (Space to toggle), or use Convert all.")
                return
            self._run_convert_selected(log, sel)

    def _busy(self) -> bool:
        return getattr(self.app, "_convert_busy", False)

    def _set_busy(self, v: bool) -> None:
        self.app._convert_busy = v

    def _run_convert_all(self, log: RichLog) -> None:
        if self._busy():
            log.write("Already running.")
            return
        log.clear()
        self._set_busy(True)

        def log_line(s: str) -> None:
            log.write(s)

        def on_done(code: int) -> None:
            self._set_busy(False)
            if code == 0:
                log_line("")
                log_line("— Done (success) —")
            else:
                log_line("")
                log_line(f"— Finished with exit code {code} —")
            self._refresh_pdfs()

        cmd = ["bash", str(PROCESS_SCRIPT)]
        stream_command(self.app, cmd, REPO_ROOT, log_line, on_done)

    def _run_convert_selected(self, log: RichLog, names: list[str]) -> None:
        if self._busy():
            log.write("Already running.")
            return
        log.clear()
        self._set_busy(True)

        def log_line(s: str) -> None:
            log.write(s)

        def run_next(i: int) -> None:
            if i >= len(names):
                self._set_busy(False)
                log_line("")
                log_line("— All selected conversions finished —")
                self._refresh_pdfs()
                return

            name = names[i]

            def step_done(code: int) -> None:
                log_line(f"— {name} → exit {code} —")
                run_next(i + 1)

            cmd = ["bash", str(PROCESS_SCRIPT), name]
            stream_command(self.app, cmd, REPO_ROOT, log_line, step_done)

        run_next(0)
