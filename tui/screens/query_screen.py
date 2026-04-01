from __future__ import annotations

from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Vertical
from textual.screen import Screen
from textual.widgets import Button, Footer, Input, RichLog, Select, Static, TabbedContent, TabPane

from tui import dbutil
from tui.paths import QUERY, REPO_ROOT, VENV_PYTHON
from tui.runner import stream_command


class QueryScreen(Screen[None]):
    BINDINGS = [
        Binding("escape", "go_back", "Back", show=True),
    ]

    def compose(self) -> ComposeResult:
        yield Static("LabSmith — Query Database", classes="screen-title")
        yield Static("Runs query.py (stats, list, search, get)", classes="screen-subtitle")

        with TabbedContent(id="query_tabs"):
            with TabPane("Stats", id="tab_stats"):
                yield Vertical(
                    self._workshop_select("stats_ws"),
                    Button("Run stats", id="btn_stats", variant="primary"),
                    classes="tab-inner",
                )
            with TabPane("List", id="tab_list"):
                yield Vertical(
                    self._workshop_select("list_ws"),
                    Button("Run list", id="btn_list", variant="primary"),
                    classes="tab-inner",
                )
            with TabPane("Search", id="tab_search"):
                yield Vertical(
                    Input(placeholder="Search keyword", id="search_kw"),
                    self._workshop_select("search_ws"),
                    Button("Run search", id="btn_search", variant="primary"),
                    classes="tab-inner",
                )
            with TabPane("Get", id="tab_get"):
                yield Vertical(
                    Input(placeholder="Chunk id(s), space-separated", id="get_ids"),
                    Button("Run get", id="btn_get", variant="primary"),
                    classes="tab-inner",
                )

        yield Static("Output", classes="log-label")
        yield RichLog(id="query_log", highlight=True, wrap=True, max_lines=4000)
        yield Footer()

    def _workshop_select(self, wid: str) -> Select[str]:
        opts: list[tuple[str, str]] = [("(all workshops)", "__all__")]
        return Select(opts, value="__all__", allow_blank=False, id=wid, disabled=True)

    def on_mount(self) -> None:
        self._reload_workshop_selects()

    def _reload_workshop_selects(self) -> None:
        db = self.app.db_path
        workshops = dbutil.list_workshops(db)
        for wid in ("stats_ws", "list_ws", "search_ws"):
            sel = self.query_one(f"#{wid}", Select)
            opts: list[tuple[str, str]] = [("(all workshops)", "__all__")]
            for w in workshops:
                opts.append((w, w))
            sel.set_options(opts)
            sel.disabled = False
            if workshops:
                sel.value = workshops[0]
            else:
                sel.value = "__all__"

    def action_go_back(self) -> None:
        self.app.pop_screen()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        bid = event.button.id or ""
        if bid == "btn_stats":
            self._run_query_stats()
        elif bid == "btn_list":
            self._run_query_list()
        elif bid == "btn_search":
            self._run_query_search()
        elif bid == "btn_get":
            self._run_query_get()

    def _py(self) -> str:
        return str(VENV_PYTHON) if VENV_PYTHON.is_file() else "python3"

    def _db_arg(self) -> list[str]:
        return ["--db", str(self.app.db_path.resolve())]

    def _log(self) -> RichLog:
        return self.query_one("#query_log", RichLog)

    def _run_cmd(self, cmd: list[str]) -> None:
        log = self._log()
        if getattr(self.app, "_query_busy", False):
            log.write("Already running.")
            return
        self.app._query_busy = True
        log.clear()

        def log_line(s: str) -> None:
            log.write(s)

        def on_done(code: int) -> None:
            self.app._query_busy = False
            log_line("")
            log_line(f"— exit {code} —")

        stream_command(self.app, cmd, REPO_ROOT, log_line, on_done)

    def _run_query_stats(self) -> None:
        ws = self.query_one("#stats_ws", Select).value
        cmd = [self._py(), str(QUERY), *self._db_arg(), "stats"]
        if isinstance(ws, str) and ws and ws != "__all__":
            cmd.extend(["--workshop", ws])
        self._run_cmd(cmd)

    def _run_query_list(self) -> None:
        ws = self.query_one("#list_ws", Select).value
        cmd = [self._py(), str(QUERY), *self._db_arg(), "list"]
        if isinstance(ws, str) and ws and ws != "__all__":
            cmd.extend(["--workshop", ws])
        self._run_cmd(cmd)

    def _run_query_search(self) -> None:
        kw = self.query_one("#search_kw", Input).value.strip()
        if not kw:
            self._log().write("Enter a search keyword.")
            return
        ws = self.query_one("#search_ws", Select).value
        cmd = [self._py(), str(QUERY), *self._db_arg(), "search", kw]
        if isinstance(ws, str) and ws and ws != "__all__":
            cmd.extend(["--workshop", ws])
        self._run_cmd(cmd)

    def _run_query_get(self) -> None:
        raw = self.query_one("#get_ids", Input).value.strip()
        if not raw:
            self._log().write("Enter one or more chunk ids.")
            return
        parts = raw.split()
        ids: list[str] = []
        for p in parts:
            if p.isdigit():
                ids.append(p)
            else:
                self._log().write(f"Invalid id (not an integer): {p}")
                return
        if not ids:
            self._log().write("No valid ids.")
            return
        cmd = [self._py(), str(QUERY), *self._db_arg(), "get", *ids]
        self._run_cmd(cmd)
