#!/bin/bash
# LabSmith — Setup Script Tester
# Simulates missing prerequisites by placing fake stubs ahead of real commands in PATH.
#
# Usage:
#   bash test-setup.sh                  # run all scenarios
#   bash test-setup.sh --no-python      # simulate missing Python
#   bash test-setup.sh --no-git         # simulate missing git
#   bash test-setup.sh --no-brew        # simulate missing Homebrew
#   bash test-setup.sh --old-python     # simulate Python 3.9
#   bash test-setup.sh --no-python --no-git
#   bash test-setup.sh --clean          # python + git + brew missing
#
# No `set -e` — each scenario runs to completion and reports exit status.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAKE_BIN="/tmp/labsmith-test-bin"

# Feed enough "n" answers for multiple read -p prompts (Homebrew + brew install, etc.)
auto_decline_installs() {
    # One line per prompt; setup.sh may ask up to 2 times on macOS
    printf '%s\n' n n n n n n n
}

# ── Build fake command stubs ──
setup_fakes() {
    rm -rf "$FAKE_BIN"
    mkdir -p "$FAKE_BIN"
}

hide_command() {
    local cmd="$1"
    cat > "$FAKE_BIN/$cmd" << 'STUB'
#!/bin/bash
echo "labsmith-test: $(basename "$0") is a stub (simulating missing / broken command)" >&2
exit 127
STUB
    chmod +x "$FAKE_BIN/$cmd"
}

# Python stub: version probe prints 3.9; other invocations delegate to a real interpreter (not from FAKE_BIN)
fake_old_python() {
    local real_py=""
    for cand in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
        if [ -x "$cand" ]; then
            real_py="$cand"
            break
        fi
    done
    cat > "$FAKE_BIN/python3" << EOF
#!/bin/bash
# labsmith-test: old-python — version check returns 3.9; else real interpreter
case "\$*" in
  *sys.version_info*)
    echo "3.9"
    exit 0
    ;;
esac
if [ -n "$real_py" ] && [ -x "$real_py" ]; then
  exec "$real_py" "\$@"
fi
echo "labsmith-test: python3 stub — no system python to delegate to" >&2
exit 127
EOF
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
            echo "  --no-python    Stub python3 (exit 127)"
            echo "  --no-git       Stub git (exit 127)"
            echo "  --no-brew      Stub brew (exit 127)"
            echo "  --old-python   Fake Python 3.9 for version probe"
            echo "  --clean        Stub python3, git, and brew"
            echo "  (no flags)     Run all scenarios sequentially"
            exit 0
            ;;
        *)
            echo "Unknown flag: $arg (try --help)"
            exit 1
            ;;
    esac
done

run_scenario() {
    local name="$1"
    shift
    local exit_code=0

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  SCENARIO: $name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    setup_fakes

    for cmd in "$@"; do
        case "$cmd" in
            no-python)  hide_command python3 ;;
            no-git)     hide_command git ;;
            no-brew)    hide_command brew ;;
            old-python) fake_old_python ;;
        esac
    done

    echo "(Auto-declining install prompts with 'n')"
    echo ""

    # Prepend fake bin so stubs shadow real commands — same as users with broken PATH shims
    PATH="$FAKE_BIN:$PATH"
    export PATH

    auto_decline_installs | bash "$SCRIPT_DIR/setup.sh" "$SCRIPT_DIR" 2>&1
    exit_code=${PIPESTATUS[1]}

    echo ""
    if [ "$exit_code" -eq 0 ]; then
        echo "  RESULT: setup.sh exited 0 (success)"
    else
        echo "  RESULT: setup.sh exited $exit_code (expected for missing prerequisites / declined installs)"
    fi
    echo "  --- End scenario: $name ---"
    echo ""
}

# ── Single scenario mode (flags) ──
if ! $RUN_ALL; then
    label=""
    cmds=()

    if $CLEAN; then
        label="clean (no python, git, or brew)"
        cmds=(no-python no-git no-brew)
    else
        $NO_PYTHON && cmds+=(no-python)
        $OLD_PYTHON && cmds+=(old-python)
        $NO_GIT && cmds+=(no-git)
        $NO_BREW && cmds+=(no-brew)
        label=""
        for c in "${cmds[@]}"; do
            [ -z "$label" ] && label="$c" || label="$label $c"
        done
        [ -z "$label" ] && label="(no scenario cmds — check flags)"
    fi

    run_scenario "$label" "${cmds[@]}"
    rm -rf "$FAKE_BIN"
    exit 0
fi

# ── All scenarios ──
echo ""
echo "Running all setup scenarios (each auto-declines installs where prompted)"
echo ""

run_scenario "Happy path (no stubs)"
run_scenario "Missing Python"                     no-python
run_scenario "Old Python (3.9)"                   old-python
run_scenario "Missing git"                        no-git
run_scenario "Missing Python + git"              no-python no-git
run_scenario "Missing Homebrew + Python"         no-brew no-python
run_scenario "Clean (no python, git, brew)"      no-python no-git no-brew

rm -rf "$FAKE_BIN"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  All scenarios complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
