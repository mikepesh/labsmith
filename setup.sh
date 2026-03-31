#!/bin/bash
# LabSmith — Setup
# Run this once to check prerequisites, install dependencies, and verify everything works.
#
# Usage:
#   bash setup.sh                    # install to default location
#   bash setup.sh /path/to/labsmith  # install to custom location
#
# No `set -e` — every failure path is handled explicitly. Detection uses real invocations
# (e.g. python3 -c ..., git --version) so PATH stubs that replace binaries are detected
# as “missing” when they exit non‑zero, not via `command -v`.

LABSMITH_DIR="${1:-$(cd "$(dirname "$0")" && pwd)}"
PASS="✅"
FAIL="❌"
WARN="⚠️"
needs_python=false
needs_git=false

echo ""
echo "═══════════════════════════════════════"
echo "  LabSmith Setup"
echo "═══════════════════════════════════════"
echo ""

# ── Check Python 3.10+ (run python3 directly; stubs that exit 127 → empty version) ──
echo "Checking Python..."
PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null) || PY_VERSION=""
if [ -n "$PY_VERSION" ]; then
    PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
    PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)
    if [ "$PY_MAJOR" -ge 3 ] && [ "$PY_MINOR" -ge 10 ]; then
        echo "  $PASS Python $PY_VERSION"
    else
        echo "  $FAIL Python $PY_VERSION found — need 3.10+"
        needs_python=true
    fi
else
    echo "  $FAIL Python 3 not found (or not usable)"
    needs_python=true
fi

# ── Check Git (run git --version; do not use command -v) ──
echo "Checking git..."
GIT_VERSION=""
if git --version >/dev/null 2>&1; then
    GIT_VERSION=$(git --version 2>/dev/null | awk '{print $3}')
fi
if [ -n "$GIT_VERSION" ]; then
    echo "  $PASS git $GIT_VERSION"
else
    echo "  $FAIL git not found (or not usable)"
    needs_git=true
fi

print_manual_install_macos() {
    echo ""
    echo "$FAIL Install prerequisites manually, then re-run:"
    echo "     bash setup.sh"
    echo ""
    echo "  • Homebrew (if needed): https://brew.sh"
    if $needs_python; then
        echo "  • Python 3.10+:  brew install python@3.12"
    fi
    if $needs_git; then
        echo "  • Git:             brew install git"
    fi
    echo ""
}

print_manual_install_linux_apt() {
    echo ""
    echo "$FAIL Install prerequisites manually, then re-run:"
    echo "     bash setup.sh"
    echo ""
    echo "  Example (Debian/Ubuntu):"
    echo "    sudo apt-get update && sudo apt-get install -y python3 python3-venv git"
    echo ""
}

# ── Install missing prerequisites ──
if $needs_python || $needs_git; then
    echo ""

    if [[ "$(uname)" == "Darwin" ]]; then
        BREW_LINE=""
        # Do not rely on pipeline exit status (head can mask a failing brew stub).
        if brew --version >/dev/null 2>&1; then
            BREW_LINE=$(brew --version 2>/dev/null | head -n1)
        fi
        if [ -z "$BREW_LINE" ]; then
            echo "Missing prerequisites require Homebrew to install automatically."
            echo ""
            read -p "Install Homebrew? (y/n) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true
                if [ -f /opt/homebrew/bin/brew ]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                elif [ -f /usr/local/bin/brew ]; then
                    eval "$(/usr/local/bin/brew shellenv)"
                fi
                if brew --version >/dev/null 2>&1; then
                    BREW_LINE=$(brew --version 2>/dev/null | head -n1)
                else
                    BREW_LINE=""
                fi
                if [ -z "$BREW_LINE" ]; then
                    echo ""
                    echo "$FAIL Homebrew install did not produce a working brew."
                    print_manual_install_macos
                    exit 1
                fi
            else
                echo ""
                echo "$FAIL Homebrew is required on macOS for the guided install path you skipped."
                print_manual_install_macos
                exit 1
            fi
        fi

        to_install=""
        $needs_python && to_install="python@3.12"
        if $needs_git; then
            [ -n "$to_install" ] && to_install="$to_install git" || to_install="git"
        fi

        echo ""
        read -p "Install $to_install via Homebrew? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            brew install $to_install || true
            echo ""

            if $needs_python; then
                PY_CHECK=""
                PY_CHECK=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null) || PY_CHECK=""
                if [ -n "$PY_CHECK" ]; then
                    PY_MAJOR=$(echo "$PY_CHECK" | cut -d. -f1)
                    PY_MINOR=$(echo "$PY_CHECK" | cut -d. -f2)
                    if [ "$PY_MAJOR" -ge 3 ] && [ "$PY_MINOR" -ge 10 ]; then
                        echo "  $PASS Python $PY_CHECK installed"
                    else
                        echo "  $FAIL Python $PY_CHECK still below 3.10. Try: brew install python@3.12"
                        print_manual_install_macos
                        exit 1
                    fi
                else
                    echo "  $FAIL Python install failed. Try: brew install python@3.12"
                    print_manual_install_macos
                    exit 1
                fi
            fi
            if $needs_git; then
                GIT_CHECK=""
                GIT_CHECK=$(git --version 2>/dev/null | awk '{print $3}') || GIT_CHECK=""
                if [ -n "$GIT_CHECK" ]; then
                    echo "  $PASS git $GIT_CHECK installed"
                else
                    echo "  $FAIL git install failed. Try: brew install git"
                    print_manual_install_macos
                    exit 1
                fi
            fi
        else
            echo ""
            echo "$FAIL Declined installing these packages via Homebrew: $to_install"
            print_manual_install_macos
            exit 1
        fi

    elif [[ "$(uname)" == "Linux" ]]; then
        to_install=""
        $needs_python && to_install="python3 python3-venv"
        if $needs_git; then
            [ -n "$to_install" ] && to_install="$to_install git" || to_install="git"
        fi

        echo "Missing: $to_install"
        APT_LINE=""
        if apt-get --version >/dev/null 2>&1; then
            APT_LINE=$(apt-get --version 2>/dev/null | head -n1)
        fi

        if [ -n "$APT_LINE" ]; then
            echo ""
            read -p "Install via apt? (y/n) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo apt-get update -qq && sudo apt-get install -y $to_install || true
                echo ""
                if $needs_python; then
                    PY_CHECK=""
                    PY_CHECK=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null) || PY_CHECK=""
                    if [ -z "$PY_CHECK" ]; then
                        echo "  $FAIL Python still not usable after apt install."
                        print_manual_install_linux_apt
                        exit 1
                    fi
                    PY_MAJOR=$(echo "$PY_CHECK" | cut -d. -f1)
                    PY_MINOR=$(echo "$PY_CHECK" | cut -d. -f2)
                    if [ "$PY_MAJOR" -lt 3 ] || [ "$PY_MINOR" -lt 10 ]; then
                        echo "  $FAIL Python $PY_CHECK — need 3.10+"
                        print_manual_install_linux_apt
                        exit 1
                    fi
                    echo "  $PASS Python $PY_CHECK"
                fi
                if $needs_git; then
                    GIT_CHECK=""
                    GIT_CHECK=$(git --version 2>/dev/null | awk '{print $3}') || GIT_CHECK=""
                    if [ -z "$GIT_CHECK" ]; then
                        echo "  $FAIL git still not usable after apt install."
                        print_manual_install_linux_apt
                        exit 1
                    fi
                    echo "  $PASS git $GIT_CHECK"
                fi
            else
                echo ""
                echo "$FAIL Guided apt install declined."
                print_manual_install_linux_apt
                exit 1
            fi
        else
            echo ""
            echo "$FAIL apt-get not found. Install with your distro’s package manager:"
            echo "    $to_install"
            echo ""
            exit 1
        fi
    else
        echo ""
        echo "$FAIL Automatic install is only wired for macOS (Homebrew) and Linux (apt)."
        echo "Install Python 3.10+ and git using your OS package manager, then re-run:"
        echo "    bash setup.sh"
        echo ""
        exit 1
    fi
fi

# ── Repo check ──
echo ""
echo "Checking LabSmith repo..."
if [ -f "$LABSMITH_DIR/chunker.py" ] && [ -f "$LABSMITH_DIR/query.py" ] && [ -f "$LABSMITH_DIR/marker/process-now.sh" ]; then
    echo "  $PASS Repo found at $LABSMITH_DIR"
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

if [ -f "$VENV_DIR/bin/python3" ] && "$VENV_DIR/bin/python3" -c "import pymupdf4llm" 2>/dev/null; then
    echo "  $PASS pymupdf4llm already installed"
else
    echo "  $WARN pymupdf4llm not found — installing..."
    python3 -m venv "$VENV_DIR" 2>/dev/null || true
    if [ -f "$VENV_DIR/bin/pip" ]; then
        "$VENV_DIR/bin/pip" install --quiet pymupdf4llm 2>/dev/null || true
    fi
    if [ -f "$VENV_DIR/bin/python3" ] && "$VENV_DIR/bin/python3" -c "import pymupdf4llm" 2>/dev/null; then
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
MARKER_OUTPUT=$(bash "$MARKER_DIR/process-now.sh" 2>&1) || true
if echo "$MARKER_OUTPUT" | grep -q "nothing to do"; then
    echo "  $PASS Marker works"
else
    echo "  $FAIL Marker test failed:"
    echo "     $MARKER_OUTPUT"
    exit 1
fi

# ── Verify chunker + query ──
echo "Testing chunker and query tool..."
TEST_RESULT=$(bash "$LABSMITH_DIR/test-pipeline.sh" 2>&1) || true
if echo "$TEST_RESULT" | grep -qE "PASS:[[:space:]]*[1-9]"; then
    PASSED=$(echo "$TEST_RESULT" | grep -oE "PASS:[[:space:]]*[0-9]+" | head -1)
    echo "  $PASS Pipeline tests reported $PASSED"
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
