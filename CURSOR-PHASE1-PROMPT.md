# LabSmith v2 — Phase 1 Cursor Prompt

## Context

You are building the foundation for LabSmith v2 — a Cowork plugin that helps presales engineers build hands-on training workshops from vendor documentation. Read `PROJECT.md` in this directory for the full project definition, decisions, and architecture.

The core flow is: PDFs → Marker (converts to markdown) → chunker (splits by heading, stores in SQLite) → Claude queries SQLite for relevant chunks → writes lab modules.

**This session focuses on Phase 1: fresh repo setup, chunker.py, query.py, and SQLite schema.**

## Step 1 — Create the fresh repo

Create a new repo at `~/Documents/CODING/labsmith-v2/` with this structure:

```
labsmith-v2/
  marker/
    process-now.sh       ← copy from ~/Documents/Claude/Projects/LabSmith/marker/process-now.sh
    to-process/          ← empty dir (gitkeep)
    output/              ← empty dir (gitkeep)
    processed/           ← empty dir (gitkeep)
  workshops/
    cisco-to-fortinet/
      references/        ← empty dir (gitkeep)
      modules/           ← empty dir (gitkeep)
  examples/
    Module-00-PreLab.md  ← copy from ~/Documents/Claude/Projects/LabSmith/marker-scripts/skills/output-examples/
    Module-01-FortiGate-Initial-Setup.md
    Module-02-Interfaces-Zones-VLANs.md
  chunker.py
  query.py
  labsmith.db            ← created by chunker.py on first run
  PROJECT.md             ← copy from ~/Documents/Claude/Projects/LabSmith/PROJECT.md
  .gitignore
  README.md
```

`.gitignore` should include: `labsmith.db`, `marker/to-process/`, `marker/processed/`, `*.pyc`, `__pycache__/`, `.DS_Store`, `venv/`

Init git repo. First commit: "Initial repo structure for LabSmith v2"

## Step 2 — Build chunker.py

This script takes Marker's markdown output and stores it in SQLite, chunked by heading.

**IMPORTANT: Reference these existing scripts in the old repo before writing anything.** They contain proven logic for heading-based splitting and artifact cleanup that should be reused:

- `~/Documents/Claude/Projects/LabSmith/marker-scripts/clean-and-split.py` — Cleans pymupdf4llm artifacts (mangled TOC tables, excessive blank lines). Finds chapter headings from TOC bold entries. Splits admin guides by `## **ChapterName**` pattern. Already handles edge cases like skipping front matter, min-line thresholds, and manifest generation.

- `~/Documents/Claude/Projects/LabSmith/marker-scripts/extract-references.py` — Splits CLI references by config block grouping (firewall, system, vpn as categories, with sub-blocks staying inside their parent). Groups diagnose/execute commands by first sub-word. Has two modes: general (h1/h2 heading split) and CLI-specific (config block split).

**The task:** Merge the splitting logic from both scripts into a single `chunker.py` that writes to SQLite instead of individual .md files.

### SQLite schema

```sql
CREATE TABLE IF NOT EXISTS chunks (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    workshop      TEXT NOT NULL,
    source_doc    TEXT NOT NULL,
    doc_type      TEXT NOT NULL,
    section_title TEXT NOT NULL,
    content       TEXT NOT NULL,
    line_count    INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_workshop ON chunks(workshop);
CREATE INDEX IF NOT EXISTS idx_doc_type ON chunks(doc_type);
CREATE INDEX IF NOT EXISTS idx_section_title ON chunks(section_title);
```

### Usage

```bash
# General docs (admin guides, datasheets, release notes)
python3 chunker.py <input.md> --workshop cisco-to-fortinet --doc-type admin --db labsmith.db

# CLI references (uses config-block-aware splitting)
python3 chunker.py <input.md> --workshop cisco-to-fortinet --doc-type cli --db labsmith.db
```

### Behavior

- `--doc-type cli` triggers the config-block-aware splitting from `extract-references.py`
- All other doc types use the general heading-based splitting from `clean-and-split.py`
- Always run `clean_markdown()` artifact cleanup before splitting (from `clean-and-split.py`)
- `source_doc` = the input filename (without path)
- Before inserting, delete any existing chunks with the same `source_doc` + `workshop` combo (allows re-processing)
- Print a summary: chunks inserted, total lines, average chunk size
- No external dependencies beyond Python stdlib + sqlite3 (both built in)

## Step 3 — Build query.py

Search and retrieve functions that Claude can call from a Cowork session via bash.

### Usage

```bash
# Search by keyword in section titles
python3 query.py search "VLAN" --workshop cisco-to-fortinet --db labsmith.db

# Search by doc type
python3 query.py search "firewall policy" --doc-type cli --db labsmith.db

# List all chunks for a workshop (summary view — no content, just titles and line counts)
python3 query.py list --workshop cisco-to-fortinet --db labsmith.db

# Get a specific chunk by ID (full content)
python3 query.py get 42 --db labsmith.db

# Get multiple chunks by ID
python3 query.py get 42 43 44 --db labsmith.db

# Stats: chunk count, total lines, breakdown by doc_type
python3 query.py stats --workshop cisco-to-fortinet --db labsmith.db
```

### Search behavior

- `search` does a case-insensitive LIKE match on `section_title` AND `content`
- Returns: id, section_title, source_doc, doc_type, line_count (no content — keep output small)
- `get` returns full content for specific chunk IDs
- Default `--db` is `labsmith.db` in the current directory

This two-step pattern (search to find relevant IDs → get to load content) is intentional — it lets Claude decide which chunks are actually relevant before loading them into context.

## Step 4 — Verify

- Run chunker.py against one of the example module .md files to confirm it parses and stores correctly
- Run query.py search and get commands to confirm retrieval works
- Confirm the DB is created, indexed, and queryable

## What NOT to do

- Do not build the Cowork plugin or skills — that's Phase 2 and happens in Cowork
- Do not add web frameworks, APIs, or servers
- Do not add embedding/vector search — plain SQLite LIKE search is fine for now
- Do not install external Python packages — stdlib + sqlite3 only
- Do not modify anything in the old repo (`~/Documents/Claude/Projects/LabSmith/`)
