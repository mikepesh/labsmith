from __future__ import annotations

import re
from pathlib import Path

from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.screen import Screen
from textual.widgets import Button, Footer, Input, RichLog, Select, SelectionList, Static

from tui import dbutil
from tui.paths import CHUNKER, OUTPUT_DIR, REPO_ROOT, VENV_PYTHON
from tui.runner import stream_command


DOC_TYPES = ("admin", "cli", "datasheet", "release-notes")
_WS_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")


class ChunkScreen(Screen[None]):
    BINDINGS = [
        Binding("escape", "go_back", "Back", show=True),
    ]

    def compose(self) -> ComposeResult:
        yield Static("LabSmith — Chunk to SQLite", classes="screen-title")
        yield Static(
            "Pick one .md from marker/output/, workshop name, doc-type — runs chunker.py",
            classes="screen-subtitle",
        )
        yield VerticalScroll(SelectionList[str](id="md_list"), classes="selection-scroll")
        yield Vertical(
            Input(placeholder="Workshop (lowercase-hyphens, e.g. my-workshop)", id="workshop_input"),
            Select(
                [(d, d) for d in DOC_TYPES],
                value=DOC_TYPES[0],
                allow_blank=False,
                id="doctype_sel",
            ),
            classes="chunk-form",
        )
        yield Horizontal(
            Button("Run chunker", id="btn_run", variant="primary"),
            Button("Refresh list", id="btn_refresh", variant="default"),
            classes="action-row",
        )
        yield Static("Output", classes="log-label")
        yield RichLog(id="chunk_log", highlight=True, wrap=True, max_lines=3000)
        yield Footer()

    def on_mount(self) -> None:
        self._refresh_mds()
        default = dbutil.default_workshop(self.app.db_path)
        inp = self.query_one("#workshop_input", Input)
        if default:
            inp.value = default

    def _refresh_mds(self) -> None:
        lst = self.query_one("#md_list", SelectionList)
        lst.clear_options()
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        mds = sorted(OUTPUT_DIR.glob("*.md"))
        for p in mds:
            lst.add_option((p.name, str(p.resolve())))
        log = self.query_one("#chunk_log", RichLog)
        if not mds:
            log.write("No .md files in marker/output/ — convert PDFs first.")

    def action_go_back(self) -> None:
        self.app.pop_screen()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "btn_refresh":
            self._refresh_mds()
            return
        if event.button.id != "btn_run":
            return

        log = self.query_one("#chunk_log", RichLog)
        lst = self.query_one("#md_list", SelectionList)
        sel = list(lst.selected)
        if len(sel) != 1:
            log.write("Select exactly one markdown file.")
            return

        md_path = Path(sel[0])
        if not md_path.is_file():
            log.write(f"File not found: {md_path}")
            return

        ws_raw = self.query_one("#workshop_input", Input).value.strip().lower()
        if not ws_raw:
            log.write("Enter a workshop name.")
            return
        if not _WS_RE.match(ws_raw):
            log.write("Workshop: lowercase letters, numbers, hyphens, underscores; start with letter or digit.")
            return

        dtype = str(self.query_one("#doctype_sel", Select).value)
        if dtype not in DOC_TYPES:
            dtype = DOC_TYPES[0]

        log.clear()
        py = str(VENV_PYTHON) if VENV_PYTHON.is_file() else "python3"
        cmd = [
            py,
            str(CHUNKER),
            str(md_path.resolve()),
            "--workshop",
            ws_raw,
            "--doc-type",
            dtype,
            "--db",
            str(self.app.db_path.resolve()),
        ]

        if getattr(self.app, "_chunk_busy", False):
            log.write("Already running.")
            return
        self.app._chunk_busy = True

        def log_line(s: str) -> None:
            log.write(s)

        def on_done(code: int) -> None:
            self.app._chunk_busy = False
            log_line("")
            log_line(f"— chunker exited {code} —")

        stream_command(self.app, cmd, REPO_ROOT, log_line, on_done)
