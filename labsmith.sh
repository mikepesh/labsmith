#!/bin/bash
# LabSmith — Interactive workshop prep (PDF → markdown → SQLite)
# Bash 3.2+ (macOS default). No extra dependencies.
#
# Usage:  cd /path/to/labsmith && bash labsmith.sh
#         bash labsmith.sh --step prereqs
#         LABSMITH_WORKSHOP=my-ws bash labsmith.sh --step convert
# Sim menu: bash labsmith-sim.sh

# ── ANSI ─────────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LABSMITH_DIR="$SCRIPT_DIR"
MARKER_DIR="$LABSMITH_DIR/marker"
VENV_DIR="$MARKER_DIR/venv"
DB_PATH="$LABSMITH_DIR/labsmith.db"
WATCH_DIR="$MARKER_DIR/to-process"
# Inner width between ║ and ║ (must match ═ count on ╔═══╗ line)
LABSMITH_BOX_IW=54
TP_PASS="✅"
TP_FAIL="❌"
TP_WARN="⚠️"
LABSMITH_ISSUES_URL="https://github.com/mikepesh/labsmith/issues"

needs_python=false
needs_git=false
SELECTED_WORKSHOP=""

labsmith_cleanup_int() {
    echo ""
    echo -e "${RED}Interrupted — run ${BOLD}bash labsmith.sh${NC}${RED} or ${BOLD}bash labsmith-sim.sh${NC}${RED} again anytime.${NC}"
    exit 130
}
trap labsmith_cleanup_int INT

# ── Helpers ────────────────────────────────────────────────────────
labsmith_farewell_quit() {
    echo ""
    echo "Thanks for trying this out."
    echo "If it failed you in one way or another, or you ran into a login issue, please tell us here:"
    echo -e "  ${CYAN}${LABSMITH_ISSUES_URL}${NC}"
    echo ""
}

labsmith_pause() {
    echo ""
    read -r -p "Press Enter to continue... " _
}

labsmith_str_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# User-facing paths only (Cowork/docs assume ~/Documents/labsmith, not .../Documents/CODING/labsmith)
labsmith_path_for_display() {
    local d="$1"
    echo "${d//\/Documents\/CODING\/labsmith/\/Documents\/labsmith}"
}

# Center plain ASCII in the banner interior (${#} is exact for ASCII on bash 3.2)
labsmith_center_in_box() {
    local text="$1"
    local width="${2:-$LABSMITH_BOX_IW}"
    local len=${#text}
    if [ "$len" -gt "$width" ]; then
        text="${text:0:$width}"
        len=$width
    fi
    local left=$(( (width - len) / 2 ))
    local right=$(( width - len - left ))
    printf '%*s%s%*s' "$left" '' "$text" "$right" ''
}

labsmith_file_size_bytes() {
    local f="$1"
    if [ "$(uname)" = "Darwin" ]; then
        stat -f%z "$f" 2>/dev/null
    else
        stat -c%s "$f" 2>/dev/null
    fi
}

labsmith_bytes_to_mb() {
    local b="$1"
    awk "BEGIN { printf \"%d\", ($b + 512) / 1024 / 1024 }"
}

labsmith_bytes_to_kb() {
    local b="$1"
    awk "BEGIN { printf \"%d\", ($b + 512) / 1024 }"
}

labsmith_print_pdf_list() {
    local dir="$1"
    local total_bytes=0
    local n=0
    local tmp
    tmp=$(mktemp)
    find "$dir" -maxdepth 1 -type f \( -iname '*.pdf' \) 2>/dev/null | sort >"$tmp"
    n=$(wc -l <"$tmp" | tr -d '[:space:]')
    [ -z "$n" ] && n=0
    echo ""
    if [ "$n" -eq 0 ]; then
        echo -e "    ${DIM}(no PDFs yet)${NC}"
        echo ""
        rm -f "$tmp"
        return 1
    fi
    echo -e "  ${BOLD}Found $n file(s):${NC}"
    echo ""
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        local base sz b mb
        base=$(basename "$f")
        sz=$(labsmith_file_size_bytes "$f")
        b="${sz:-0}"
        mb=$(labsmith_bytes_to_mb "$b")
        total_bytes=$((total_bytes + b))
        echo -e "    📄  ${WHITE}$base${NC}  (${mb} MB)"
    done <"$tmp"
    rm -f "$tmp"
    local tmb
    tmb=$(labsmith_bytes_to_mb "$total_bytes")
    echo ""
    echo -e "  ${DIM}Total: $n PDF(s), ${tmb} MB${NC}"
    echo ""
    return 0
}

labsmith_workshop_line_stats() {
    local w="$1"
    if [ ! -f "$DB_PATH" ]; then
        echo "0 0"
        return
    fi
    local s chunks typesline
    s=$(python3 "$LABSMITH_DIR/query.py" --db "$DB_PATH" stats --workshop "$w" 2>/dev/null) || s=""
    if [ -z "$s" ]; then
        echo "0 0"
        return
    fi
    chunks=$(echo "$s" | grep '^chunks=' | head -1 | sed 's/^chunks=//')
    chunks="${chunks:-0}"
    typesline=$(echo "$s" | sed -n '/^by_doc_type:/,$p' | grep -c 'chunks=' 2>/dev/null) || typesline=0
    echo "$chunks $typesline"
}

# Same install messaging as setup.sh (manual)
labsmith_manual_macos() {
    echo ""
    echo -e "${RED}Install prerequisites manually, then re-run:${NC}"
    echo -e "     ${CYAN}bash labsmith.sh${NC}"
    echo ""
    echo "  • Homebrew (if needed): https://brew.sh"
    $needs_python && echo "  • Python 3.9+:  brew install python@3.12"
    $needs_python && echo "    export PATH=\"\$(brew --prefix python@3.12)/bin:\$PATH\"  (before Apple /usr/bin/python3)"
    $needs_git && echo "  • Git:             brew install git"
    echo ""
}

labsmith_manual_linux() {
    echo ""
    echo -e "${RED}Install prerequisites manually, then re-run:${NC}"
    echo -e "     ${CYAN}bash labsmith.sh${NC}"
    echo ""
    echo "  Example (Debian/Ubuntu):"
    echo "    sudo apt-get update && sudo apt-get install -y python3 python3-venv git"
    echo ""
}

labsmith_python_version_or_empty() {
    python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo ""
}

# python@3.12 is keg-only; put it ahead of /usr/bin/python3 (often 3.9 on macOS)
labsmith_prepend_brew_python312_path() {
    [ "$(uname)" = "Darwin" ] || return 1
    brew --version >/dev/null 2>&1 || return 1
    local px
    px=$(brew --prefix python@3.12 2>/dev/null) || return 1
    [ -n "$px" ] && [ -x "$px/bin/python3" ] || return 1
    export PATH="$px/bin:$PATH"
    return 0
}

labsmith_git_version_or_empty() {
    if git --version >/dev/null 2>&1; then
        git --version 2>/dev/null | awk '{print $3}'
    else
        echo ""
    fi
}

# Mirrors setup.sh prerequisite install when needs_python || needs_git
labsmith_install_prereqs_if_needed() {
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
            echo -e "${YELLOW}Missing prerequisites require Homebrew to install automatically.${NC}"
            echo ""
            read -r -p "Install Homebrew? (y/n) " -n 1 hr
            echo ""
            if [[ $hr =~ ^[Yy]$ ]]; then
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true
                [ -f /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
                [ -f /usr/local/bin/brew ] && eval "$(/usr/local/bin/brew shellenv)"
                if ! brew --version >/dev/null 2>&1; then
                    echo -e "${RED}Homebrew install did not produce a working brew.${NC}"
                    labsmith_manual_macos
                    exit 1
                fi
            else
                echo -e "${RED}Homebrew is required on macOS for the guided install path you skipped.${NC}"
                labsmith_manual_macos
                exit 1
            fi
        fi
        local to_install=""
        $needs_python && to_install="python@3.12"
        if $needs_git; then
            [ -n "$to_install" ] && to_install="$to_install git" || to_install="git"
        fi
        echo ""
        read -r -p "Install $to_install via Homebrew? (y/n) " -n 1 hr
        echo ""
        if [[ $hr =~ ^[Yy]$ ]]; then
            brew install $to_install || true
            echo ""
            if $needs_python; then
                labsmith_prepend_brew_python312_path || true
                local pyc maj min
                pyc=$(labsmith_python_version_or_empty)
                if [ -z "$pyc" ]; then
                    echo -e "${RED}Python install failed.${NC}"; labsmith_manual_macos; exit 1
                fi
                maj=$(echo "$pyc" | cut -d. -f1); min=$(echo "$pyc" | cut -d. -f2)
                if ! { [ "$maj" -gt 3 ] || { [ "$maj" -eq 3 ] && [ "$min" -ge 9 ]; }; }; then
                    echo -e "${RED}Python still below 3.9.${NC}"; labsmith_manual_macos; exit 1
                fi
            fi
            if $needs_git; then
                if ! git --version >/dev/null 2>&1; then
                    echo -e "${RED}git install failed.${NC}"; labsmith_manual_macos; exit 1
                fi
            fi
        else
            echo -e "${RED}Declined installing: $to_install${NC}"
            labsmith_manual_macos
            exit 1
        fi
    elif [[ "$(uname)" == "Linux" ]]; then
        local to_install=""
        $needs_python && to_install="python3 python3-venv"
        if $needs_git; then
            [ -n "$to_install" ] && to_install="$to_install git" || to_install="git"
        fi
        echo "Missing: $to_install"
        if apt-get --version >/dev/null 2>&1; then
            read -r -p "Install via apt? (y/n) " -n 1 hr
            echo ""
            if [[ $hr =~ ^[Yy]$ ]]; then
                sudo apt-get update -qq && sudo apt-get install -y $to_install || true
            else
                labsmith_manual_linux
                exit 1
            fi
        else
            echo -e "${RED}apt-get not found.${NC}"
            labsmith_manual_linux
            exit 1
        fi
        if $needs_python; then
            local pyc maj min
            pyc=$(labsmith_python_version_or_empty)
            if [ -z "$pyc" ]; then labsmith_manual_linux; exit 1; fi
            maj=$(echo "$pyc" | cut -d. -f1); min=$(echo "$pyc" | cut -d. -f2)
            if ! { [ "$maj" -gt 3 ] || { [ "$maj" -eq 3 ] && [ "$min" -ge 9 ]; }; }; then
                labsmith_manual_linux; exit 1
            fi
        fi
        if $needs_git && ! git --version >/dev/null 2>&1; then
            labsmith_manual_linux
            exit 1
        fi
    else
        echo -e "${RED}Automatic install only on macOS (Homebrew) and Linux (apt).${NC}"
        labsmith_manual_linux
        exit 1
    fi
    return 0
}

labsmith_pymupdf_ok() {
    [ -f "$VENV_DIR/bin/python3" ] && "$VENV_DIR/bin/python3" -c "import pymupdf4llm" 2>/dev/null
}

labsmith_ensure_pymupdf_and_dirs() {
    mkdir -p "$MARKER_DIR/to-process" "$MARKER_DIR/output" "$MARKER_DIR/processed"
    if labsmith_pymupdf_ok; then
        return 0
    fi
    echo -e "  ${TP_WARN} ${BOLD}pymupdf4llm${NC} not in Marker venv — installing..."
    python3 -m venv "$VENV_DIR" 2>/dev/null || true
    if [ -f "$VENV_DIR/bin/pip" ]; then
        "$VENV_DIR/bin/pip" install --quiet pymupdf4llm 2>/dev/null || true
    fi
    if labsmith_pymupdf_ok; then
        echo -e "  ${GREEN}${TP_PASS}${NC}  ${BOLD}pymupdf4llm${NC} installed"
        return 0
    fi
    echo -e "  ${RED}${TP_FAIL}${NC}  Could not install pymupdf4llm."
    echo "     Try: cd $MARKER_DIR && python3 -m venv venv && venv/bin/pip install pymupdf4llm"
    exit 1
}

# For --step convert|done when workshop selection was skipped
labsmith_sim_apply_workshop_env() {
    if [ -z "$SELECTED_WORKSHOP" ] && [ -n "${LABSMITH_WORKSHOP:-}" ]; then
        SELECTED_WORKSHOP=$(labsmith_str_lower "${LABSMITH_WORKSHOP}")
    fi
}

labsmith_sim_require_workshop() {
    labsmith_sim_apply_workshop_env
    if [ -z "$SELECTED_WORKSHOP" ]; then
        echo ""
        echo -e "  ${YELLOW}${TP_WARN}${NC} No workshop was selected in this shell (skipped step 3)."
        read -r -p "  Workshop name (lowercase-hyphens, e.g. my-workshop): " SELECTED_WORKSHOP
        SELECTED_WORKSHOP=$(labsmith_str_lower "$(echo "$SELECTED_WORKSHOP" | tr -d '[:space:]')")
    fi
    if ! echo "$SELECTED_WORKSHOP" | grep -qE '^[a-z0-9][a-z0-9-]*$'; then
        echo -e "  ${RED}Invalid workshop name. Use lowercase letters, numbers, hyphens.${NC}"
        echo "  Or set ${BOLD}LABSMITH_WORKSHOP${NC} before running this step."
        return 1
    fi
    mkdir -p "$LABSMITH_DIR/workshops/$SELECTED_WORKSHOP/modules" "$LABSMITH_DIR/workshops/$SELECTED_WORKSHOP/references"
    return 0
}

# ═══ Step 1 ═══
labsmith_step_welcome() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${WHITE}$(labsmith_center_in_box "LabSmith v0.1.0")${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${DIM}$(labsmith_center_in_box "Workshop Builder for Presales Engineers")${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${DIM}Convert vendor PDFs into searchable reference material for workshop building.${NC}"
    echo ""
    echo "  This script will walk you through checking prerequisites, processing your PDFs,"
    echo "  and preparing your docs for module building in Cowork."
    echo ""
    labsmith_pause
}

# ═══ Step 2 ═══
labsmith_step_prereqs() {
    clear
    echo ""
    echo -e "${BOLD}${WHITE}  ═══ Prerequisites ═══${NC}"
    echo ""
    echo "  Checking prerequisites..."
    echo ""

    local py_disp git_disp pym_disp dir_disp
    local pyver gitver

    needs_python=false
    needs_git=false

    if [ "$(uname)" = "Darwin" ]; then
        if [ -x /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi

    pyver=$(labsmith_python_version_or_empty)
    if [ -n "$pyver" ]; then
        local maj min
        maj=$(echo "$pyver" | cut -d. -f1)
        min=$(echo "$pyver" | cut -d. -f2)
        if [ "$maj" -lt 3 ] || { [ "$maj" -eq 3 ] && [ "$min" -lt 9 ]; }; then
            labsmith_prepend_brew_python312_path && pyver=$(labsmith_python_version_or_empty)
        fi
    else
        labsmith_prepend_brew_python312_path && pyver=$(labsmith_python_version_or_empty)
    fi

    if [ -n "$pyver" ]; then
        local maj min
        maj=$(echo "$pyver" | cut -d. -f1)
        min=$(echo "$pyver" | cut -d. -f2)
        if [ "$maj" -gt 3 ] || { [ "$maj" -eq 3 ] && [ "$min" -ge 9 ]; }; then
            py_disp=$(printf "  %-16s ${GREEN}${TP_PASS}${NC}  %s" "Python 3.9+" "$pyver")
        else
            py_disp=$(printf "  %-16s ${RED}${TP_FAIL}${NC}  need 3.9+ (have %s)" "Python 3.9+" "$pyver")
            needs_python=true
        fi
    else
        py_disp=$(printf "  %-16s ${RED}${TP_FAIL}${NC}  not found" "Python 3.9+")
        needs_python=true
    fi

    gitver=$(labsmith_git_version_or_empty)
    if [ -n "$gitver" ]; then
        git_disp=$(printf "  %-16s ${GREEN}${TP_PASS}${NC}  %s" "git" "$gitver")
    else
        git_disp=$(printf "  %-16s ${RED}${TP_FAIL}${NC}  not found" "git")
        needs_git=true
    fi

    if labsmith_pymupdf_ok; then
        pym_disp=$(printf "  %-16s ${GREEN}${TP_PASS}${NC}  %s" "pymupdf4llm" "installed")
    else
        pym_disp=$(printf "  %-16s ${YELLOW}${TP_WARN}${NC}  %s" "pymupdf4llm" "will install next")
    fi

    if [ -d "$MARKER_DIR" ]; then
        dir_disp=$(printf "  %-16s ${GREEN}${TP_PASS}${NC}  %s" "Marker dirs" "ready")
    else
        dir_disp=$(printf "  %-16s ${RED}${TP_FAIL}${NC}  %s" "Marker dirs" "missing")
    fi

    echo -e "$py_disp"
    echo -e "$git_disp"
    echo -e "$pym_disp"
    echo -e "$dir_disp"
    echo ""

    if $needs_python || $needs_git; then
        labsmith_install_prereqs_if_needed
    fi

    labsmith_ensure_pymupdf_and_dirs
    echo ""
    sleep 1
}

# ═══ Step 3 ═══
labsmith_step_workshop() {
    clear
    echo ""
    echo -e "${BOLD}${WHITE}  ═══ Workshop ═══${NC}"
    echo ""

    mkdir -p "$LABSMITH_DIR/workshops"
    local wlist
    wlist=$(mktemp)
    find "$LABSMITH_DIR/workshops" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort |
        while IFS= read -r d; do
            [ -n "$d" ] || continue
            basename "$d"
        done >"$wlist"

    local idx
    idx=$(awk 'NF { c++ } END { print c+0 }' "$wlist" 2>/dev/null)
    [ -z "$idx" ] && idx=0

    echo "  Existing workshops:"
    echo ""
    if [ "$idx" -eq 0 ]; then
        echo -e "    ${DIM}(none yet)${NC}"
    else
        local i=0
        while IFS= read -r wname; do
            [ -n "$wname" ] || continue
            i=$((i + 1))
            local st ch dt
            st=$(labsmith_workshop_line_stats "$wname")
            ch=$(echo "$st" | awk '{print $1}')
            dt=$(echo "$st" | awk '{print $2}')
            echo -e "    ${CYAN}$i)${NC} $wname  ${DIM}(${ch} chunks, $dt doc type(s))${NC}"
        done <"$wlist"
    fi
    echo ""
    echo -e "  ${YELLOW}[n]${NC} Create new workshop"
    echo ""
    local pr="  Select (n for new"
    [ "$idx" -gt 0 ] && pr="${pr}, or 1-$idx"
    pr="${pr}): "
    read -r -p "$pr" choice
    choice=$(labsmith_str_lower "$(echo "$choice" | tr -d '[:space:]')")

    if [ "$choice" = "n" ] || [ "$choice" = "new" ]; then
        while true; do
            read -r -p "  New workshop name (lowercase, hyphens, e.g. acme-workshop): " nw
            nw=$(echo "$nw" | tr -d '[:space:]')
            if echo "$nw" | grep -qE '^[a-z0-9][a-z0-9-]*$'; then
                mkdir -p "$LABSMITH_DIR/workshops/$nw/modules" "$LABSMITH_DIR/workshops/$nw/references"
                SELECTED_WORKSHOP="$nw"
                echo -e "  ${GREEN}${TP_PASS}${NC} Created workshop ${BOLD}$nw${NC}"
                break
            fi
            echo -e "  ${RED}Use only lowercase letters, numbers, and hyphens.${NC}"
        done
    else
        if ! echo "$choice" | grep -qE '^[0-9]+$' || [ "$choice" -lt 1 ] || [ "$choice" -gt "$idx" ] || [ "$idx" -eq 0 ]; then
            echo -e "${RED}Invalid selection.${NC}"
            rm -f "$wlist"
            exit 1
        fi
        SELECTED_WORKSHOP=$(sed -n "${choice}p" "$wlist")
        rm -f "$wlist"
        echo -e "  ${GREEN}${TP_PASS}${NC} Using workshop ${BOLD}$SELECTED_WORKSHOP${NC}"
    fi
    rm -f "$wlist"
    labsmith_pause
}

# ═══ Step 4 ═══
labsmith_step_drop_files() {
    local abs_in abs_show done_drop
    abs_in=$(cd "$WATCH_DIR" && pwd 2>/dev/null || echo "$WATCH_DIR")
    abs_show=$(labsmith_path_for_display "$abs_in")
    done_drop=false
    while [ "$done_drop" != "true" ]; do
        clear
        echo ""
        echo -e "${BOLD}${WHITE}  ═══ Add Documents ═══${NC}"
        echo ""
        echo "  Drop your PDF files into this folder:"
        echo ""
        echo -e "    📂  ${CYAN}$abs_in${NC}"
        if [ "$abs_in" != "$abs_show" ]; then
            echo -e "  ${DIM}(in Cowork, this repo may appear under: $abs_show)${NC}"
        fi
        echo ""

        while true; do
            read -r -p "  When your files are in place, press Enter (r refresh, w workshop, q quit)... " action
            action=$(labsmith_str_lower "$(echo "$action" | tr -d '[:space:]')")
            if [ "$action" = "r" ]; then
                labsmith_print_pdf_list "$WATCH_DIR" || true
                continue
            fi
            if [ "$action" = "w" ]; then
                labsmith_step_workshop
                break
            fi
            if [ "$action" = "q" ]; then
                labsmith_farewell_quit
                exit 0
            fi
            if labsmith_print_pdf_list "$WATCH_DIR"; then
                done_drop=true
                break
            fi
            echo -e "  ${YELLOW}${TP_WARN}${NC} No PDFs found. Add files to the folder above, then press Enter,"
            echo "           or ${BOLD}w${NC} to go back to workshop selection, ${BOLD}q${NC} to quit."
        done
    done
    labsmith_pause
}

# ═══ Step 5 ═══
labsmith_step_convert() {
    clear
    local tmp
    tmp=$(mktemp)
    find "$WATCH_DIR" -maxdepth 1 -type f \( -iname '*.pdf' \) 2>/dev/null | sort >"$tmp"
    local n=0
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        n=$((n + 1))
    done <"$tmp"

    if [ "$n" -eq 0 ]; then
        echo "No PDFs to process."
        rm -f "$tmp"
        exit 1
    fi

    # Build array file -> basename (bash 3: use temp mapping file)
    local mapf
    mapf=$(mktemp)
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        echo "$(basename "$f")" >>"$mapf"
    done <"$tmp"
    rm -f "$tmp"

    declare -a BASENAMES
    local i=0
    while IFS= read -r base; do
        [ -n "$base" ] || continue
        BASENAMES[$i]="$base"
        i=$((i + 1))
    done <"$mapf"
    rm -f "$mapf"
    local nb=${#BASENAMES[@]}

    echo ""
    echo -e "  ${BOLD}Ready to process $nb file(s) for workshop \"${SELECTED_WORKSHOP}\"${NC}"
    echo ""
    read -r -p "  Press Enter to start, or q to quit... " go
    go=$(labsmith_str_lower "$(echo "$go" | tr -d '[:space:]')")
    if [ "$go" = "q" ]; then
        labsmith_farewell_quit
        exit 0
    fi

    mkdir -p "$LABSMITH_DIR/workshops/$SELECTED_WORKSHOP/references"

    local fi=0
    while [ "$fi" -lt "$nb" ]; do
        local base base_noext outmd
        base="${BASENAMES[$fi]}"
        base_noext="${base%.pdf}"
        base_noext="${base_noext%.PDF}"
        outmd="$MARKER_DIR/output/${base_noext}.md"

        clear
        echo ""
        echo -e "${DIM}  ── Processing $((fi + 1)) of $nb ─────────────────────────────────${NC}"
        echo ""
        echo -e "  ${CYAN}🔄 Converting:${NC} $base"
        echo ""

        local pdfpath="$WATCH_DIR/$base"
        if [ ! -f "$pdfpath" ]; then
            pdfpath=$(find "$WATCH_DIR" -maxdepth 1 -type f -iname "$base" 2>/dev/null | head -1)
        fi
        if [ ! -f "$pdfpath" ]; then
            echo -e "  ${RED}${TP_FAIL}${NC} PDF not found: $base (already processed?)"
        else
            bash "$MARKER_DIR/process-now.sh" "$base"
            echo ""
        fi

        if [ -f "$outmd" ]; then
            local osz okb
            osz=$(labsmith_file_size_bytes "$outmd")
            okb=$(labsmith_bytes_to_kb "${osz:-0}")
            echo -e "  ${GREEN}${TP_PASS}${NC} Converted: ${okb} KB"
            echo ""
            echo -e "  ${CYAN}🔄 Chunking into SQLite...${NC}"
            local cout
            cout=$(python3 "$LABSMITH_DIR/chunker.py" "$outmd" --workshop "$SELECTED_WORKSHOP" --db "$DB_PATH" 2>&1)
            echo "$cout"
            local inserted
            inserted=$(echo "$cout" | sed -n 's/^Chunks inserted: //p' | head -1)
            inserted="${inserted:-?}"
            echo -e "  ${GREEN}${TP_PASS}${NC} ${inserted} chunks stored for this file"
            if [ -f "$outmd" ]; then
                cp "$outmd" "$LABSMITH_DIR/workshops/$SELECTED_WORKSHOP/references/" 2>/dev/null || true
            fi
        else
            echo -e "  ${RED}${TP_FAIL}${NC} No markdown output for $base — check conversion errors above."
        fi
        echo ""
        fi=$((fi + 1))
    done

    labsmith_pause
}

# ═══ Step 6 ═══
labsmith_step_done() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${WHITE}$(labsmith_center_in_box "Processing Complete")${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$DB_PATH" ]; then
        echo -e "  ${YELLOW}${TP_WARN}${NC} No database yet at labsmith.db"
        labsmith_pause
        return
    fi

    echo -e "  ${BOLD}📊 Workshop:${NC} $SELECTED_WORKSHOP"
    echo ""

    export LABSMITH_STAT_DB="$DB_PATH"
    export LABSMITH_STAT_WS="$SELECTED_WORKSHOP"
    python3 << 'PY'
import os
import sqlite3
import sys

db = os.environ.get("LABSMITH_STAT_DB", "")
ws = os.environ.get("LABSMITH_STAT_WS", "")
if not db or not ws:
    sys.exit(0)
try:
    conn = sqlite3.connect(db)
    row = conn.execute(
        "SELECT COUNT(*) AS c, COALESCE(SUM(line_count), 0) AS ln FROM chunks WHERE workshop = ?",
        (ws,),
    ).fetchone()
    chunks, lines = int(row[0]), int(row[1])
    doc_n = int(
        conn.execute(
            "SELECT COUNT(DISTINCT source_doc) FROM chunks WHERE workshop = ?",
            (ws,),
        ).fetchone()[0]
    )
    types = conn.execute(
        "SELECT doc_type, COUNT(*) AS c FROM chunks WHERE workshop = ? "
        "GROUP BY doc_type ORDER BY doc_type",
        (ws,),
    ).fetchall()
    conn.close()
except Exception:
    print("     (Could not read stats.)")
    sys.exit(0)

print(f"     Documents:  {doc_n}")
print(f"     Chunks:     {chunks}")
print(f"     Total lines: {lines:,}")
print("")
print("     By type:")
for dt, c in types:
    pad = max(3, 22 - len(dt))
    print(f"       {dt} {'.' * pad} {c} chunks")
PY
    unset LABSMITH_STAT_DB LABSMITH_STAT_WS

    echo ""
    echo -e "${BOLD}  ═══ What's Next ═══${NC}"
    echo ""
    echo "  1. Open Claude Desktop → start a Cowork session"
    echo "  2. Mount your labsmith folder:"
    echo -e "     📂  ${CYAN}$(labsmith_path_for_display "$LABSMITH_DIR")${NC}"
    echo "  3. Tell Claude what module to build:"
    echo ""
    echo "     \"Build a module on firewall policies for the $SELECTED_WORKSHOP workshop\""
    echo ""
    echo "  Other things you can ask:"
    echo "     \"What topics can I build from these docs?\""
    echo "     \"Build a module on VPN configuration\""
    echo "     \"What's in the reference database?\""
    echo ""
    if [ "$(uname)" = "Darwin" ] && command -v open >/dev/null 2>&1; then
        read -r -p "Press Enter to bring Claude to the front... " _
        echo ""
        open -a "Claude" 2>/dev/null || echo -e "  ${YELLOW}${TP_WARN}${NC} Could not open Claude — launch Claude Desktop manually."
    else
        labsmith_pause
    fi
}

# ═══ CLI / main ═══
labsmith_require_repo() {
    if [ ! -f "$LABSMITH_DIR/chunker.py" ] || [ ! -f "$LABSMITH_DIR/query.py" ] || [ ! -f "$MARKER_DIR/process-now.sh" ]; then
        echo -e "${RED}Run this script from the LabSmith repository root (chunker.py / query.py / marker/ missing).${NC}"
        return 1
    fi
    return 0
}

labsmith_usage() {
    echo "LabSmith interactive workflow"
    echo ""
    echo "  bash labsmith.sh              Run all steps (welcome → done)"
    echo "  bash labsmith.sh --step STEP  Run one step (for testing)"
    echo "  bash labsmith-sim.sh          Interactive step picker"
    echo ""
    echo "Steps: welcome, prereqs, workshop, drop, convert, done"
    echo "Aliases: files (drop), summary (done)"
    echo ""
    echo "For convert or done without running workshop selection first:"
    echo "  LABSMITH_WORKSHOP=my-ws bash labsmith.sh --step convert"
}

labsmith_run_full() {
    labsmith_step_welcome
    labsmith_step_prereqs
    labsmith_step_workshop
    labsmith_step_drop_files
    labsmith_step_convert
    labsmith_step_done
    echo ""
    echo -e "${GREEN}Done.${NC}"
    echo ""
}

labsmith_run_step() {
    local s
    s=$(labsmith_str_lower "$1")
    case "$s" in
        welcome)
            labsmith_step_welcome
            ;;
        prereqs|prerequisite|prerequisites)
            labsmith_step_prereqs
            ;;
        workshop|ws)
            labsmith_step_workshop
            ;;
        drop|files)
            labsmith_step_drop_files
            ;;
        convert|process)
            labsmith_sim_require_workshop || return 1
            labsmith_step_convert
            ;;
        done|summary|finish)
            labsmith_sim_require_workshop || return 1
            labsmith_step_done
            ;;
        *)
            echo -e "${RED}Unknown step: ${1:-}(empty)${NC}"
            echo "Valid: welcome, prereqs, workshop, drop, convert, done"
            return 1
            ;;
    esac
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    labsmith_usage
    exit 0
fi

if [ "${1:-}" = "--step" ]; then
    shift
    if ! labsmith_require_repo; then
        exit 1
    fi
    st="${1:-}"
    if [ -z "$st" ]; then
        labsmith_usage
        exit 1
    fi
    if ! labsmith_run_step "$st"; then
        exit 1
    fi
    exit 0
fi

if [ -n "${1:-}" ]; then
    echo -e "${RED}Unknown argument: $1${NC}"
    labsmith_usage
    exit 1
fi

if ! labsmith_require_repo; then
    exit 1
fi
labsmith_run_full

