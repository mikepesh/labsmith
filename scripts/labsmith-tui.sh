#!/usr/bin/env bash
# LabSmith — Textual TUI (experimental / testing only). Default workflow is bash labsmith.sh.
# From repo root: bash scripts/labsmith-tui.sh [--db PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT" || exit 1

VENV="$ROOT/marker/venv"
PY="$VENV/bin/python3"
PIP="$VENV/bin/pip"

if ! command -v python3 >/dev/null 2>&1; then
    echo "LabSmith TUI needs Python 3.9 or newer."
    echo "  https://www.python.org/downloads/"
    echo "  macOS (Homebrew): brew install python@3.12"
    exit 1
fi

if ! python3 -c 'import sys; assert sys.version_info >= (3, 9)' 2>/dev/null; then
    echo "LabSmith TUI needs Python 3.9+. This interpreter is too old:"
    python3 -c 'import sys; print(sys.version)' 2>/dev/null || true
    exit 1
fi

NEED=0
if [[ ! -x "$PY" ]]; then
    NEED=1
elif ! "$PY" -c "import textual" 2>/dev/null; then
    NEED=1
elif ! "$PY" -c "import pymupdf4llm" 2>/dev/null; then
    NEED=1
fi

if [[ "$NEED" -eq 1 ]]; then
    echo "Setting up LabSmith TUI deps in marker/venv... (one-time)"
    mkdir -p "$ROOT/marker"
    if [[ ! -x "$PY" ]]; then
        python3 -m venv "$VENV"
    fi
    "$PIP" install -q pymupdf4llm textual
fi

exec "$PY" -u -m tui "$@"
