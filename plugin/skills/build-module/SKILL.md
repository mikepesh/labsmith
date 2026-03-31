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

## Repository root

All commands below assume the **LabSmith repository root** (the folder containing `chunker.py`, `query.py`, and `plugin/`).

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

```bash
python3 query.py search "<topic keywords>" --workshop <workshop> --db labsmith.db
```

Review the results (id, section_title, source_doc, doc_type, line_count). Select the most relevant chunks and load their content:

```bash
python3 query.py get <id1> <id2> <id3> ... --db labsmith.db
```

**Token efficiency rule:** Only load chunks you will actually use. Don't load everything — be selective based on section titles and doc types. Prefer:

- `cli` chunks for command reference tables
- `admin` chunks for conceptual overviews
- `datasheet` chunks for hardware specs (only if the module involves specific hardware)

If no relevant chunks exist, warn the user: "I don't have reference material on [topic]. I can still write the module but will use VERIFY comments on any claims I'm not certain about."

### Stage 3 — Generate the module

Read the module format reference first:

`plugin/skills/build-module/references/module-format.md` (relative to the repository root).

Then write the full module as a single markdown file.

#### Module structure (always follow this exact order)

```
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
```

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

```bash
# Save
cat > workshops/<workshop>/modules/Module-<number>-<title-slug>.md << 'EOF'
<full module content>
EOF
```

After saving, verify the file:

```bash
wc -l workshops/<workshop>/modules/Module-<number>-<title-slug>.md
head -20 workshops/<workshop>/modules/Module-<number>-<title-slug>.md
```

Report: filename, line count, sections present.

## Error handling

| Situation | Action |
|-----------|--------|
| No chunks in SQLite for this workshop | Warn user. Offer to generate with VERIFY comments or suggest running convert first. |
| Search returns no relevant chunks | Broaden search terms. Try `--doc-type` filter. If still nothing, warn and use VERIFY comments. |
| Module under 100 lines | Always expand — incomplete output. |
| Workshop directory missing | Create it: `mkdir -p workshops/<name>/{references,modules}` |
