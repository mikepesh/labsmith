# LabSmith — shared prerequisite detection, system package install, Marker venv.
# Source after LABSMITH_DIR is set. Optional:
#   LABSMITH_PREREQS_USE_COLOR   — non-empty: use RED/YELLOW/GREEN/NC (labsmith.sh)
#   LABSMITH_PREREQS_RERUN_CMD  — shown in manual-install hints (default: bash setup.sh)

# shellcheck shell=bash
# shellcheck disable=SC2034  # needs_python / needs_git set for callers

labsmith_prereqs_msg_plain() { echo "$*"; }
labsmith_prereqs_msg_warn() {
    if [ -n "${LABSMITH_PREREQS_USE_COLOR:-}" ]; then
        echo -e "${YELLOW}$*${NC}"
    else
        echo "$*"
    fi
}
labsmith_prereqs_msg_err() {
    if [ -n "${LABSMITH_PREREQS_USE_COLOR:-}" ]; then
        echo -e "${RED}$*${NC}"
    else
        echo "$*"
    fi
}

labsmith_prereqs_rerun_cmd() { echo "${LABSMITH_PREREQS_RERUN_CMD:-bash setup.sh}"; }

labsmith_prereqs_brew_shellenv_darwin() {
    if [ "$(uname)" = "Darwin" ]; then
        if [ -x /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
}

labsmith_prereqs_python_version_or_empty() {
    python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo ""
}

# python@3.12 is keg-only; put it ahead of /usr/bin/python3 (often old on macOS)
labsmith_prereqs_prepend_brew_python312() {
    [ "$(uname)" = "Darwin" ] || return 1
    brew --version >/dev/null 2>&1 || return 1
    local px
    px=$(brew --prefix python@3.12 2>/dev/null) || return 1
    [ -n "$px" ] && [ -x "$px/bin/python3" ] || return 1
    export PATH="$px/bin:$PATH"
    return 0
}

labsmith_prereqs_git_version_or_empty() {
    if git --version >/dev/null 2>&1; then
        git --version 2>/dev/null | awk '{print $3}'
    else
        echo ""
    fi
}

# Resolve python3 version after trying Homebrew 3.12 when default is missing or < 3.9
labsmith_prereqs_effective_python_version() {
    local v maj min
    v=$(labsmith_prereqs_python_version_or_empty)
    if [ -n "$v" ]; then
        maj=$(echo "$v" | cut -d. -f1)
        min=$(echo "$v" | cut -d. -f2)
        if [ "$maj" -lt 3 ] || { [ "$maj" -eq 3 ] && [ "$min" -lt 9 ]; }; then
            labsmith_prereqs_prepend_brew_python312 && v=$(labsmith_prereqs_python_version_or_empty)
        fi
    else
        labsmith_prereqs_prepend_brew_python312 && v=$(labsmith_prereqs_python_version_or_empty)
    fi
    echo "$v"
}

labsmith_prereqs_repo_layout_ok() {
    [ -f "$LABSMITH_DIR/chunker.py" ] && [ -f "$LABSMITH_DIR/query.py" ] && [ -f "$LABSMITH_DIR/marker/process-now.sh" ]
}

# User-facing paths (Cowork/docs assume ~/Documents/labsmith, not .../Documents/CODING/labsmith)
labsmith_prereqs_display_path_for_docs() {
    local d="$1"
    echo "${d//\/Documents\/CODING\/labsmith/\/Documents\/labsmith}"
}

labsmith_prereqs_print_manual_macos() {
    labsmith_prereqs_msg_err ""
    labsmith_prereqs_msg_err "Install prerequisites manually, then re-run:"
    if [ -n "${LABSMITH_PREREQS_USE_COLOR:-}" ]; then
        echo -e "     ${CYAN}$(labsmith_prereqs_rerun_cmd)${NC}"
    else
        echo "     $(labsmith_prereqs_rerun_cmd)"
    fi
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

labsmith_prereqs_print_manual_linux_apt() {
    labsmith_prereqs_msg_err ""
    labsmith_prereqs_msg_err "Install prerequisites manually, then re-run:"
    if [ -n "${LABSMITH_PREREQS_USE_COLOR:-}" ]; then
        echo -e "     ${CYAN}$(labsmith_prereqs_rerun_cmd)${NC}"
    else
        echo "     $(labsmith_prereqs_rerun_cmd)"
    fi
    echo ""
    echo "  Example (Debian/Ubuntu):"
    echo "    sudo apt-get update && sudo apt-get install -y python3 python3-venv git"
    echo ""
}

# Sets globals needs_python, needs_git and LABSMITH_PREREQS_CACHED_{PY_VER,GIT_VER}
# (call after labsmith_prereqs_brew_shellenv_darwin)
labsmith_prereqs_eval_needs_flags() {
    needs_python=false
    needs_git=false
    local maj min
    LABSMITH_PREREQS_CACHED_PY_VER=$(labsmith_prereqs_effective_python_version)
    if [ -z "$LABSMITH_PREREQS_CACHED_PY_VER" ]; then
        needs_python=true
    else
        maj=$(echo "$LABSMITH_PREREQS_CACHED_PY_VER" | cut -d. -f1)
        min=$(echo "$LABSMITH_PREREQS_CACHED_PY_VER" | cut -d. -f2)
        if [ "$maj" -lt 3 ] || { [ "$maj" -eq 3 ] && [ "$min" -lt 9 ]; }; then
            needs_python=true
        fi
    fi
    LABSMITH_PREREQS_CACHED_GIT_VER=$(labsmith_prereqs_git_version_or_empty)
    if [ -z "$LABSMITH_PREREQS_CACHED_GIT_VER" ]; then
        needs_git=true
    fi
}

# Install Homebrew packages (macOS) or apt packages (Linux) when needs_python || needs_git.
# Uses needs_python, needs_git; exits on failure. Honors LABSMITH_PREREQS_USE_COLOR and LABSMITH_PREREQS_RERUN_CMD.
labsmith_prereqs_install_system_packages() {
    if ! $needs_python && ! $needs_git; then
        return 0
    fi
    echo ""
    if [[ "$(uname)" == "Darwin" ]]; then
        local brew_line=""
        if brew --version >/dev/null 2>&1; then
            brew_line=$(brew --version 2>/dev/null | head -n1)
        fi
        if [ -z "$brew_line" ]; then
            labsmith_prereqs_msg_warn "Missing prerequisites require Homebrew to install automatically."
            echo ""
            if [ -n "${LABSMITH_PREREQS_USE_COLOR:-}" ]; then
                read -r -p "$(echo -e "${YELLOW}Install Homebrew? (y/n) ${NC}")" -n 1 hr
            else
                read -r -p "Install Homebrew? (y/n) " -n 1 hr
            fi
            echo ""
            if [[ $hr =~ ^[Yy]$ ]]; then
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true
                if [ -f /opt/homebrew/bin/brew ]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                elif [ -f /usr/local/bin/brew ]; then
                    eval "$(/usr/local/bin/brew shellenv)"
                fi
                if brew --version >/dev/null 2>&1; then
                    brew_line=$(brew --version 2>/dev/null | head -n1)
                else
                    brew_line=""
                fi
                if [ -z "$brew_line" ]; then
                    echo ""
                    labsmith_prereqs_msg_err "❌ Homebrew install did not produce a working brew."
                    labsmith_prereqs_print_manual_macos
                    exit 1
                fi
            else
                echo ""
                labsmith_prereqs_msg_err "❌ Homebrew is required on macOS for the guided install path you skipped."
                labsmith_prereqs_print_manual_macos
                exit 1
            fi
        fi
        local to_install=""
        $needs_python && to_install="python@3.12"
        if $needs_git; then
            [ -n "$to_install" ] && to_install="$to_install git" || to_install="git"
        fi
        echo ""
        if [ -n "${LABSMITH_PREREQS_USE_COLOR:-}" ]; then
            read -r -p "$(echo -e "${YELLOW}Install $to_install via Homebrew? (y/n) ${NC}")" -n 1 hr
        else
            read -r -p "Install $to_install via Homebrew? (y/n) " -n 1 hr
        fi
        echo ""
        if [[ $hr =~ ^[Yy]$ ]]; then
            brew install $to_install || true
            echo ""
            if $needs_python; then
                labsmith_prereqs_prepend_brew_python312 || true
                local pyc maj min
                pyc=$(labsmith_prereqs_python_version_or_empty)
                if [ -z "$pyc" ]; then
                    labsmith_prereqs_msg_err "❌ Python install failed. Try: brew install python@3.12"
                    labsmith_prereqs_print_manual_macos
                    exit 1
                fi
                maj=$(echo "$pyc" | cut -d. -f1)
                min=$(echo "$pyc" | cut -d. -f2)
                if ! { [ "$maj" -gt 3 ] || { [ "$maj" -eq 3 ] && [ "$min" -ge 9 ]; }; }; then
                    labsmith_prereqs_msg_err "❌ Python $pyc still below 3.9. Try: brew install python@3.12"
                    labsmith_prereqs_print_manual_macos
                    exit 1
                fi
                labsmith_prereqs_msg_plain "  ✅ Python $pyc installed"
            fi
            if $needs_git; then
                local gitc
                gitc=$(labsmith_prereqs_git_version_or_empty)
                if [ -z "$gitc" ]; then
                    labsmith_prereqs_msg_err "❌ git install failed. Try: brew install git"
                    labsmith_prereqs_print_manual_macos
                    exit 1
                fi
                labsmith_prereqs_msg_plain "  ✅ git $gitc installed"
            fi
        else
            echo ""
            labsmith_prereqs_msg_err "❌ Declined installing these packages via Homebrew: $to_install"
            labsmith_prereqs_print_manual_macos
            exit 1
        fi
    elif [[ "$(uname)" == "Linux" ]]; then
        local to_install=""
        $needs_python && to_install="python3 python3-venv"
        if $needs_git; then
            [ -n "$to_install" ] && to_install="$to_install git" || to_install="git"
        fi
        labsmith_prereqs_msg_plain "Missing: $to_install"
        local apt_line=""
        if apt-get --version >/dev/null 2>&1; then
            apt_line=$(apt-get --version 2>/dev/null | head -n1)
        fi
        if [ -n "$apt_line" ]; then
            echo ""
            if [ -n "${LABSMITH_PREREQS_USE_COLOR:-}" ]; then
                read -r -p "$(echo -e "${YELLOW}Install via apt? (y/n) ${NC}")" -n 1 hr
            else
                read -r -p "Install via apt? (y/n) " -n 1 hr
            fi
            echo ""
            if [[ $hr =~ ^[Yy]$ ]]; then
                sudo apt-get update -qq && sudo apt-get install -y $to_install || true
                echo ""
                if $needs_python; then
                    local pyc maj min
                    pyc=$(labsmith_prereqs_python_version_or_empty)
                    if [ -z "$pyc" ]; then
                        labsmith_prereqs_msg_err "❌ Python still not usable after apt install."
                        labsmith_prereqs_print_manual_linux_apt
                        exit 1
                    fi
                    maj=$(echo "$pyc" | cut -d. -f1)
                    min=$(echo "$pyc" | cut -d. -f2)
                    if ! { [ "$maj" -gt 3 ] || { [ "$maj" -eq 3 ] && [ "$min" -ge 9 ]; }; }; then
                        labsmith_prereqs_msg_err "❌ Python $pyc — need 3.9+"
                        labsmith_prereqs_print_manual_linux_apt
                        exit 1
                    fi
                    labsmith_prereqs_msg_plain "  ✅ Python $pyc"
                fi
                if $needs_git; then
                    local gitc
                    gitc=$(labsmith_prereqs_git_version_or_empty)
                    if [ -z "$gitc" ]; then
                        labsmith_prereqs_msg_err "❌ git still not usable after apt install."
                        labsmith_prereqs_print_manual_linux_apt
                        exit 1
                    fi
                    labsmith_prereqs_msg_plain "  ✅ git $gitc"
                fi
            else
                echo ""
                labsmith_prereqs_msg_err "❌ Guided apt install declined."
                labsmith_prereqs_print_manual_linux_apt
                exit 1
            fi
        else
            echo ""
            labsmith_prereqs_msg_err "❌ apt-get not found. Install with your distro’s package manager:"
            labsmith_prereqs_msg_plain "    $to_install"
            echo ""
            exit 1
        fi
    else
        echo ""
        labsmith_prereqs_msg_err "❌ Automatic install is only wired for macOS (Homebrew) and Linux (apt)."
        labsmith_prereqs_msg_plain "Install Python 3.9+ and git using your OS package manager, then re-run:"
        labsmith_prereqs_msg_plain "    $(labsmith_prereqs_rerun_cmd)"
        echo ""
        exit 1
    fi
    return 0
}

# mode: setup | wizard — setup uses plain ✅/⚠️ lines; wizard uses labsmith TP_* and colors
labsmith_prereqs_ensure_pymupdf_venv() {
    local mode="${1:-setup}"
    MARKER_DIR="${MARKER_DIR:-$LABSMITH_DIR/marker}"
    VENV_DIR="${VENV_DIR:-$MARKER_DIR/venv}"
    mkdir -p "$MARKER_DIR/to-process" "$MARKER_DIR/output" "$MARKER_DIR/processed"

    if [ -f "$VENV_DIR/bin/python3" ] && "$VENV_DIR/bin/python3" -c "import pymupdf4llm" 2>/dev/null; then
        if [ "$mode" = "wizard" ]; then
            return 0
        fi
        labsmith_prereqs_msg_plain "  ✅ pymupdf4llm already installed"
        return 0
    fi

    if [ "$mode" = "wizard" ]; then
        echo -e "  ${TP_WARN} ${BOLD}pymupdf4llm${NC} not in Marker venv — installing..."
    else
        labsmith_prereqs_msg_plain "  ⚠️ pymupdf4llm not found — installing..."
    fi
    python3 -m venv "$VENV_DIR" 2>/dev/null || true
    if [ -f "$VENV_DIR/bin/pip" ]; then
        "$VENV_DIR/bin/pip" install --quiet pymupdf4llm 2>/dev/null || true
    fi
    if [ -f "$VENV_DIR/bin/python3" ] && "$VENV_DIR/bin/python3" -c "import pymupdf4llm" 2>/dev/null; then
        if [ "$mode" = "wizard" ]; then
            echo -e "  ${GREEN}${TP_PASS}${NC}  ${BOLD}pymupdf4llm${NC} installed"
        else
            labsmith_prereqs_msg_plain "  ✅ pymupdf4llm installed"
        fi
        return 0
    fi
    if [ "$mode" = "wizard" ]; then
        echo -e "  ${RED}${TP_FAIL}${NC}  Could not install pymupdf4llm."
        echo "     Try: cd $MARKER_DIR && python3 -m venv venv && venv/bin/pip install pymupdf4llm"
    else
        labsmith_prereqs_msg_err "  ❌ pymupdf4llm install failed"
        labsmith_prereqs_msg_plain "     Try manually: cd $MARKER_DIR && python3 -m venv venv && venv/bin/pip install pymupdf4llm"
    fi
    exit 1
}

labsmith_prereqs_marker_inbox_abs() {
    MARKER_DIR="${MARKER_DIR:-$LABSMITH_DIR/marker}"
    mkdir -p "$MARKER_DIR/to-process" "$MARKER_DIR/output" "$MARKER_DIR/processed"
    (cd "$MARKER_DIR/to-process" && pwd)
}
