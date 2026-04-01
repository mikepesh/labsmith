#!/bin/bash
# LabSmith — Setup
# Run this once to check prerequisites, install dependencies, and verify everything works.
#
# Usage:
#   bash setup.sh                    # install to default location
#   bash setup.sh /path/to/labsmith  # install to custom location
#   LABSMITH_SETUP_NO_WIZARD=1 bash setup.sh   # skip post-setup interactive steps
#
# No `set -e` — every failure path is handled explicitly. Detection uses real invocations
# (e.g. python3 -c ..., git --version) so PATH stubs that replace binaries are detected
# as “missing” when they exit non‑zero, not via `command -v`.

SETUP_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LABSMITH_DIR="${1:-$SETUP_SCRIPT_DIR}"
# shellcheck source=scripts/prereqs-common.sh
. "$SETUP_SCRIPT_DIR/scripts/prereqs-common.sh"

PASS="✅"
FAIL="❌"
WARN="⚠️"

labsmith_display_path() { labsmith_prereqs_display_path_for_docs "$1"; }

echo ""
echo "═══════════════════════════════════════"
echo "  LabSmith Setup"
echo "═══════════════════════════════════════"
echo ""

labsmith_prereqs_brew_shellenv_darwin
labsmith_prereqs_eval_needs_flags

echo "Checking Python..."
if ! $needs_python; then
    echo "  $PASS Python $LABSMITH_PREREQS_CACHED_PY_VER"
else
    if [ -n "$LABSMITH_PREREQS_CACHED_PY_VER" ]; then
        echo "  $FAIL Python $LABSMITH_PREREQS_CACHED_PY_VER found — need 3.9+ (install python@3.12 and re-run, or fix PATH)"
    else
        echo "  $FAIL Python 3 not found (or not usable)"
    fi
fi

echo "Checking git..."
if ! $needs_git; then
    echo "  $PASS git $LABSMITH_PREREQS_CACHED_GIT_VER"
else
    echo "  $FAIL git not found (or not usable)"
fi

if $needs_python || $needs_git; then
    labsmith_prereqs_install_system_packages
fi

# ── Repo check ──
echo ""
echo "Checking LabSmith repo..."
if labsmith_prereqs_repo_layout_ok; then
    echo "  $PASS Repo found at $(labsmith_display_path "$LABSMITH_DIR")"
else
    echo "  $FAIL LabSmith repo not found at $LABSMITH_DIR"
    echo "     Clone it first:"
    echo "     git clone https://github.com/mikepesh/labsmith.git $LABSMITH_DIR"
    exit 1
fi

# ── Marker venv + pymupdf4llm ──
echo "Checking PDF converter..."
MARKER_DIR="$LABSMITH_DIR/marker"
VENV_DIR="$MARKER_DIR/venv"
labsmith_prereqs_ensure_pymupdf_venv setup

# ── Directory structure ──
echo "Checking directories..."
TO_PROC_ABS=$(labsmith_prereqs_marker_inbox_abs)
echo "  $PASS Marker dirs ready (inbox: $TO_PROC_ABS)"

# ── Verify Marker runs ──
echo ""
echo "═══════════════════════════════════════"
echo "  Running verification"
echo "═══════════════════════════════════════"
echo ""

echo "Testing PDF converter (quick check — does not convert files in to-process/)..."
echo "  (Use labsmith.sh or bash marker/process-now.sh when you are ready to convert.)"
if ! "$VENV_DIR/bin/python3" -c "import pymupdf4llm, pymupdf" 2>/dev/null; then
    echo "  $FAIL Marker venv cannot import pymupdf4llm / pymupdf"
    exit 1
fi
if ! bash -n "$MARKER_DIR/process-now.sh" 2>/dev/null; then
    echo "  $FAIL process-now.sh has a bash syntax error"
    exit 1
fi
echo "  $PASS Marker stack and process-now.sh OK"

# ── Verify chunker + query (optional; test-pipeline.sh is maintainer-local, not in clone) ──
if [ -f "$LABSMITH_DIR/test-pipeline.sh" ]; then
    echo "Testing chunker and query tool..."
    TEST_RESULT=$(bash "$LABSMITH_DIR/test-pipeline.sh" 2>&1) || true
    if echo "$TEST_RESULT" | grep -qE "PASS:[[:space:]]*[1-9]"; then
        PASSED=$(echo "$TEST_RESULT" | grep -oE "PASS:[[:space:]]*[0-9]+" | head -1)
        echo "  $PASS Pipeline tests reported $PASSED"
    else
        echo "  $WARN Tests had issues (may need a PDF for full test suite)"
        echo "     Run manually: bash test-pipeline.sh"
    fi
else
    echo "Skipping pipeline tests (test-pipeline.sh not present — normal for a GitHub clone)."
fi

# ── Done — hand off to labsmith.sh (6-step interactive flow) ──
LS_ROOT_DISP=$(labsmith_display_path "$LABSMITH_DIR")

echo ""
echo "═══════════════════════════════════════"
echo "  $PASS Setup complete"
echo "═══════════════════════════════════════"
echo ""
echo "Prerequisites and checks are done. The main terminal UI is labsmith.sh (Textual TUI)."
echo ""
echo "  PDF inbox (full path):"
echo "    $TO_PROC_ABS"
echo ""
echo "  Start the TUI from the repo root:"
echo "    cd \"$LABSMITH_DIR\" && bash labsmith.sh"
echo ""
echo "  Mount this folder in Cowork when building modules:"
echo "    $LS_ROOT_DISP"
echo ""

if [ -t 0 ] && [ "${LABSMITH_SETUP_NO_WIZARD:-}" != "1" ]; then
    read -r -p "Launch labsmith.sh now? [Y/n] " _run_ls
    _run_ls=${_run_ls:-y}
    if [[ "$_run_ls" =~ ^[Yy] ]]; then
        echo ""
        ( cd "$LABSMITH_DIR" && bash labsmith.sh ) || true
        echo ""
    fi
else
    echo "(Non-interactive: run labsmith.sh in a terminal when ready.)"
    echo ""
fi
