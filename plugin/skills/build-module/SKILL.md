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

## Cowork runtime (read-only plugin)

The **plugin directory is extracted read-only**. Do not write modules, databases, or scratch files under the plugin tree.

- **`chunker.py` / `query.py` / `marker/` / `workshops/` / `labsmith.db`** — always on the user’s **mounted LabSmith workspace** (discovered below).
- **Module format spec** — read from the skill bundle only: `skills/build-module/references/module-format.md` (relative to the extracted plugin root; readable, not writable).

## Resolve the LabSmith workspace **first**

Before running `query.py` or writing to `workshops/`, find a directory that contains **all** of: `chunker.py`, `query.py`, and `marker/process-now.sh`. That directory is **LABSMITH_ROOT** (same discovery rule as the convert skill).

Cowork mounts the user’s project under session mounts, typically:

`/sessions/<session-id>/mnt/<folder-name>/`

Discover candidates:

```bash
for d in /sessions/*/mnt/*/; do
  [ -f "${d}chunker.py" ] && [ -f "${d}query.py" ] && [ -f "${d}marker/process-now.sh" ] && echo "${d}"
done
```

- **Zero results:** Stop and ask the user to **mount their LabSmith repo** in Cowork, then re-run the check (same pattern as the convert skill).
- **One result:** Use it as **LABSMITH_ROOT**.
- **Multiple results:** Prefer a mount named `labsmith` if present; otherwise list paths and ask which workspace to use.

Use **LABSMITH_ROOT** for every bash command:

```bash
cd "$LABSMITH_ROOT" || exit 1
pwd
```

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

From **LABSMITH_ROOT**:

```bash
python3 query.py --db labsmith.db search "<topic keywords>" --workshop <workshop>
```

Review the results (id, section_title, source_doc, doc_type, line_count). Select the most relevant chunks and load their content:

```bash
python3 query.py --db labsmith.db get <id1> <id2> <id3> ...
```

(`--db` must appear immediately after `query.py`, before the subcommand.)

**Token efficiency rule:** Only load chunks you will actually use. Don't load everything — be selective based on section titles and doc types. Prefer:

- `cli` chunks for command reference tables
- `admin` chunks for conceptual overviews
- `datasheet` chunks for hardware specs (only if the module involves specific hardware)

If no relevant chunks exist, warn the user: "I don't have reference material on [topic]. I can still write the module but will use VERIFY comments on any claims I'm not certain about."

### Stage 3 — Generate the module

Read the canonical format from the **bundled** reference (plugin read-only tree):

`skills/build-module/references/module-format.md`

Then write the full module as a single markdown file (content goes to the **workspace**, not the plugin).

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

Write the module under **LABSMITH_ROOT** only:

```bash
cd "$LABSMITH_ROOT"
cat > "workshops/<workshop>/modules/Module-<number>-<title-slug>.md" << 'EOF'
<full module content>
EOF
```

Verify:

```bash
wc -l "workshops/<workshop>/modules/Module-<number>-<title-slug>.md"
head -20 "workshops/<workshop>/modules/Module-<number>-<title-slug>.md"
```

Report: filename, line count, sections present.

## Error handling

| Situation | Action |
|-----------|--------|
| LabSmith workspace not mounted / discover finds 0 roots | Ask the user to mount the LabSmith repo in Cowork, then re-run discovery |
| No chunks in SQLite for this workshop | Warn user. Offer to generate with VERIFY comments or suggest running convert first. |
| Search returns no relevant chunks | Broaden search terms. Try `--doc-type` filter. If still nothing, warn and use VERIFY comments. |
| Module under 100 lines | Always expand — incomplete output. |
| Workshop directory missing | From **LABSMITH_ROOT**: `mkdir -p workshops/<name>/{references,modules}` |
