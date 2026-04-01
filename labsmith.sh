#!/usr/bin/env bash
# LabSmith — bootstrap: ensure Python 3.9+, marker/venv with Textual + pymupdf4llm, then launch TUI.
# Silent on success. Usage: bash labsmith.sh [--db PATH]
#
# Legacy bash wizard: bash scripts/labsmith-wizard.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || exit 1

VENV="$ROOT/marker/venv"
PY="$VENV/bin/python3"
PIP="$VENV/bin/pip"

if ! command -v python3 >/dev/null 2>&1; then
    echo "LabSmith needs Python 3.9 or newer."
    echo "  https://www.python.org/downloads/"
    echo "  macOS (Homebrew): brew install python@3.12"
    exit 1
fi

if ! python3 -c 'import sys; assert sys.version_info >= (3, 9)' 2>/dev/null; then
    echo "LabSmith needs Python 3.9+. This interpreter is too old:"
    python3 -c 'import sys; print(sys.version)' 2>/dev/null || true
    echo "  https://www.python.org/downloads/"
    echo "  macOS (Homebrew): brew install python@3.12"
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
    echo "Setting up LabSmith... (one-time)"
    mkdir -p "$ROOT/marker"
    if [[ ! -x "$PY" ]]; then
        python3 -m venv "$VENV"
    fi
    "$PIP" install -q pymupdf4llm textual
fi

exec "$PY" -u -m tui "$@"
