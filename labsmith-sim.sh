#!/bin/bash
# LabSmith — simulation / step test menu (bash 3.2+)
# Picks a single workflow step to run against your repo without walking 1→6.
#
# Usage: cd /path/to/labsmith && bash labsmith-sim.sh

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

LABSMITH_BOX_IW=54

labsmith_sim_center() {
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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LABSMITH_MAIN="$SCRIPT_DIR/labsmith.sh"

labsmith_sim_cleanup_int() {
    echo ""
    echo -e "${RED}Interrupted.${NC}"
    exit 130
}
trap labsmith_sim_cleanup_int INT

labsmith_sim_header() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${WHITE}$(labsmith_sim_center "LabSmith - simulation menu")${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${DIM}$(labsmith_sim_center "Run one step at a time for testing")${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

if [ ! -f "$LABSMITH_MAIN" ]; then
    echo -e "${RED}labsmith.sh not found next to this script.${NC}"
    exit 1
fi

while true; do
    labsmith_sim_header
    echo -e "  ${DIM}Convert / chunk steps use real tools (Marker, chunker), not mocks.${NC}"
    echo ""
    echo "  Pick a step:"
    echo ""
    echo -e "    ${CYAN}1${NC}  Welcome screen"
    echo -e "    ${CYAN}2${NC}  Prerequisites check (same as setup)"
    echo -e "    ${CYAN}3${NC}  Workshop selection / create"
    echo -e "    ${CYAN}4${NC}  File drop — list PDFs in marker/to-process/"
    echo -e "    ${CYAN}5${NC}  Convert + chunk (process-now.sh + chunker)"
    echo -e "    ${CYAN}6${NC}  Done — stats + what’s next"
    echo -e "    ${CYAN}7${NC}  ${BOLD}Full pipeline${NC} (same as bash labsmith.sh)"
    echo ""
    echo -e "    ${YELLOW}w${NC}  Set ${BOLD}LABSMITH_WORKSHOP${NC} for steps 5–6 (current: ${WHITE}${LABSMITH_WORKSHOP:-<unset>}${NC})"
    echo -e "    ${YELLOW}h${NC}  Show labsmith.sh --help"
    echo -e "    ${YELLOW}q${NC}  Quit"
    echo ""
    read -r -p "  Choice (1-7, w, h, q): " choice
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

    case "$choice" in
        1) bash "$LABSMITH_MAIN" --step welcome ;;
        2) bash "$LABSMITH_MAIN" --step prereqs ;;
        3) bash "$LABSMITH_MAIN" --step workshop ;;
        4) bash "$LABSMITH_MAIN" --step drop ;;
        5) bash "$LABSMITH_MAIN" --step convert ;;
        6) bash "$LABSMITH_MAIN" --step done ;;
        7) bash "$LABSMITH_MAIN" ;;
        w)
            echo ""
            read -r -p "  Workshop name (lowercase-hyphens, empty to clear): " LABSMITH_WORKSHOP
            LABSMITH_WORKSHOP=$(echo "$LABSMITH_WORKSHOP" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
            if [ -n "$LABSMITH_WORKSHOP" ]; then
                export LABSMITH_WORKSHOP
                echo -e "  ${GREEN}✅${NC} Will use workshop ${BOLD}$LABSMITH_WORKSHOP${NC} for steps 5–6."
            else
                unset LABSMITH_WORKSHOP
                echo -e "  ${DIM}Cleared — steps 5–6 will ask for a workshop.${NC}"
            fi
            read -r -p "  Press Enter... " _
            ;;
        h)
            bash "$LABSMITH_MAIN" --help
            read -r -p "Press Enter... " _
            ;;
        q|quit|exit)
            echo ""
            echo -e "${GREEN}Bye.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown choice.${NC}"
            sleep 1
            ;;
    esac
done
