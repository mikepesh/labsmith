"""Run subprocesses with line streaming onto the Textual main thread."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path
from typing import Callable, Sequence

from textual.app import App


def stream_command(
    app: App,
    cmd: Sequence[str],
    cwd: Path,
    log_line: Callable[[str], None],
    on_exit: Callable[[int], None],
) -> None:
    """
    Run cmd in a worker thread; call log_line (via call_from_thread) per stdout line.
    on_exit is called with return code (or -1 on spawn error).
    """

    def work() -> None:
        env = os.environ.copy()
        env["PYTHONUNBUFFERED"] = "1"
        try:
            proc = subprocess.Popen(
                list(cmd),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                cwd=str(cwd),
                bufsize=1,
                env=env,
            )
        except OSError as exc:
            app.call_from_thread(log_line, f"Error starting process: {exc}")
            app.call_from_thread(on_exit, -1)
            return

        if proc.stdout is None:
            code = proc.wait()
            app.call_from_thread(on_exit, code if code is not None else 0)
            return

        for line in proc.stdout:
            app.call_from_thread(log_line, line.rstrip("\n\r"))
        code = proc.wait()
        app.call_from_thread(on_exit, code if code is not None else 0)

    app.run_worker(work, thread=True, exclusive=True)


def stream_command_ansi(
    app: App,
    cmd: Sequence[str],
    cwd: Path,
    log_rich,
    on_exit: Callable[[int], None],
) -> None:
    """Like stream_command but passes lines through Rich ANSI parsing for log_rich.write."""

    def work() -> None:
        from rich.text import Text

        env = os.environ.copy()
        env["PYTHONUNBUFFERED"] = "1"
        try:
            proc = subprocess.Popen(
                list(cmd),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                cwd=str(cwd),
                bufsize=1,
                env=env,
            )
        except OSError as exc:
            app.call_from_thread(log_rich.write, f"Error starting process: {exc}")
            app.call_from_thread(on_exit, -1)
            return

        if proc.stdout is None:
            code = proc.wait()
            app.call_from_thread(on_exit, code if code is not None else 0)
            return

        for line in proc.stdout:
            raw = line.rstrip("\n\r")
            try:
                t = Text.from_ansi(raw)
                app.call_from_thread(log_rich.write, t)
            except Exception:
                app.call_from_thread(log_rich.write, raw)
        code = proc.wait()
        app.call_from_thread(on_exit, code if code is not None else 0)

    app.run_worker(work, thread=True, exclusive=True)
