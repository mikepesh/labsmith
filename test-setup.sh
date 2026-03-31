#!/bin/bash
# LabSmith — Setup Script Tester
# Simulates missing prerequisites by hiding commands from PATH.
#
# Usage:
#   bash test-setup.sh                  # run all scenarios
#   bash test-setup.sh --no-python      # simulate missing Python
#   bash test-setup.sh --no-git         # simulate missing git
#   bash test-setup.sh --no-brew        # simulate missing Homebrew
#   bash test-setup.sh --old-python     # simulate Python 3.9
#   bash test-setup.sh --no-python --no-git  # combine flags
#   bash test-setup.sh --clean          # full clean install simulation

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAKE_BIN="/tmp/labsmith-test-bin"

# ── Build fake command stubs ──
setup_fakes() {
    rm -rf "$FAKE_BIN"
    mkdir -p "$FAKE_BIN"
}

# Create a stub that mimics a missing command (exits with error)
hide_command() {
    local cmd="$1"
    cat > "$FAKE_BIN/$cmd" << 'STUB'
#!/bin/bash
echo "labsmith-test: $0 is hidden for testing" >&2
exit 127
STUB
    chmod +x "$FAKE_BIN/$cmd"
}

# Create a Python stub that reports version 3.9
fake_old_python() {
    cat > "$FAKE_BIN/python3" << 'STUB'
#!/bin/bash
if [[ "$*" == *"sys.version_info"* ]]; then
    echo "3.9"
else
    exec /usr/bin/env python3.real "$@"
fi
STUB
    chmod +x "$FAKE_BIN/python3"
}

# ── Parse flags ──
NO_PYTHON=false
NO_GIT=false
NO_BREW=false
OLD_PYTHON=false
CLEAN=false
RUN_ALL=true

for arg in "$@"; do
    case "$arg" in
        --no-python)  NO_PYTHON=true; RUN_ALL=false ;;
        --no-git)     NO_GIT=true; RUN_ALL=false ;;
        --no-brew)    NO_BREW=true; RUN_ALL=false ;;
        --old-python) OLD_PYTHON=true; RUN_ALL=false ;;
        --clean)      CLEAN=true; RUN_ALL=false ;;
        --help|-h)
            echo "Usage: bash test-setup.sh [flags]"
            echo ""
            echo "Flags (combine as needed):"
            echo "  --no-python    Hide python3"
            echo "  --no-git       Hide git"
            echo "  --no-brew      Hide brew"
            echo "  --old-python   Fake Python 3.9"
            echo "  --clean        All prerequisites missing"
            echo "  (no flags)     Run all scenarios one by one"
            exit 0
            ;;
        *)
            echo "Unknown flag: $arg (try --help)"
            exit 1
            ;;
    esac
done

# ── Run a single scenario ──
run_scenario() {
    local name="$1"
    shift

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  SCENARIO: $name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    setup_fakes

    # Apply each requested hide/fake
    for cmd in "$@"; do
        case "$cmd" in
            no-python)  hide_command python3 ;;
            no-git)     hide_command git ;;
            no-brew)    hide_command brew ;;
            old-python) fake_old_python ;;
        esac
    done

    # Run setup.sh with fake bin first in PATH
    # Use 'yes n' to auto-decline install prompts (we're just testing detection)
    echo "(Auto-declining any install prompts with 'n')"
    echo ""
    yes n 2>/dev/null | PATH="$FAKE_BIN:$PATH" bash "$SCRIPT_DIR/setup.sh" "$SCRIPT_DIR" 2>&1 || true

    echo ""
    echo "  ^^^ End of scenario: $name"
    echo ""
}

# ── Single scenario mode ──
if ! $RUN_ALL; then
    label=""
    cmds=()

    if $CLEAN; then
        label="Clean install (nothing available)"
        cmds=(no-python no-git no-brew)
    else
        $NO_PYTHON && { label="${label}no-python "; cmds+=(no-python); }
        $OLD_PYTHON && { label="${label}old-python "; cmds+=(old-python); }
        $NO_GIT && { label="${label}no-git "; cmds+=(no-git); }
        $NO_BREW && { label="${label}no-brew "; cmds+=(no-brew); }
    fi

    run_scenario "$label" "${cmds[@]}"
    rm -rf "$FAKE_BIN"
    exit 0
fi

# ── Run all scenarios ──
echo ""
echo "Running all setup scenarios..."
echo "(Each scenario auto-declines install prompts)"

run_scenario "Everything installed (happy path)"
run_scenario "Missing Python"                     no-python
run_scenario "Old Python (3.9)"                   old-python
run_scenario "Missing git"                        no-git
run_scenario "Missing Python + git"               no-python no-git
run_scenario "Missing Homebrew + Python"          no-brew no-python
run_scenario "Clean install (nothing)"            no-python no-git no-brew

rm -rf "$FAKE_BIN"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  All scenarios complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
