# LabSmith v2 — Test Plan

## Overview

This plan validates the full LabSmith pipeline end-to-end: PDF → Marker → Chunker → SQLite → Query → Build Module. Tests are split into automated (script-verifiable) and manual (requires human judgment).

## Test material

You need **two real PDFs** from your existing collection:

| File | Type | Why |
|------|------|-----|
| One admin guide chapter (or short admin guide) | `admin` | Tests general heading-based chunking |
| One CLI reference section | `cli` | Tests config-block-aware chunking |

If you don't have a short PDF handy, any Fortinet datasheet or release notes PDF works — just use the appropriate `--doc-type`.

Place them in: `~/Documents/CODING/labsmith/marker/to-process/`

---

## Phase A — Pipeline tests (automated)

These are run by `test-pipeline.sh` (see below). They validate that each tool works correctly in isolation and together.

### A1. Marker conversion
- Input: PDF in `marker/to-process/`
- Expected: `.md` file in `marker/output/` with content > 10 lines
- Validates: pymupdf4llm is installed, process-now.sh works, output is non-empty

### A2. Chunker — admin doc
- Input: Marker output `.md` file
- Flags: `--workshop test-workshop --doc-type admin`
- Expected: chunks inserted > 0, SQLite DB created, summary printed
- Validates: clean_markdown runs, heading-based splitting works, SQLite writes succeed

### A3. Chunker — CLI doc
- Input: Marker output `.md` file (or use an example module as a stand-in)
- Flags: `--workshop test-workshop --doc-type cli`
- Expected: chunks inserted > 0
- Validates: config-block-aware splitting path works

### A4. Chunker — re-processing (idempotent)
- Input: Same file as A2, same flags
- Expected: chunk count stays the same (old chunks deleted, new ones inserted)
- Validates: `DELETE WHERE source_doc + workshop` logic works

### A5. Chunker — bad doc-type rejected
- Input: Any `.md` file
- Flags: `--workshop test-workshop --doc-type invalid`
- Expected: non-zero exit code, error message about valid doc types
- Validates: doc-type validation

### A6. Query — list
- Command: `python3 query.py list --workshop test-workshop`
- Expected: table output showing chunk IDs, section titles, doc types, line counts
- Validates: list command works, all chunks from A2/A3 are visible

### A7. Query — search by title
- Command: `python3 query.py search "<keyword from a known section title>" --workshop test-workshop`
- Expected: at least 1 result with matching section_title
- Validates: case-insensitive LIKE on section_title works

### A8. Query — search by content
- Command: `python3 query.py search "<word that only appears in chunk content, not title>"`
- Expected: at least 1 result
- Validates: LIKE match on content field works

### A9. Query — get by ID
- Command: `python3 query.py get <id from A7>`
- Expected: full chunk content printed, includes markdown with headings
- Validates: get retrieval works, content is intact

### A10. Query — get multiple IDs
- Command: `python3 query.py get <id1> <id2>`
- Expected: both chunks printed, separated clearly
- Validates: multi-ID get works

### A11. Query — stats
- Command: `python3 query.py stats --workshop test-workshop`
- Expected: total chunk count, total lines, breakdown by doc_type
- Validates: stats aggregation works

### A12. Query — cross-workshop (no --workshop flag)
- Command: `python3 query.py list`
- Expected: lists chunks from all workshops (test-workshop should appear)
- Validates: optional workshop filter works

### A13. Query — max 50 results
- Command: `python3 query.py search "a" --workshop test-workshop`
- Expected: at most 50 results (letter "a" should match many chunks)
- Validates: result cap is enforced

---

## Phase B — Integration test (automated)

### B1. Full pipeline in one shot
- Drop PDF → Marker → Chunker → Query search → Query get
- Validates the entire chain without manual intervention
- This is what `test-pipeline.sh` runs end-to-end

---

## Phase C — Skill tests (manual, in Cowork)

These test the actual plugin skills in a Cowork session. Run these after the plugin is installed.

### C1. Convert skill — happy path
1. Drop a PDF into the LabSmith folder
2. Say "convert this for the cisco-to-fortinet workshop, it's an admin guide"
3. Verify: Claude runs Marker, runs chunker, shows chunk summary
4. Check: `python3 query.py list --workshop cisco-to-fortinet` shows the new chunks

### C2. Convert skill — missing Marker
1. Temporarily rename `marker/venv/` (if it exists)
2. Try to convert
3. Verify: Claude gives clear install instructions, doesn't crash

### C3. Build module skill — happy path
1. After C1 (chunks exist in SQLite)
2. Say "build a module on [topic covered by your chunks]"
3. Verify: Claude queries SQLite (you should see query.py commands), writes a module
4. Check: module file exists in `workshops/cisco-to-fortinet/modules/`
5. Check: module follows the format in `module-format.md` (300+ lines, all sections present)

### C4. Build module skill — no reference material
1. Say "build a module on quantum computing" (topic with no chunks)
2. Verify: Claude warns about missing reference material, offers to proceed with VERIFY comments

### C5. Token efficiency check
1. After C3, note how many chunks Claude loaded (count the `query.py get` calls)
2. Compare: total tokens in loaded chunks vs. total tokens in the full source document
3. Target: loaded chunks should be <30% of full document size

---

## Phase D — Quality validation (manual)

### D1. Module quality comparison
1. Compare a generated module against the examples in `examples/`
2. Check: same section structure, similar depth, CLI commands grounded in reference docs
3. Check: VERIFY comments present where reference material was thin

### D2. Chunk quality spot-check
1. Run `python3 query.py get <random-id>` on 5 random chunks
2. Check: each chunk has a meaningful section title, content is clean (no TOC artifacts, no mangled tables), and content relates to the title

---

## Cleanup

After testing, remove test data:

```bash
# Delete test workshop chunks from SQLite
python3 -c "import sqlite3; c=sqlite3.connect('labsmith.db'); c.execute('DELETE FROM chunks WHERE workshop=\"test-workshop\"'); c.commit(); print(f'Deleted {c.total_changes} chunks')"

# Or delete the entire test DB
rm labsmith.db
```
