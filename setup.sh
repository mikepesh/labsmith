#!/bin/bash
# LabSmith — Setup
# Run this once to check prerequisites, install dependencies, and verify everything works.
#
# Usage:
#   bash setup.sh                    # install to default location
#   bash setup.sh /path/to/labsmith  # install to custom location

set -e

LABSMITH_DIR="${1:-$(cd "$(dirname "$0")" && pwd)}"
PASS="✅"
FAIL="❌"
WARN="⚠️"
errors=0

echo ""
echo "═══════════════════════════════════════"
echo "  LabSmith Setup"
echo "═══════════════════════════════════════"
echo ""

# ── Python 3.10+ ──
echo "Checking Python..."
if command -v python3 &>/dev/null; then
    PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
    PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)
    if [ "$PY_MAJOR" -ge 3 ] && [ "$PY_MINOR" -ge 10 ]; then
        echo "  $PASS Python $PY_VERSION"
    else
        echo "  $FAIL Python $PY_VERSION found — need 3.10+"
        echo "     Install: https://www.python.org/downloads/"
        errors=$((errors + 1))
    fi
else
    echo "  $FAIL Python 3 not found"
    echo "     Install: https://www.python.org/downloads/"
    errors=$((errors + 1))
fi

# ── Git ──
echo "Checking git..."
if command -v git &>/dev/null; then
    echo "  $PASS git $(git --version | awk '{print $3}')"
else
    echo "  $FAIL git not found"
    echo "     Install: https://git-scm.com/downloads"
    errors=$((errors + 1))
fi

# ── Stop here if prerequisites are missing ──
if [ "$errors" -gt 0 ]; then
    echo ""
    echo "$FAIL Fix the issues above and re-run this script."
    exit 1
fi

# ── Repo check ──
echo "Checking LabSmith repo..."
if [ -f "$LABSMITH_DIR/chunker.py" ] && [ -f "$LABSMITH_DIR/query.py" ] && [ -f "$LABSMITH_DIR/marker/process-now.sh" ]; then
    echo "  $PASS Repo found at $LABSMITH_DIR"
else
    echo "  $FAIL LabSmith repo not found at $LABSMITH_DIR"
    echo "     Clone it first:"
    echo "     git clone git@github.com:mikepesh/labsmith.git $LABSMITH_DIR"
    exit 1
fi

# ── Marker venv + pymupdf4llm ──
echo "Checking PDF converter..."
MARKER_DIR="$LABSMITH_DIR/marker"
VENV_DIR="$MARKER_DIR/venv"

if [ -f "$VENV_DIR/bin/python3" ] && "$VENV_DIR/bin/python3" -c "import pymupdf4llm" 2>/dev/null; then
    echo "  $PASS pymupdf4llm already installed"
else
    echo "  $WARN pymupdf4llm not found — installing..."
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install --quiet pymupdf4llm
    if "$VENV_DIR/bin/python3" -c "import pymupdf4llm" 2>/dev/null; then
        echo "  $PASS pymupdf4llm installed"
    else
        echo "  $FAIL pymupdf4llm install failed"
        echo "     Try manually: cd $MARKER_DIR && python3 -m venv venv && venv/bin/pip install pymupdf4llm"
        exit 1
    fi
fi

# ── Directory structure ──
echo "Checking directories..."
mkdir -p "$MARKER_DIR/to-process" "$MARKER_DIR/output" "$MARKER_DIR/processed"
echo "  $PASS marker/to-process/, marker/output/, marker/processed/"

# ── Verify Marker runs ──
echo ""
echo "═══════════════════════════════════════"
echo "  Running verification"
echo "═══════════════════════════════════════"
echo ""

echo "Testing PDF converter..."
MARKER_OUTPUT=$(bash "$MARKER_DIR/process-now.sh" 2>&1)
if echo "$MARKER_OUTPUT" | grep -q "nothing to do"; then
    echo "  $PASS Marker works"
else
    echo "  $FAIL Marker test failed:"
    echo "     $MARKER_OUTPUT"
    exit 1
fi

# ── Verify chunker + query ──
echo "Testing chunker and query tool..."
TEST_RESULT=$(bash "$LABSMITH_DIR/test-pipeline.sh" 2>&1)
if echo "$TEST_RESULT" | grep -q "PASSED"; then
    PASSED=$(echo "$TEST_RESULT" | grep -c "PASSED")
    echo "  $PASS $PASSED tests passed"
else
    echo "  $WARN Tests had issues (may need a PDF for full test suite)"
    echo "     Run manually: bash test-pipeline.sh"
fi

# ── Done ──
echo ""
echo "═══════════════════════════════════════"
echo "  $PASS Setup complete"
echo "═══════════════════════════════════════"
echo ""
echo "You're ready to go. Next steps:"
echo ""
echo "  1. Drop a PDF in marker/to-process/"
echo "  2. Run:  bash marker/process-now.sh"
echo "  3. Run:  python3 chunker.py marker/output/<filename>.md \\"
echo "             --workshop <name> --doc-type admin"
echo "  4. Open Cowork, mount this folder, and say:"
echo "     \"Build a module on <topic> for the <name> workshop\""
echo ""
