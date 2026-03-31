---
name: convert
description: >
  Convert vendor PDFs into searchable reference chunks stored in SQLite.
  Use when the user says "convert", "process these PDFs", "add docs",
  "ingest these docs", or drops PDF files for workshop reference material.
---

# LabSmith — Convert Docs

This skill converts vendor documentation (PDFs) into markdown, chunks it by heading, and stores it in SQLite so the build-module skill can query only what it needs.

## Repository root

All commands below assume the **LabSmith repository root**: the directory that contains `chunker.py`, `query.py`, `marker/`, `workshops/`, and `plugin/`. `cd` there first (or set your shell working directory to that folder in Cowork).

## What happens

Two steps under the hood:

1. **Marker** converts PDF → clean markdown (`marker/process-now.sh` using `pymupdf4llm`)
2. **Chunker** splits markdown by heading → stores chunks in SQLite with metadata

The user just drops PDFs and says "convert these." One action, two things happen.

## Prerequisites

- Python 3 with `pymupdf4llm` installed (Marker dependency)
- Marker venv at `marker/venv/` **or** `pymupdf4llm` importable on the default `python3`

## Workflow

### Step 1 — Determine workshop name

Ask the user which workshop these docs belong to. If only one workshop exists under `workshops/`, use it. If none exist yet, ask what to name it.

Check existing workshops:

```bash
ls workshops/
```

### Step 2 — Determine doc type

Ask the user what type of document(s) they're converting. Valid types:

| Type | Use for |
|------|---------|
| `admin` | Administration guides, user guides |
| `cli` | CLI references, command references |
| `datasheet` | Product datasheets, spec sheets |
| `release-notes` | Release notes, what's new docs |

If ambiguous, ask. If the user drops multiple doc types, process each with the correct type.

### Step 3 — Run Marker

Put PDFs in `marker/to-process/` (unless you pass a full path to a PDF). Then from the repository root:

```bash
bash marker/process-now.sh
```

Process a single file by name **after** it sits in `marker/to-process/`:

```bash
bash marker/process-now.sh filename.pdf
```

Or pass a **full path** to a PDF anywhere on disk (the script accepts that). Markdown output lands in `marker/output/`; originals move to `marker/processed/`.

### Step 4 — Run Chunker

For each converted markdown file, from the repository root:

```bash
python3 chunker.py marker/output/<filename>.md --workshop <workshop-name> --doc-type <type> --db labsmith.db
```

Use `--doc-type cli` for CLI references; otherwise `admin`, `datasheet`, or `release-notes` as appropriate.

### Step 5 — Copy markdown to workshop references

```bash
cp marker/output/<filename>.md workshops/<workshop-name>/references/
```

### Step 6 — Confirm

Show the user:

- Number of chunks stored
- Total lines processed
- Breakdown by chunk (summary) via `query.py list`:

```bash
python3 query.py list --workshop <workshop-name> --db labsmith.db
```

## Error handling

| Situation | Action |
|-----------|--------|
| Marker not installed / venv missing | Tell user: `cd marker && python3 -m venv venv && marker/venv/bin/pip install pymupdf4llm` (or install `pymupdf4llm` globally) |
| PDF conversion fails | Report the error, suggest checking if the PDF is corrupted or password-protected |
| Chunker finds 0 sections | Warn user — the markdown may lack heading structure. Offer to store as a single chunk or improve headings in the source |
| Workshop directory doesn't exist | Create it: `mkdir -p workshops/<name>/{references,modules}` |
