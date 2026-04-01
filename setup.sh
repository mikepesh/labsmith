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

LABSMITH_DIR="${1:-$(cd "$(dirname "$0")" && pwd)}"

labsmith_display_path() {
    local d="$1"
    echo "${d//\/Documents\/CODING\/labsmith/\/Documents\/labsmith}"
}

PASS="✅"
FAIL="❌"
WARN="⚠️"
needs_python=false
needs_git=false

# macOS: Homebrew is often missing from non-interactive / minimal PATH
if [ "$(uname)" = "Darwin" ]; then
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# python3 may still be Apple 3.9; python@3.12 is keg-only — prepend its bin when present
labsmith_setup_get_py_ver() {
    python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo ""
}

labsmith_setup_prepend_brew_python312() {
    [ "$(uname)" = "Darwin" ] || return 1
    brew --version >/dev/null 2>&1 || return 1
    local px
    px=$(brew --prefix python@3.12 2>/dev/null) || return 1
    [ -n "$px" ] && [ -x "$px/bin/python3" ] || return 1
    export PATH="$px/bin:$PATH"
    return 0
}

echo ""
echo "═══════════════════════════════════════"
echo "  LabSmith Setup"
echo "═══════════════════════════════════════"
echo ""

# ── Check Python 3.9+ (run python3 directly; stubs that exit 127 → empty version) ──
echo "Checking Python..."
PY_VERSION=$(labsmith_setup_get_py_ver)
PY_MAJOR=0
PY_MINOR=0
if [ -n "$PY_VERSION" ]; then
    PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
    PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)
fi
# Prefer Homebrew 3.12 when default python3 is too old (brew install does not replace /usr/bin/python3)
if [ -z "$PY_VERSION" ] || [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 9 ]; }; then
    if labsmith_setup_prepend_brew_python312; then
        PY_VERSION=$(labsmith_setup_get_py_ver)
        if [ -n "$PY_VERSION" ]; then
            PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
            PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)
        fi
    fi
fi
if [ -n "$PY_VERSION" ] && [ "$PY_MAJOR" -ge 3 ] && [ "$PY_MINOR" -ge 9 ]; then
    echo "  $PASS Python $PY_VERSION"
else
    if [ -n "$PY_VERSION" ]; then
        echo "  $FAIL Python $PY_VERSION found — need 3.9+ (install python@3.12 and re-run, or fix PATH)"
    else
        echo "  $FAIL Python 3 not found (or not usable)"
    fi
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
        echo "  • Python 3.9+:  brew install python@3.12"
        echo "    Then put it ahead of Apple Python: export PATH=\"\$(brew --prefix python@3.12)/bin:\$PATH\""
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
                labsmith_setup_prepend_brew_python312 || true
                PY_CHECK=""
                PY_CHECK=$(labsmith_setup_get_py_ver)
                if [ -n "$PY_CHECK" ]; then
                    PY_MAJOR=$(echo "$PY_CHECK" | cut -d. -f1)
                    PY_MINOR=$(echo "$PY_CHECK" | cut -d. -f2)
                    if [ "$PY_MAJOR" -ge 3 ] && [ "$PY_MINOR" -ge 9 ]; then
                        echo "  $PASS Python $PY_CHECK installed"
                    else
                        echo "  $FAIL Python $PY_CHECK still below 3.9. Try: brew install python@3.12"
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
                    if [ "$PY_MAJOR" -lt 3 ] || [ "$PY_MINOR" -lt 9 ]; then
                        echo "  $FAIL Python $PY_CHECK — need 3.9+"
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
        echo "Install Python 3.9+ and git using your OS package manager, then re-run:"
        echo "    bash setup.sh"
        echo ""
        exit 1
    fi
fi

# ── Repo check ──
echo ""
echo "Checking LabSmith repo..."
if [ -f "$LABSMITH_DIR/chunker.py" ] && [ -f "$LABSMITH_DIR/query.py" ] && [ -f "$LABSMITH_DIR/marker/process-now.sh" ]; then
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
TO_PROC_ABS=$(cd "$MARKER_DIR/to-process" && pwd)
echo "  $PASS Marker dirs ready (inbox: $TO_PROC_ABS)"

# ── Verify Marker runs ──
echo ""
echo "═══════════════════════════════════════"
echo "  Running verification"
echo "═══════════════════════════════════════"
echo ""

echo "Testing PDF converter (quick check — does not convert files in to-process/)..."
echo "  (Use labsmith.sh or bash marker/process-now.sh when you are ready to convert.)"
# Running process-now.sh with no args would convert every PDF in to-process/ (very slow) and would
# not print "nothing to do", incorrectly failing this step after a successful run.
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
echo "Prerequisites and checks are done. The guided PDF → workshop flow is in labsmith.sh"
echo "(6 steps: welcome, prerequisites, workshop, add PDFs, convert + chunk, Cowork)."
echo ""
echo "  PDF inbox (full path — you’ll see this again in step 4 of labsmith.sh):"
echo "    $TO_PROC_ABS"
echo ""
echo "  Start the interactive script from the repo root:"
echo "    cd \"$LABSMITH_DIR\" && bash labsmith.sh"
echo ""
echo "  When you reach the end of that script, mount this folder in Cowork:"
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
