#!/bin/bash
# LabSmith — Interactive workshop prep (PDF → markdown → SQLite)
# Bash 3.2+ (macOS default). No extra dependencies.
#
# Usage:  cd /path/to/labsmith && bash labsmith.sh

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
TP_PASS="✅"
TP_FAIL="❌"
TP_WARN="⚠️"

needs_python=false
needs_git=false
SELECTED_WORKSHOP=""

labsmith_cleanup_int() {
    echo ""
    echo -e "${RED}Interrupted — you can run ${BOLD}bash labsmith.sh${NC}${RED} again anytime.${NC}"
    exit 130
}
trap labsmith_cleanup_int INT

# ── Helpers ────────────────────────────────────────────────────────
labsmith_pause() {
    echo ""
    read -r -p "Press Enter to continue... " _
}

labsmith_str_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
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

labsmith_print_pdf_list() {
    local dir="$1"
    local total_bytes=0
    local n=0
    echo ""
    echo -e "  ${BOLD}Found files:${NC}"
    echo ""
    local tmp
    tmp=$(mktemp)
    find "$dir" -maxdepth 1 -type f \( -iname '*.pdf' \) 2>/dev/null | sort >"$tmp"
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        n=$((n + 1))
        local base sz b mb
        base=$(basename "$f")
        sz=$(labsmith_file_size_bytes "$f")
        b="${sz:-0}"
        mb=$(labsmith_bytes_to_mb "$b")
        total_bytes=$((total_bytes + b))
        echo -e "    📄  ${WHITE}$base${NC}  (${mb} MB)"
    done <"$tmp"
    rm -f "$tmp"
    if [ "$n" -eq 0 ]; then
        echo -e "    ${DIM}(no PDFs yet)${NC}"
        echo ""
        return 1
    fi
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
    $needs_python && echo "  • Python 3.10+:  brew install python@3.12"
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
                local pyc maj min
                pyc=$(labsmith_python_version_or_empty)
                if [ -z "$pyc" ]; then
                    echo -e "${RED}Python install failed.${NC}"; labsmith_manual_macos; exit 1
                fi
                maj=$(echo "$pyc" | cut -d. -f1); min=$(echo "$pyc" | cut -d. -f2)
                if ! { [ "$maj" -gt 3 ] || { [ "$maj" -eq 3 ] && [ "$min" -ge 10 ]; }; }; then
                    echo -e "${RED}Python still below 3.10.${NC}"; labsmith_manual_macos; exit 1
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
            if ! { [ "$maj" -gt 3 ] || { [ "$maj" -eq 3 ] && [ "$min" -ge 10 ]; }; }; then
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

labsmith_doc_type_from_key() {
    case "$1" in
        a|A) echo "admin" ;;
        c|C) echo "cli" ;;
        d|D) echo "datasheet" ;;
        r|R) echo "release-notes" ;;
        *) echo "" ;;
    esac
}

# ═══ Step 1 ═══
labsmith_step_welcome() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}${WHITE}                LabSmith v0.1.0                      ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}     ${DIM}Workshop Builder for Presales Engineers${NC}        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${DIM}Convert vendor PDFs into searchable reference material for workshop building.${NC}"
    echo ""
    echo "  This script walks you through prerequisites, PDF conversion, and"
    echo "  chunking your docs for module building in Cowork."
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

    pyver=$(labsmith_python_version_or_empty)
    if [ -n "$pyver" ]; then
        local maj min
        maj=$(echo "$pyver" | cut -d. -f1)
        min=$(echo "$pyver" | cut -d. -f2)
        if [ "$maj" -gt 3 ] || { [ "$maj" -eq 3 ] && [ "$min" -ge 10 ]; }; then
            py_disp=$(printf "  %-16s ${GREEN}${TP_PASS}${NC}  %s" "Python 3.10+" "$pyver")
        else
            py_disp=$(printf "  %-16s ${RED}${TP_FAIL}${NC}  need 3.10+ (have %s)" "Python 3.10+" "$pyver")
            needs_python=true
        fi
    else
        py_disp=$(printf "  %-16s ${RED}${TP_FAIL}${NC}  not found" "Python 3.10+")
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
    local abs_in
    abs_in=$(cd "$WATCH_DIR" && pwd 2>/dev/null || echo "$WATCH_DIR")
    clear
    echo ""
    echo -e "${BOLD}${WHITE}  ═══ Add Documents ═══${NC}"
    echo ""
    echo "  Drop your PDF files into this folder:"
    echo ""
    echo -e "    📂  ${CYAN}$abs_in${NC}"
    echo ""
    while true; do
        read -r -p "  When your files are in place, press Enter (or r to refresh list)... " action
        action=$(labsmith_str_lower "$(echo "$action" | tr -d '[:space:]')")
        if [ "$action" = "r" ]; then
            labsmith_print_pdf_list "$WATCH_DIR" || true
            continue
        fi
        if labsmith_print_pdf_list "$WATCH_DIR"; then
            break
        fi
        echo -e "  ${YELLOW}${TP_WARN}${NC} No PDFs found. Add files to the folder above, then press Enter."
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

    declare -a DOCTYPES
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
    echo -e "${BOLD}${WHITE}  ═══ Document Types ═══${NC}"
    echo ""
    echo "  What type is each file?"
    echo ""
    echo "    [a] Admin guide    [c] CLI reference"
    echo "    [d] Datasheet      [r] Release notes"
    echo ""

    local j=0
    while [ "$j" -lt "$nb" ]; do
        local b tkey dtype
        b="${BASENAMES[$j]}"
        echo -n "  $b  "
        read -r -p "type (a/c/d/r): " tkey
        tkey=$(labsmith_str_lower "$(echo "$tkey" | tr -d '[:space:]')")
        dtype=$(labsmith_doc_type_from_key "$tkey")
        while [ -z "$dtype" ]; do
            read -r -p "  Enter a, c, d, or r: " tkey
            tkey=$(labsmith_str_lower "$(echo "$tkey" | tr -d '[:space:]')")
            dtype=$(labsmith_doc_type_from_key "$tkey")
        done
        DOCTYPES[$j]="$dtype"
        if [ "$nb" -gt 1 ] && [ "$j" -eq 0 ]; then
            read -r -p "  Apply this type to all remaining files? (y/n) " ap
            ap=$(labsmith_str_lower "$(echo "$ap" | tr -d '[:space:]')")
            if [ "$ap" = "y" ] || [ "$ap" = "yes" ]; then
                local k=$((j + 1))
                while [ "$k" -lt "$nb" ]; do
                    DOCTYPES[$k]="$dtype"
                    k=$((k + 1))
                done
                break
            fi
        fi
        j=$((j + 1))
    done

    echo ""
    echo -e "  ${BOLD}Ready to process $nb file(s) for workshop \"${SELECTED_WORKSHOP}\"${NC}"
    echo ""
    read -r -p "  Press Enter to start, or q to quit: " go
    go=$(labsmith_str_lower "$(echo "$go" | tr -d '[:space:]')")
    if [ "$go" = "q" ]; then
        echo "Goodbye."
        exit 0
    fi

    mkdir -p "$LABSMITH_DIR/workshops/$SELECTED_WORKSHOP/references"

    local fi=0
    while [ "$fi" -lt "$nb" ]; do
        local base dtype base_noext outmd
        base="${BASENAMES[$fi]}"
        dtype="${DOCTYPES[$fi]}"
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
            echo -e "  ${CYAN}🔄 Chunking into SQLite...${NC}"
            local cout
            cout=$(python3 "$LABSMITH_DIR/chunker.py" "$outmd" --workshop "$SELECTED_WORKSHOP" --doc-type "$dtype" --db "$DB_PATH" 2>&1)
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
    echo -e "${CYAN}║${NC}  ${BOLD}${WHITE}            Processing Complete                     ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$DB_PATH" ]; then
        echo -e "  ${YELLOW}${TP_WARN}${NC} No database yet at labsmith.db"
        labsmith_pause
        return
    fi

    local stats
    stats=$(python3 "$LABSMITH_DIR/query.py" --db "$DB_PATH" stats --workshop "$SELECTED_WORKSHOP" 2>/dev/null) || stats=""
    echo -e "  ${BOLD}📊 Workshop:${NC} $SELECTED_WORKSHOP"
    echo ""
    if [ -n "$stats" ]; then
        echo "$stats" | sed 's/^/     /'
    fi

    echo ""
    echo -e "${BOLD}  ═══ What's Next ═══${NC}"
    echo ""
    echo "  1. Open Claude Desktop → start a Cowork session"
    echo "  2. Mount your LabSmith folder:"
    echo -e "     📂  ${CYAN}$LABSMITH_DIR${NC}"
    echo "  3. Ask Claude to build a module, e.g.:"
    echo ""
    echo "     \"Build a module on firewall policies for the $SELECTED_WORKSHOP workshop\""
    echo ""
    labsmith_pause
}

# ═══ main ═══
if [ ! -f "$LABSMITH_DIR/chunker.py" ] || [ ! -f "$LABSMITH_DIR/query.py" ] || [ ! -f "$MARKER_DIR/process-now.sh" ]; then
    echo -e "${RED}Run this script from the LabSmith repository root (chunker.py / query.py / marker/ missing).${NC}"
    exit 1
fi

labsmith_step_welcome
labsmith_step_prereqs
labsmith_step_workshop
labsmith_step_drop_files
labsmith_step_convert
labsmith_step_done

echo ""
echo -e "${GREEN}Done.${NC}"
echo ""

