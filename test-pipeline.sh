#!/bin/bash
# LabSmith v2 — Automated Pipeline Test
#
# Tests the full chain: Marker → Chunker → SQLite → Query
# Run from the labsmith repo root:
#   bash test-pipeline.sh [optional-pdf-path]
#
# If no PDF is provided, tests run against the example modules (skips Marker).

set -e

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

DB="test-labsmith.db"
WORKSHOP="test-workshop"
PASS=0
FAIL=0
SKIP=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}PASS${NC} — $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}FAIL${NC} — $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "  ${YELLOW}SKIP${NC} — $1"; SKIP=$((SKIP + 1)); }

echo "╔══════════════════════════════════════════════════════╗"
echo "║        LabSmith v2 — Pipeline Test Suite             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Clean up any previous test DB
rm -f "$DB"

# ─── Determine test input ───
PDF_PATH="$1"
ADMIN_MD=""
CLI_MD=""

if [ -n "$PDF_PATH" ] && [ -f "$PDF_PATH" ]; then
    echo "── Phase A0: Marker conversion ──"
    echo "  Input: $PDF_PATH"

    # Copy to marker inbox if not already there (cp errors if source == dest)
    PDF_BASENAME=$(basename "$PDF_PATH")
    SRC_ABS="$(cd "$(dirname "$PDF_PATH")" && pwd)/$PDF_BASENAME"
    DEST_ABS="$(cd marker/to-process && pwd)/$PDF_BASENAME"
    if [ "$SRC_ABS" != "$DEST_ABS" ]; then
        cp "$PDF_PATH" marker/to-process/
    else
        echo "  (PDF already in marker/to-process/, skipping copy)"
    fi

    # Run Marker on this PDF only (to-process/ may hold other PDFs)
    PDF_BASENAME_FOR_MARKER=$(basename "$PDF_PATH")
    BASENAME=$(basename "$PDF_PATH" .pdf)
    bash marker/process-now.sh "$PDF_BASENAME_FOR_MARKER" 2>&1 | tail -25
    marker_exit=${PIPESTATUS[0]}

    if [ -f "marker/output/${BASENAME}.md" ]; then
        LINES=$(wc -l < "marker/output/${BASENAME}.md")
        if [ "$LINES" -gt 10 ] && [ "$marker_exit" -eq 0 ]; then
            pass "A1: Marker produced ${LINES} lines"
            ADMIN_MD="marker/output/${BASENAME}.md"
        elif [ "$LINES" -le 10 ]; then
            fail "A1: Marker output only ${LINES} lines (expected >10)"
        else
            fail "A1: Marker exited ${marker_exit} — check ${BASENAME}.md (${LINES} lines)"
        fi
    else
        fail "A1: Marker output file not found (marker exit ${marker_exit})"
    fi
    echo ""
else
    echo "── No PDF provided — using example modules for testing ──"
    skip "A1: Marker conversion (no PDF provided)"

    # Use example modules as stand-ins
    if [ -f "examples/Module-01-FortiGate-Initial-Setup.md" ]; then
        ADMIN_MD="examples/Module-01-FortiGate-Initial-Setup.md"
    else
        echo "  ERROR: No example modules found. Cannot proceed."
        exit 1
    fi
    echo ""
fi

# CLI chunker expects `## **...**` headings (config / execute / diagnose). Lab modules use plain ## — use a small fixture.
if [ -f "test-fixtures/cli-reference-sample.md" ]; then
    CLI_MD="test-fixtures/cli-reference-sample.md"
elif [ -f "examples/Module-02-Interfaces-Zones-VLANs.md" ]; then
    CLI_MD="examples/Module-02-Interfaces-Zones-VLANs.md"
else
    CLI_MD="$ADMIN_MD"
fi

# ─── A2: Chunker — admin doc ───
echo "── Phase A: Chunker tests ──"

OUTPUT=$(python3 chunker.py "$ADMIN_MD" --workshop "$WORKSHOP" --doc-type admin --db "$DB" 2>&1)
if [ $? -eq 0 ]; then
    CHUNK_COUNT=$(echo "$OUTPUT" | grep -oi '[0-9]* chunk' | head -1 | grep -o '[0-9]*')
    if [ -n "$CHUNK_COUNT" ] && [ "$CHUNK_COUNT" -gt 0 ]; then
        pass "A2: Chunker (admin) inserted ${CHUNK_COUNT} chunks"
    else
        # Fallback: check DB directly
        CHUNK_COUNT=$(python3 -c "import sqlite3; c=sqlite3.connect('$DB'); r=c.execute('SELECT COUNT(*) FROM chunks WHERE workshop=\"$WORKSHOP\" AND doc_type=\"admin\"').fetchone()[0]; print(r)")
        if [ "$CHUNK_COUNT" -gt 0 ]; then
            pass "A2: Chunker (admin) inserted ${CHUNK_COUNT} chunks"
        else
            fail "A2: Chunker (admin) — 0 chunks inserted"
        fi
    fi
else
    fail "A2: Chunker (admin) exited with error"
    echo "  Output: $OUTPUT"
fi

# ─── A3: Chunker — CLI doc ───
OUTPUT=$(python3 chunker.py "$CLI_MD" --workshop "$WORKSHOP" --doc-type cli --db "$DB" 2>&1)
if [ $? -eq 0 ]; then
    CLI_COUNT=$(python3 -c "import sqlite3; c=sqlite3.connect('$DB'); r=c.execute('SELECT COUNT(*) FROM chunks WHERE workshop=\"$WORKSHOP\" AND doc_type=\"cli\"').fetchone()[0]; print(r)")
    if [ "$CLI_COUNT" -gt 0 ]; then
        pass "A3: Chunker (cli) inserted ${CLI_COUNT} chunks"
    else
        fail "A3: Chunker (cli) — 0 chunks inserted"
    fi
else
    fail "A3: Chunker (cli) exited with error"
fi

# ─── A4: Chunker — re-processing (idempotent) ───
BEFORE=$(python3 -c "import sqlite3; c=sqlite3.connect('$DB'); r=c.execute('SELECT COUNT(*) FROM chunks WHERE workshop=\"$WORKSHOP\" AND doc_type=\"admin\"').fetchone()[0]; print(r)")
python3 chunker.py "$ADMIN_MD" --workshop "$WORKSHOP" --doc-type admin --db "$DB" > /dev/null 2>&1
AFTER=$(python3 -c "import sqlite3; c=sqlite3.connect('$DB'); r=c.execute('SELECT COUNT(*) FROM chunks WHERE workshop=\"$WORKSHOP\" AND doc_type=\"admin\"').fetchone()[0]; print(r)")
if [ "$BEFORE" = "$AFTER" ]; then
    pass "A4: Re-processing is idempotent (${BEFORE} → ${AFTER})"
else
    fail "A4: Re-processing changed chunk count (${BEFORE} → ${AFTER})"
fi

# ─── A5: Chunker — bad doc-type rejected ───
set +e
OUTPUT=$(python3 chunker.py "$ADMIN_MD" --workshop "$WORKSHOP" --doc-type invalid --db "$DB" 2>&1)
py_exit=$?
set -e
if [ "$py_exit" -ne 0 ]; then
    pass "A5: Bad doc-type rejected with error"
else
    fail "A5: Bad doc-type was accepted (should have been rejected)"
fi

echo ""
echo "── Phase A: Query tests ──"

# ─── A6: Query — list ───
LIST_OUTPUT=$(python3 query.py --db "$DB" list --workshop "$WORKSHOP" 2>&1)
if [ $? -eq 0 ] && echo "$LIST_OUTPUT" | grep -qi "admin\|cli"; then
    LISTED=$(echo "$LIST_OUTPUT" | grep -c '[0-9]' || true)
    pass "A6: List returned results for $WORKSHOP"
else
    fail "A6: List returned no results or failed"
fi

# ─── A7: Query — search by title ───
# Get a section title to search for
FIRST_TITLE=$(python3 -c "import sqlite3; c=sqlite3.connect('$DB'); r=c.execute('SELECT section_title FROM chunks WHERE workshop=\"$WORKSHOP\" LIMIT 1').fetchone(); print(r[0] if r else '')")
if [ -n "$FIRST_TITLE" ]; then
    # Use first word of the title as search term
    SEARCH_TERM=$(echo "$FIRST_TITLE" | awk '{print $1}')
    SEARCH_OUTPUT=$(python3 query.py --db "$DB" search "$SEARCH_TERM" --workshop "$WORKSHOP" 2>&1)
    if [ $? -eq 0 ] && echo "$SEARCH_OUTPUT" | grep -qi "$SEARCH_TERM"; then
        pass "A7: Search by title for '${SEARCH_TERM}' found results"
    else
        fail "A7: Search by title for '${SEARCH_TERM}' returned nothing"
    fi
else
    skip "A7: No section titles to search"
fi

# ─── A8: Query — search by content ───
# Grab a word from chunk content that might not be in the title
CONTENT_WORD=$(python3 -c "
import sqlite3
c=sqlite3.connect('$DB')
r=c.execute('SELECT content FROM chunks WHERE workshop=\"$WORKSHOP\" LIMIT 1').fetchone()
if r:
    words = [w for w in r[0].split() if len(w) > 6 and w.isalpha()]
    print(words[0] if words else '')
else:
    print('')
")
if [ -n "$CONTENT_WORD" ]; then
    SEARCH_OUTPUT=$(python3 query.py --db "$DB" search "$CONTENT_WORD" 2>&1)
    if [ $? -eq 0 ] && [ -n "$SEARCH_OUTPUT" ]; then
        pass "A8: Search by content for '${CONTENT_WORD}' found results"
    else
        fail "A8: Search by content for '${CONTENT_WORD}' returned nothing"
    fi
else
    skip "A8: No content words to search"
fi

# ─── A9: Query — get by ID ───
FIRST_ID=$(python3 -c "import sqlite3; c=sqlite3.connect('$DB'); r=c.execute('SELECT id FROM chunks WHERE workshop=\"$WORKSHOP\" LIMIT 1').fetchone(); print(r[0] if r else '')")
if [ -n "$FIRST_ID" ]; then
    GET_OUTPUT=$(python3 query.py --db "$DB" get "$FIRST_ID" 2>&1)
    if [ $? -eq 0 ] && [ ${#GET_OUTPUT} -gt 50 ]; then
        pass "A9: Get by ID ${FIRST_ID} returned content (${#GET_OUTPUT} chars)"
    else
        fail "A9: Get by ID ${FIRST_ID} returned empty or short content"
    fi
else
    skip "A9: No chunk IDs to get"
fi

# ─── A10: Query — get multiple IDs ───
TWO_IDS=$(python3 -c "import sqlite3; c=sqlite3.connect('$DB'); rows=c.execute('SELECT id FROM chunks WHERE workshop=\"$WORKSHOP\" LIMIT 2').fetchall(); print(' '.join(str(r[0]) for r in rows))")
if [ -n "$TWO_IDS" ]; then
    GET_OUTPUT=$(python3 query.py --db "$DB" get $TWO_IDS 2>&1)
    if [ $? -eq 0 ] && [ ${#GET_OUTPUT} -gt 100 ]; then
        pass "A10: Get multiple IDs (${TWO_IDS}) returned content"
    else
        fail "A10: Get multiple IDs returned empty or short content"
    fi
else
    skip "A10: Not enough chunk IDs"
fi

# ─── A11: Query — stats ───
STATS_OUTPUT=$(python3 query.py --db "$DB" stats --workshop "$WORKSHOP" 2>&1)
if [ $? -eq 0 ] && echo "$STATS_OUTPUT" | grep -qi "chunk\|total\|admin\|cli"; then
    pass "A11: Stats returned meaningful output"
else
    fail "A11: Stats returned nothing useful"
fi

# ─── A12: Query — cross-workshop (no filter) ───
LIST_ALL=$(python3 query.py --db "$DB" list 2>&1)
if [ $? -eq 0 ] && echo "$LIST_ALL" | grep -qi "$WORKSHOP"; then
    pass "A12: List without --workshop shows test-workshop chunks"
else
    fail "A12: List without --workshop didn't show test-workshop"
fi

# ─── A13: Query — max 50 results ───
SEARCH_A=$(python3 query.py --db "$DB" search "a" 2>&1)
RESULT_COUNT=$(echo "$SEARCH_A" | grep -c '[0-9]' || true)
if [ "$RESULT_COUNT" -le 52 ]; then  # 50 results + possible header lines
    pass "A13: Search result cap enforced (${RESULT_COUNT} lines)"
else
    fail "A13: Search returned ${RESULT_COUNT} lines (expected ≤50 results)"
fi

# ─── Cleanup ───
echo ""
echo "── Cleanup ──"
rm -f "$DB"
echo "  Removed test DB"

# ─── Summary ───
TOTAL=$((PASS + FAIL + SKIP))
echo ""
echo "════════════════════════════════════════════════════════"
echo -e "  ${GREEN}PASS: ${PASS}${NC}  |  ${RED}FAIL: ${FAIL}${NC}  |  ${YELLOW}SKIP: ${SKIP}${NC}  |  TOTAL: ${TOTAL}"
echo "════════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
