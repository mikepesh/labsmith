# LabSmith — Project definition

## What it is

LabSmith is a Cowork plugin that helps presales engineers build hands-on training workshops from vendor documentation.

You drop in PDFs — datasheets, admin guides, release notes — and LabSmith helps you turn them into structured, ready-to-deliver lab modules with topology references, command tables, and exercises your audience can follow.

## Who it's for

Any presales engineer who needs to build a workshop. If you have docs and a concept for a lab, LabSmith gets you from zero to deliverable.

## How it works

Three steps. That's it.

1. **Convert** — Drop PDFs into Marker. It converts them to clean markdown, chunks it by heading, and stores it in SQLite. One action from the user — two things happen under the hood.
2. **Build** — Tell Claude what you want. It queries SQLite for just the relevant reference chunks and generates a structured lab module (`.md` file). Lean context, focused output.
3. **Deliver** — Each lab is its own `.md` file. When you want a polished handout, Claude compiles them into a docx or PDF on demand.

Claude is the intelligence layer. Marker handles PDF conversion. SQLite keeps token usage tight. The plugin wires them together.

## What it is NOT

- Not a web app
- Not a CLI tool with subcommands and flags
- Not a pipeline with orchestration, subprocess management, or queue systems
- Not an AI wrapper that needs its own inference backend

If it can't be explained in the three steps above, it doesn't belong.

## What stays from v1

| Keep                     | Why                                                                                      |
| ------------------------ | ---------------------------------------------------------------------------------------- |
| Marker (PDF → markdown)  | Solves the token cost problem. Works.                                                    |
| Module markdown format   | The structure (Objectives → Overview → Commands → Exercise → Instructor Notes) is proven |

## What's gone

| Drop                                               | Why                                                                             |
| -------------------------------------------------- | ------------------------------------------------------------------------------- |
| Compiler (`compile.py`)                            | Claude can assemble a workshop doc directly — no need for a separate build step |
| Planner orchestration                              | Claude *is* the planner now                                                     |
| Scripts (`generate-module.py`, `plan-workshop.py`) | Replaced by Cowork plugin skills                                                |
| Frontend plans (Node/React/Fastify)                | There is no frontend. Cowork is the interface.                                  |
| GSD workflow enforcement                           | Overhead from a different era                                                   |
| Ollama / local inference                           | Not needed when Claude is the runtime                                           |
| Hardware profiles (YAML)                           | Converted docs ARE the reference. No curated abstraction layer needed.          |
| Workshop configs (YAML)                            | Workshop structure is defined conversationally, not in config files              |

## Principles

1. **Simplicity is the feature.** Every addition must justify itself against "does this make the three-step workflow better?"
2. **Right tool for the job.** Planning and content authoring happen in Cowork. Coding happens in Cursor. Don't blur the lines.
3. **Token efficiency matters.** Markdown in, structured output out. Never feed raw PDFs to Claude when converted markdown exists.
4. **Ship for one, then generalize.** Get it working perfectly for one workshop track before abstracting.

## Repo plan

**This repo** is `~/Documents/CODING/labsmith/`. The earlier Streamlit codebase was moved to `~/Documents/CODING/labsmith-streamlit/`. The legacy tree at `~/Documents/Claude/Projects/LabSmith/` stays untouched as a reference where useful. Cowork can still read from the old repo; day-to-day Cursor work happens here.

Copy over only:
- `marker/` — PDF conversion tooling (process-now.sh + pymupdf4llm pipeline)
- `marker-scripts/clean-and-split.py` — heading-based splitting + artifact cleanup (refactor target for chunker.py)
- `marker-scripts/extract-references.py` — CLI reference splitting logic (refactor target for chunker.py)
- `marker-scripts/skills/output-examples/` — example module output (Module-00, 01, 02) for quality reference
- Plugin definition and skills

Everything else starts clean. No profiles, no compiler, no configs, no scripts directory.

## Workshop directory structure

Each workshop gets its own directory. Converted docs and modules live together:

```
workshops/
  cisco-to-fortinet/
    references/          ← Marker output (flat markdown files)
    modules/             ← Generated lab modules (.md each)

labsmith.db              ← Shared SQLite reference store (all workshops)
```

One shared DB across all workshops. Users will likely build multiple workshops and reference material often overlaps across them. A `workshop` column tags which workshop(s) a chunk belongs to.

## Plugin structure (MVP)

Two skills:

1. **convert** — Takes PDFs, runs Marker, chunks markdown by heading, stores in SQLite. User drops files and says "convert these."
2. **build-module** — User describes what they want. Claude queries SQLite for relevant chunks, writes a `.md` module file. Each module is self-contained.

Delivery (compiling modules into a polished docx/PDF) is handled ad hoc by Claude — not a dedicated skill.

## Roadmap

### Phase 1 — Foundation (Cursor tasks)
- Set up fresh repo
- Build `chunker.py` — splits Marker markdown by heading, stores in SQLite with metadata (source doc, section title, doc type)
- Build `query.py` — search/retrieve functions Claude calls to pull relevant chunks
- SQLite schema design

### Phase 2 — Plugin (Cowork tasks)
- Write convert skill (wires Marker + chunker together)
- Write build-module skill (wires query + module authoring together)
- Plugin packaging and definition

### Phase 3 — Validate
- End-to-end test with one workshop track (cisco-to-fortinet)
- Measure token usage vs. old approach
- Iterate on chunking quality and query relevance

## Decisions log

| Decision | Date | Rationale |
|----------|------|-----------|
| Drop hardware profiles | 2026-03-30 | Converted docs are the reference. Profiles limited LabSmith to hardware-centric workshops. |
| SQLite is foundational, not optional | 2026-03-30 | Token efficiency is the core value prop. Build around it from day one. |
| Shared DB, not per-workshop | 2026-03-30 | Reference material overlaps across workshops. One DB, workshop column. |
| Two skills MVP (convert + build-module) | 2026-03-30 | Delivery is ad hoc. Keep the plugin dead simple. |
| Fresh repo | 2026-03-30 | Too much dead code. Copy over only Marker, modules (as examples), and plugin. |
| Separate directories | 2026-03-30 | Old repo stays as reference. Cursor project canonical path: ~/Documents/CODING/labsmith/. |

## SQLite schema

```sql
CREATE TABLE chunks (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    workshop      TEXT NOT NULL,       -- e.g. "cisco-to-fortinet"
    source_doc    TEXT NOT NULL,       -- original PDF filename
    doc_type      TEXT NOT NULL,       -- "admin", "cli", "datasheet", "release-notes"
    section_title TEXT NOT NULL,       -- heading text
    content       TEXT NOT NULL,       -- markdown chunk
    line_count    INTEGER NOT NULL     -- quick size gauge
);

CREATE INDEX idx_workshop ON chunks(workshop);
CREATE INDEX idx_doc_type ON chunks(doc_type);
CREATE INDEX idx_section_title ON chunks(section_title);
```

## Existing scripts (reference for Cursor)

These live in the OLD repo at `~/Documents/Claude/Projects/LabSmith/marker-scripts/`:

| Script | What it does | Reuse in this repo |
|--------|-------------|-------------|
| `clean-and-split.py` | Cleans pymupdf4llm artifacts (TOC tables, blank lines), finds chapter headings in TOC, splits admin guides by chapter | Core logic becomes chunker.py — redirect output to SQLite instead of .md files |
| `extract-references.py` | Splits CLI references by config blocks (firewall, system, vpn), diagnose/execute command groups | Same — merge into chunker.py with doc_type-aware splitting |
| `extract-profile.sh` | Ollama-based YAML profile extraction | Dead. Drop entirely. |
| `process-now.sh` | Runs pymupdf4llm on PDFs in to-process/ | Keep as-is — this is the Marker entry point |

## Output examples (reference for quality)

In old repo at `~/Documents/Claude/Projects/LabSmith/marker-scripts/skills/output-examples/`:
- `Module-00-PreLab.md` — orientation and hardware verification
- `Module-01-FortiGate-Initial-Setup.md` — baseline config from factory default
- `Module-02-Interfaces-Zones-VLANs.md` — network configuration

These demonstrate the target module format: frontmatter → overview → learning objectives → topology → numbered tasks with CLI blocks → Cisco equivalence tables → verification steps.

## Open questions

- Chunking edge cases: how to handle content that spans headings or has no heading structure
- Should chunker.py auto-detect doc_type from content, or require it as a flag (like the existing --prefix pattern)?
