# LabSmith v2 — Phase 2 Cursor Prompt

## Context

Phase 1 is complete: `chunker.py`, `query.py`, and the SQLite schema are built and verified. Read `PROJECT.md` for the full project definition.

**This session focuses on Phase 2: building the Cowork plugin — skill definitions and plugin packaging.**

A Cowork plugin is a directory structure with:
- `plugin.json` — metadata and skill registry
- `skills/<skill-name>/SKILL.md` — instruction files that tell Claude how to behave when the skill is triggered

Skills are NOT code. They're structured prompts (markdown) that Claude reads and follows. They reference the tools built in Phase 1 (`chunker.py`, `query.py`) via bash commands.

## Step 1 — Create the plugin structure

```
plugin/
  plugin.json
  skills/
    convert/
      SKILL.md
    build-module/
      SKILL.md
      references/
        module-format.md
```

## Step 2 — Write plugin.json

```json
{
  "name": "labsmith",
  "version": "2.0.0",
  "description": "Build hands-on training workshops from vendor documentation. Convert PDFs to searchable reference chunks, then generate structured lab modules grounded in real product docs.",
  "skills": [
    {
      "name": "convert",
      "description": "Convert PDFs (datasheets, admin guides, release notes, CLI references) into searchable reference chunks stored in SQLite. Use when the user says 'convert', 'process these PDFs', 'add docs', 'convert my datasheets', 'ingest these docs', or drops PDF files and wants them turned into reference material for workshop authoring.",
      "path": "skills/convert"
    },
    {
      "name": "build-module",
      "description": "Generate a structured hands-on lab module from reference material. Use when the user says 'build a module', 'create a lab', 'new module', 'write a module', 'generate a module on [topic]', or wants to turn their converted reference docs into a training exercise.",
      "path": "skills/build-module"
    }
  ]
}
```

## Step 3 — Write skills/convert/SKILL.md

```markdown
---
name: convert
description: >
  Convert vendor PDFs into searchable reference chunks stored in SQLite.
  Use when the user says "convert", "process these PDFs", "add docs",
  "ingest these docs", or drops PDF files for workshop reference material.
---

# LabSmith — Convert Docs

This skill converts vendor documentation (PDFs) into markdown, chunks it by heading, and stores it in SQLite so the build-module skill can query only what it needs.

## What happens

Two steps under the hood:

1. **Marker** converts PDF → clean markdown
2. **Chunker** splits markdown by heading → stores chunks in SQLite with metadata

The user just drops PDFs and says "convert these." One action, two things happen.

## Prerequisites

- Python 3 with `pymupdf4llm` installed (Marker dependency)
- Marker venv at `marker/venv/` OR pymupdf4llm available globally

## Workflow

### Step 1 — Determine workshop name

Ask the user which workshop these docs belong to. If only one workshop exists, use it. If none exist yet, ask what to name it.

Check existing workshops:

\`\`\`bash
ls workshops/
\`\`\`

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

For each PDF, run the Marker pipeline:

\`\`\`bash
cd /path/to/labsmith && bash marker/process-now.sh
\`\`\`

Or for a specific file:

\`\`\`bash
cd /path/to/labsmith && bash marker/process-now.sh filename.pdf
\`\`\`

The PDF goes in `marker/to-process/`, markdown output lands in `marker/output/`.

### Step 4 — Run Chunker

For each converted markdown file:

\`\`\`bash
python3 chunker.py marker/output/<filename>.md --workshop <workshop-name> --doc-type <type>
\`\`\`

### Step 5 — Copy markdown to workshop references

\`\`\`bash
cp marker/output/<filename>.md workshops/<workshop-name>/references/
\`\`\`

### Step 6 — Confirm

Show the user:
- Number of chunks stored
- Total lines processed
- Breakdown by section title (use `query.py list`)

\`\`\`bash
python3 query.py list --workshop <workshop-name>
\`\`\`

## Error handling

| Situation | Action |
|-----------|--------|
| Marker not installed / venv missing | Tell user: `cd marker && python3 -m venv venv && venv/bin/pip install pymupdf4llm` |
| PDF conversion fails | Report the error, suggest checking if the PDF is corrupted or password-protected |
| Chunker finds 0 sections | Warn user — the markdown may lack heading structure. Offer to store as a single chunk. |
| Workshop directory doesn't exist | Create it: `mkdir -p workshops/<name>/{references,modules}` |
```

## Step 4 — Write skills/build-module/SKILL.md

```markdown
---
name: build-module
description: >
  Generate a structured hands-on lab module grounded in reference material.
  Use when the user says "build a module", "create a lab", "new module",
  "write a module", "generate a module on [topic]", or wants to create
  a training exercise from their converted docs.
---

# LabSmith — Build Module

This skill generates a complete, structured lab module grounded in real vendor documentation stored in SQLite. Claude queries only the relevant reference chunks — not full documents — keeping token usage tight.

**Claude writes the module directly. No external generation tools.**

## Workflow

### Stage 1 — Gather requirements

Ask the user what module they want to build. Collect:

| Field | Required | Example |
|-------|----------|---------|
| Workshop | Yes | cisco-to-fortinet |
| Module number | Yes | 05 |
| Title | Yes | FortiLink & Managed Switches |
| Topic / focus | Yes | FortiLink setup, FortiSwitch management from FortiGate |
| Estimated duration | No (default: 60 min) | 45 minutes |
| Prerequisites | No (default: none) | Modules 00, 01 |
| Audience context | No | Cisco-experienced engineers |

Use the AskUserQuestion tool for structured fields where possible.

### Stage 2 — Query reference material

Search SQLite for chunks relevant to the module topic:

\`\`\`bash
python3 query.py search "<topic keywords>" --workshop <workshop>
\`\`\`

Review the results (id, section_title, source_doc, doc_type, line_count). Select the most relevant chunks and load their content:

\`\`\`bash
python3 query.py get <id1> <id2> <id3> ...
\`\`\`

**Token efficiency rule:** Only load chunks you will actually use. Don't load everything — be selective based on section titles and doc types. Prefer:
- `cli` chunks for command reference tables
- `admin` chunks for conceptual overviews
- `datasheet` chunks for hardware specs (only if the module involves specific hardware)

If no relevant chunks exist, warn the user: "I don't have reference material on [topic]. I can still write the module but will use VERIFY comments on any claims I'm not certain about."

### Stage 3 — Generate the module

Read the module format reference first:

This file is at `skills/build-module/references/module-format.md` inside the plugin.

Then write the full module as a single markdown file.

#### Module structure (always follow this exact order)

\`\`\`
# Module <number> — <Title>

**Workshop:** <workshop name>
**Estimated Time:** <duration>
**Prerequisites:** <prerequisites or "None">

---

## Overview
## Learning Objectives
## Conceptual Overview    ← includes comparison to prior platform if relevant
## Command Reference Table
## Lab Exercise           ← numbered tasks with CLI blocks + verification
## Instructor Notes       ← talking points, common mistakes, Q&A, time tips
\`\`\`

#### Content rules

- **Ground claims in reference chunks.** If a CLI command, spec, or behavior comes from a loaded chunk, use it accurately. If you're uncertain, add `<!-- VERIFY: "description" -->`.
- **Conceptual Overview** — if the audience has prior platform experience (e.g., Cisco), include a comparison: mental model shift, terminology mapping table (Old Term | New Term | Notes).
- **Command Reference Table** — 8-15 entries. Columns: Task | Old CLI (if applicable) | New CLI. Source commands from `cli` chunks when available.
- **Lab Exercise** — numbered Parts. Each step shows the CLI command. If migration context exists, add `# Equivalent: <old command>` below each step. Each Part ends with a Verification section.
- **Instructor Notes** — four sections: Talking Points, Common Mistakes, Anticipated Questions + Answers, Time Management Tips.
- **Tone** — clear, direct, professional. Written for experienced engineers, not beginners.
- **Length** — a complete module is typically 300-600 lines. Under 100 lines is always incomplete.
- **No preamble** — the file starts with `# Module`. No "Here is your module:" or explanatory text before it.

### Stage 4 — Save and verify

Write the module to the workshop's modules directory:

\`\`\`bash
# Save
cat > workshops/<workshop>/modules/Module-<number>-<title-slug>.md << 'EOF'
<full module content>
EOF
\`\`\`

After saving, verify the file:

\`\`\`bash
wc -l workshops/<workshop>/modules/Module-<number>-<title-slug>.md
head -20 workshops/<workshop>/modules/Module-<number>-<title-slug>.md
\`\`\`

Report: filename, line count, sections present.

## Error handling

| Situation | Action |
|-----------|--------|
| No chunks in SQLite for this workshop | Warn user. Offer to generate with VERIFY comments or suggest running convert first. |
| Search returns no relevant chunks | Broaden search terms. Try doc_type filter. If still nothing, warn and use VERIFY comments. |
| Module under 100 lines | Always expand — incomplete output. |
| Workshop directory missing | Create it: `mkdir -p workshops/<name>/{references,modules}` |
```

## Step 5 — Write skills/build-module/references/module-format.md

```markdown
# LabSmith Module Format Reference

This document defines the canonical structure for LabSmith workshop modules. Every module follows this format.

## File naming

`Module-<NN>-<Title-Slug>.md`

Examples:
- `Module-00-PreLab.md`
- `Module-01-FortiGate-Initial-Setup.md`
- `Module-05-FortiLink-Managed-Switches.md`

## Frontmatter

Every module starts with:

\`\`\`markdown
# Module <NN> — <Title>

**Workshop:** <full workshop name>
**Estimated Time:** <duration>
**Prerequisites:** <module dependencies or "None">
\`\`\`

## Required sections (in order)

### Overview
2-3 paragraphs explaining what this module covers and why it matters. Set expectations for what the learner will be able to do afterward.

### Learning Objectives
Bulleted list starting with "By the end of this module you will be able to:" followed by 4-6 measurable objectives using action verbs (configure, verify, explain, troubleshoot).

### Conceptual Overview
Technical explanation of the topic. If the workshop targets engineers migrating from another platform, include:
- A mental model comparison (how the old platform handles this vs. the new one)
- A terminology mapping table: Old Term | New Term | Notes

### Command Reference Table
8-15 rows covering the most common operations for this topic.
Columns: Task | Old CLI (if applicable) | New CLI

### Lab Exercise
Numbered Parts (Part 1, Part 2, etc.). Each Part contains:
- Numbered steps with CLI command blocks
- If migration context: `# Equivalent: <old platform command>` below each command
- A **Verification** subsection at the end with `show`/`get`/`diagnose` commands and expected output

### Instructor Notes
Four subsections:
- **Talking Points** — key messages to emphasize
- **Common Mistakes** — what learners typically get wrong and how to help
- **Anticipated Questions and Answers** — 3-5 likely questions with prepared answers
- **Time Management Tips** — pacing guidance, where to spend vs. skip time

## Quality markers

- Total length: 300-600 lines (under 100 = incomplete)
- Every CLI command sourced from reference docs or marked with `<!-- VERIFY: "description" -->`
- No hardcoded values that should be environment-specific
- Clear, direct tone — assumes technical competence
```

## Step 6 — Copy the updated prompt to the v2 repo

Copy the latest `PROJECT.md` from the source if it has been updated:

\`\`\`bash
# Only if PROJECT.md in the labsmith repo is older than the source
cp ~/Documents/Claude/Projects/LabSmith/PROJECT.md ./ 2>/dev/null || true
\`\`\`

## Step 7 — Verify

- Confirm the plugin directory structure matches Step 1
- Validate `plugin.json` is valid JSON
- Read each SKILL.md and confirm it references the correct `chunker.py` / `query.py` commands
- Commit and push

## What NOT to do

- Do not modify `chunker.py` or `query.py` — Phase 1 is complete
- Do not build a web UI, API, or server
- Do not reference hardware profiles (YAML) — those are gone in v2
- Do not reference the old compiler, QA scripts, or Ollama
- Do not reference or modify anything outside this repo
