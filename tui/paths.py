"""Repository root and standard paths (cwd is expected to be repo root)."""

from __future__ import annotations

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MARKER_DIR = REPO_ROOT / "marker"
OUTPUT_DIR = MARKER_DIR / "output"
TOPROC_DIR = MARKER_DIR / "to-process"
VENV_PYTHON = MARKER_DIR / "venv" / "bin" / "python3"
PROCESS_SCRIPT = MARKER_DIR / "process-now.sh"
CHUNKER = REPO_ROOT / "chunker.py"
QUERY = REPO_ROOT / "query.py"
TEST_PIPELINE = REPO_ROOT / "test-pipeline.sh"
