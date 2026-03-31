# Task: Build an interactive terminal script for LabSmith

## Overview

Create `labsmith.sh` — a single interactive bash script that walks non-technical users through the entire LabSmith convert workflow without requiring them to know Terminal commands. It replaces the **manual** process of running `process-now.sh` and `chunker.py` yourself (with separate commands).

**Relationship to `setup.sh`:** Run **`bash setup.sh` once** to install prerequisites (Python, git, Marker venv, pymupdf4llm, smoke tests). Setup finishes by pointing you at **`labsmith.sh`**. Do **not** duplicate the 6-step flow inside setup — the numbered welcome → Cowork experience lives only in `labsmith.sh` (this document).

The script should feel visually polished — use color, box-drawing characters, emoji status indicators, and clear screen transitions between steps. Think of it as a TUI built with nothing but bash and ANSI escape codes.

## Design principles

- **Zero dependencies beyond bash** — no Python, no npm, no ncurses. Just bash 3.2+ (macOS default).
- **Sequential flow** — each step must complete before the next unlocks. No jumping around.
- **Non-destructive** — never delete user files. Moving PDFs from `to-process/` to `processed/` is the only file move (already handled by `process-now.sh`).
- **Interruptible** — Ctrl-C exits cleanly at any point.
- **Idempotent** — running it again after a partial run picks up where things left off (already converted files are skipped, existing workshops are listed).

## Visual style

Use ANSI colors and formatting throughout. Define these at the top:

```bash
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'  # reset
```

Use box-drawing characters for headers and section dividers:

```
╔══════════════════════════════════════════════════════╗
║                    LabSmith v0.1.0                    ║
║         Workshop Builder for Presales Engineers       ║
╚══════════════════════════════════════════════════════╝
```

Status indicators:
- `✅` — passed / complete
- `❌` — failed / missing
- `⚠️` — warning / needs attention
- `📄` — file listed
- `🔄` — in progress
- `📊` — stats

## Flow (6 steps)

### Step 1 — Welcome

Clear screen. Show the LabSmith banner (box-drawing art). Show a one-line description: "Convert vendor PDFs into searchable reference material for workshop building."

Brief instruction: "This script will walk you through checking prerequisites, processing your PDFs, and preparing your docs for module building in Cowork."

Press Enter to continue.

### Step 2 — Prerequisite Check

Run the same checks as `setup.sh` but with better visual output:

```
  Checking prerequisites...

  Python 3.9+      ✅  3.9
  git               ✅  2.50.1
  pymupdf4llm       ✅  installed
  Marker dirs       ✅  ready
```

If anything fails, show what's wrong and offer to install (same Homebrew/apt logic as `setup.sh`). The user can say yes to install, or the script explains what to do manually and exits.

If everything passes, pause briefly then move to Step 3.

**Important**: Reuse the exact detection logic from `setup.sh` — run `python3 -c "import sys; ..."` directly, don't use `command -v`. Run `git --version` directly. Check `brew --version` directly. All with `2>/dev/null` and fallbacks. This ensures stubs/shims that exit non-zero are correctly detected as missing.

### Step 3 — Workshop Selection

```
  ═══ Workshop ═══

  Existing workshops:
    1) cisco-to-fortinet (249 chunks, 3 doc types)
    2) acme-onboarding (0 chunks)

  [n] Create new workshop

  Select a workshop (1-2, or n):
```

List existing workshops by scanning `workshops/*/` directories. For each, show chunk count from `python3 query.py stats --workshop <name>` if the DB exists.

If user picks `n`, prompt for a new workshop name (lowercase, hyphens, no spaces). Create `workshops/<name>/modules/` and `workshops/<name>/references/` (Markdown copies land in `references/` after chunking).

Store the selected workshop name for later steps.

### Step 4 — File Drop

```
  ═══ Add Documents ═══

  Drop your PDF files into this folder:

    📂  /Users/you/Documents/labsmith/marker/to-process/

  When your files are in place, press Enter to continue...
```

Show the **full absolute on-disk path** to `marker/to-process/` (real `pwd`, so files land in the clone you are running from). If the repo lives under a path you normalize for Cowork (e.g. `.../Documents/CODING/...` vs `.../Documents/...`), you may show a one-line note with the “display” path. Wait for Enter.

After Enter, scan the directory and list what was found:

```
  Found 3 file(s):

    📄  FortiOS-Admin-Guide.pdf          (142 MB)
    📄  FortiOS-CLI-Reference.pdf        (38 MB)
    📄  FortiSwitch-Admin-Guide.pdf      (22 MB)

  Total: 3 PDFs, 202 MB
```

If no PDFs found, say so and offer **wait again** (Enter), **go back** to workshop selection (`w`), or **quit** (`q`).

### Step 5 — Doc Type & Convert

First offer the default: **`reference`** for all files (no per-file questions) unless the user opts in to classify.

```
  ═══ Document Types ═══

  Default doc type is reference (general material).
  Classify each file (a/c/d/r)? [y/N]
```

If **N** or Enter: use `reference` for every file and call `chunker.py` **without** `--doc-type` (default).

If **y**: for each PDF, ask the doc type:

```
  What type of document is each file?

    [a] Admin guide    [c] CLI reference
    [d] Datasheet      [r] Release notes
    [Enter]            reference

  FortiOS-Admin-Guide.pdf ............... type: a
```

If there's only one file, just ask once. If multiple files are the same type, offer "Apply to all? (y/n)".

Then confirm and start conversion:

```
  Ready to process 3 files for workshop "cisco-to-fortinet"

  Press Enter to start, or q to quit...
```

Trailing ellipsis on that line is optional; `q` must exit without starting conversion.

For each file:
1. Run `bash marker/process-now.sh <filename>` — show the progress output in real time (it already prints batch progress with percentage and ETA)
2. When Marker finishes, run `python3 chunker.py marker/output/<name>.md --workshop <workshop>` (optional: `--doc-type admin|cli|datasheet|release-notes`; default is `reference`)
3. Show chunk count after each file

Use a visual separator between files:

```
  ── Processing 1 of 3 ──────────────────────────────

  🔄 Converting: FortiOS-Admin-Guide.pdf
     PDF has 4672 pages
     [ 10.7%] 500/4672 pages — 52s elapsed, ~434s remaining
     [ 21.4%] 1000/4672 pages — 108s elapsed, ~396s remaining
     ...
     [100.0%] 4672/4672 pages — 1005s elapsed, ~0s remaining
  ✅ Converted: 6702 KB

  🔄 Chunking into SQLite...
  ✅ 249 chunks stored

  ── Processing 2 of 3 ──────────────────────────────
  ...
```

### Step 6 — Done

```
  ╔══════════════════════════════════════════════════════╗
  ║                   Processing Complete                 ║
  ╚══════════════════════════════════════════════════════╝

  📊 Workshop: cisco-to-fortinet

     Documents:  3
     Chunks:     487
     Total lines: 412,850

     By type:
       admin ......... 385 chunks
       cli ........... 102 chunks

  ═══ What's Next ═══

  1. Open Claude Desktop → start a Cowork session
  2. Mount your labsmith folder:
     📂  /Users/you/Documents/labsmith
  3. Tell Claude what module to build:

     "Build a module on firewall policies for the cisco-to-fortinet workshop"

  Other things you can ask:
     "What topics can I build from these docs?"
     "Build a module on VPN configuration"
     "What's in the reference database?"
```

## Files to reference (read these first)

- `setup.sh` — prerequisite detection and install logic. **Reuse the exact same detection patterns** (direct invocation with `2>/dev/null`, not `command -v`). The Homebrew install flow, apt flow, and all error messages should match.
- `marker/process-now.sh` — PDF conversion pipeline. Understand how it's called (`bash marker/process-now.sh` for all, `bash marker/process-now.sh filename.pdf` for one), what it outputs, and how progress reporting works.
- `chunker.py` — CLI: `python3 chunker.py <input.md> --workshop <name> [--doc-type TYPE] --db labsmith.db`. Default doc type is `reference`; optional types include `admin`, `cli`, `datasheet`, `release-notes`.
- `query.py` — CLI: `python3 query.py stats --workshop <name>` for chunk counts. `python3 query.py list --workshop <name>` for titles.
- `USER-GUIDE.md` — understand the full workflow and messaging.

## File to create

- `labsmith.sh` — the interactive script, in the repo root

## Technical notes

- All paths should be relative to the script's own location (use `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"`)
- The script runs from the repo root: `cd ~/Documents/labsmith && bash labsmith.sh`
- `labsmith.db` defaults to the repo root (same as chunker.py and query.py defaults)
- Marker venv Python is at `marker/venv/bin/python3` — process-now.sh finds it automatically
- process-now.sh moves processed PDFs from `marker/to-process/` to `marker/processed/` automatically
- Markdown output lands in `marker/output/` with the same base name as the PDF
- When running chunker after each file, the output filename is: `marker/output/<pdf-basename-without-extension>.md`

## Testing

Run from the repo root:
```bash
bash labsmith.sh
```

Test with no PDFs in `to-process/` — should handle gracefully.
Test with one PDF — should skip the "apply to all" prompt.
Test with an existing workshop that has chunks — should show stats.
Test Ctrl-C at various points — should exit cleanly.
