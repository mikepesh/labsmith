---
name: convert
description: >
  Convert vendor PDFs into searchable reference chunks stored in SQLite for
  workshop authoring. ALWAYS use this skill when the user mentions converting
  docs, processing PDFs, adding reference material, ingesting documentation,
  loading datasheets, importing admin guides, or wants to prepare any vendor
  documentation for module generation — even if they don't say "convert"
  explicitly. Also trigger when the user drops PDF files, asks about the
  marker pipeline, or says things like "I have some new PDFs", "add these
  docs to the workshop", "process my datasheets", or "get these ready for
  module building". NOTE: The convert pipeline runs from Terminal, not inside
  Cowork — SQLite writes require direct filesystem access. Guide the user
  through Terminal commands.
---

# LabSmith — Convert Docs

This skill converts vendor documentation (PDFs) into markdown, chunks it by heading, and stores it in SQLite so the build-module skill can query only what it needs.

> **Important:** The convert pipeline (Marker + chunker) must run from **Terminal** or **Cursor**, not from inside a Cowork session. SQLite cannot write to Cowork-mounted directories. Guide the user through the Terminal commands below.

## Cowork runtime (read-only plugin)

The **plugin directory is extracted read-only**. Do not create, edit, or save files under the plugin tree. All `chunker.py`, `query.py`, `marker/`, `workshops/`, `labsmith.db`, and PDF/markdown paths refer to the user’s **mounted LabSmith workspace**, never to paths inside the plugin package.

## Resolve the LabSmith workspace **first**

Before running any Marker or chunker commands, find a directory that contains **all** of: `chunker.py`, `query.py`, and `marker/process-now.sh`. That directory is **LABSMITH_ROOT** (the full LabSmith repo on disk).

Cowork mounts the user’s project under session mounts, typically:

`/sessions/<session-id>/mnt/<folder-name>/`

Discover candidates (non-destructive checks only):

```bash
for d in /sessions/*/mnt/*/; do
  [ -f "${d}chunker.py" ] && [ -f "${d}query.py" ] && [ -f "${d}marker/process-now.sh" ] && echo "${d}"
done
```

- **Zero results:** Stop and ask the user to **mount their LabSmith repo** in Cowork (the folder that contains `chunker.py` and `marker/`), then re-run the check.
- **One result:** Use it as `LABSMITH_ROOT` (normalize: `LABSMITH_ROOT="${path%/}"` if needed).
- **Multiple results:** Prefer a mount whose folder name is `labsmith` if present; otherwise list the paths and ask which workspace to use.

Set the shell working directory to **LABSMITH_ROOT** for every command below:

```bash
cd "$LABSMITH_ROOT" || exit 1
pwd
```

Do not assume a path like `~/Documents/CODING/labsmith` unless it appears in the mount listing.

## What happens

Two steps under the hood:

1. **Marker** converts PDF → clean markdown (`marker/process-now.sh` using `pymupdf4llm`)
2. **Chunker** splits markdown by heading → stores chunks in SQLite with metadata

The user just drops PDFs and says "convert these." One action, two things happen.

## Prerequisites

- Python 3 with `pymupdf4llm` installed (Marker dependency)
- Marker venv at `marker/venv/` **or** `pymupdf4llm` importable on the default `python3`

(all relative to **LABSMITH_ROOT**)

## Workflow

### Step 1 — Determine workshop name

Ask the user which workshop these docs belong to. If only one workshop exists under `workshops/`, use it. If none exist yet, ask what to name it.

From **LABSMITH_ROOT**:

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

Put PDFs in `marker/to-process/` under **LABSMITH_ROOT** (unless you pass a full path to a PDF). Then:

```bash
cd "$LABSMITH_ROOT"
bash marker/process-now.sh
```

Process a single file by name **after** it sits in `marker/to-process/`:

```bash
bash marker/process-now.sh filename.pdf
```

Or pass a **full path** to a PDF (the script accepts that). Markdown output lands in `marker/output/`; originals move to `marker/processed/`.

### Step 4 — Run Chunker

For each converted markdown file:

```bash
cd "$LABSMITH_ROOT"
python3 chunker.py "marker/output/<filename>.md" --workshop <workshop-name> --doc-type <type> --db labsmith.db
```

Use `--doc-type cli` for CLI references; otherwise `admin`, `datasheet`, or `release-notes` as appropriate.

### Step 5 — Copy markdown to workshop references

```bash
cd "$LABSMITH_ROOT"
cp "marker/output/<filename>.md" "workshops/<workshop-name>/references/"
```

### Step 6 — Confirm

Show the user:

- Number of chunks stored
- Total lines processed
- Breakdown by chunk (summary) via `query.py list`:

```bash
cd "$LABSMITH_ROOT"
python3 query.py --db labsmith.db list --workshop <workshop-name>
```

(`--db` must come before the subcommand `list`, `search`, `get`, or `stats`.)

## Error handling

| Situation | Action |
|-----------|--------|
| LabSmith workspace not mounted / discover finds 0 roots | Ask the user to mount the LabSmith repo in Cowork, then re-run discovery |
| Marker not installed / venv missing | From **LABSMITH_ROOT**: `cd marker && python3 -m venv venv && venv/bin/pip install pymupdf4llm` (or install globally) |
| PDF conversion fails | Report the error, suggest checking if the PDF is corrupted or password-protected |
| Chunker finds 0 sections | Warn user — the markdown may lack heading structure. Offer to store as a single chunk or improve headings in the source |
| Workshop directory doesn't exist | From **LABSMITH_ROOT**: `mkdir -p workshops/<name>/{references,modules}` |
