# LabSmith — User Guide

LabSmith builds hands-on training modules from vendor PDFs. You convert documentation once, then generate as many lab modules as you need — each one grounded in the actual product docs, not hallucinated.

It runs as a Cowork plugin inside Claude Desktop. Two skills: **convert** (PDF to searchable chunks) and **build-module** (chunks to lab exercise).

---

## Feedback wanted

This is an early release and I'd love your input. If something doesn't work, doesn't make sense, or could be better — I want to hear it. Don't worry about being polite; blunt and specific is the most helpful.

**How to give feedback:** Open an issue at [github.com/mikepesh/labsmith/issues](https://github.com/mikepesh/labsmith/issues). Pick whichever fits:

- **Bug** — something broke or didn't work as described
- **Idea** — a feature, workflow change, or module improvement you'd find useful
- **Question** — anything unclear in the guide or the tool itself

No GitHub account? Just message me directly — Slack, email, whatever works.

---

## Prerequisites

- **Claude Pro, Team, or Enterprise subscription** — Cowork mode is required, which is not available on the free tier
- **Python 3.9+** and **git** — checked when you run `labsmith.sh` (or `setup.sh` if you use that first)
- **macOS or Linux** — the PDF converter and shell scripts assume a Unix environment

## Setup (one time, ~5 minutes)

### 1. Clone and run the wizard

```bash
git clone https://github.com/mikepesh/labsmith.git ~/Documents/labsmith
cd ~/Documents/labsmith
bash labsmith.sh
```

Step 2 of the wizard checks Python 3.9+ and git, can install missing dependencies on macOS (Homebrew) or Debian/Ubuntu (apt), and installs the PDF stack under `marker/venv/`. That logic lives in `scripts/prereqs-common.sh` and is the same code `setup.sh` uses.

**Optional:** Run `bash setup.sh` instead if you want install-and-verify only (extra checks like `bash -n` on `process-now.sh`, optional `test-pipeline.sh` when present) and an offer to launch `labsmith.sh` afterward — useful for automation or when you want confirmation before the full wizard.

**Experimental Textual UI (testing only):** `bash scripts/labsmith-tui.sh` launches a menu-driven interface over the same underlying scripts (`process-now.sh`, `chunker.py`, `query.py`). It is **not** the supported default path; use `bash labsmith.sh` for the standard wizard.

### 2. Install the Cowork plugin

Open Claude Desktop. Drag `labsmith.plugin` into a Cowork session, or install it however your team distributes plugins. Once installed, you'll have two skills available in every Cowork session: **convert** and **build-module**.

---

## The workflow

Everything happens in two phases, both from Terminal.

### Phase 1 — Convert your docs

Put your vendor PDFs in `marker/to-process/` and run the pipeline. Do this from Terminal (not Cowork) because the chunker writes to SQLite, which doesn't work on Cowork-mounted directories.

```bash
cd ~/Documents/labsmith

# Step 1: Drop PDFs in
cp ~/Downloads/FortiOS-Admin-Guide.pdf marker/to-process/

# Step 2: Convert PDF to markdown
bash marker/process-now.sh

# Step 3: Chunk the markdown into SQLite (doc-type optional; default is reference)
python3 chunker.py marker/output/FortiOS-Admin-Guide.md \
  --workshop my-workshop

# Step 4: Verify
python3 query.py stats --workshop my-workshop
```

Large PDFs (100+ MB) take time. The script shows progress as it goes — page count, percentage, estimated time remaining.

**Doc types (optional):** If you omit `--doc-type`, chunks are stored as **`reference`** (default) — general material using the same heading-based splitting as admin guides. Add `--doc-type` when you want to categorize or use special handling:

| Type | When to use |
|------|-------------|
| **`reference`** (default) | General PDFs; no flag needed. |
| **`admin`** | Admin guides (explicit label in stats/search). |
| **`cli`** | CLI references (config-block-aware splitting). |
| **`datasheet`** | Product datasheets. |
| **`release-notes`** | Release notes. |

Example with classification:  
`python3 chunker.py marker/output/Guide.md --workshop my-workshop --doc-type cli`

You can load multiple documents into the same workshop with different types over time.

### Phase 2 — Build modules

Open Cowork, mount your `labsmith` folder, and tell Claude what you need:

- "Build a module on firewall policies for the my-workshop workshop"
- "What topics can I build from these docs?"
- "Next module: VPN configuration"

Claude searches the chunks, pulls only the relevant sections, and writes a complete lab module with objectives, command reference tables, step-by-step exercises, and instructor notes. Each module is 300–600 lines of structured markdown saved to `workshops/<name>/modules/`.

---

## What you get

Each module follows a consistent format:

**Frontmatter** — title, workshop name, estimated time, prerequisites

**Overview** — what the module covers and why it matters

**Learning Objectives** — 4–6 measurable outcomes

**Conceptual Overview** — technical explanation, with a platform comparison if you're building a migration workshop (e.g., Cisco to Fortinet terminology mapping)

**Command Reference Table** — 8–15 common tasks with CLI commands, old-platform equivalents where applicable

**Lab Exercise** — numbered parts with step-by-step CLI commands and verification checks after each part

**Instructor Notes** — talking points, common mistakes, anticipated questions with answers, pacing tips

---

## Useful commands

Run these from `~/Documents/labsmith`:

```bash
# See what's in the database
python3 query.py stats --workshop my-workshop

# List all chunks (shows id, title, source doc, line count)
python3 query.py list --workshop my-workshop

# Search for chunks by keyword
python3 query.py search "VLAN" --workshop my-workshop

# Load specific chunks by ID
python3 query.py get 12 13 14
```

---

## Best practices

### Choosing documents

**More docs = better modules.** Every document you convert adds to the reference pool that Claude draws from. Conversion happens locally on your machine — it doesn't cost tokens or hit any API. Load as much as you have.

**Prioritize admin guides.** They have the broadest coverage and give you the most topics to build from. A single admin guide can support 10-20 modules.

**Layer in CLI references.** These give Claude the exact command syntax for command reference tables and lab exercises. Without a CLI reference, Claude will still write commands but may mark them with VERIFY comments.

**Datasheets are useful for hardware-specific modules.** If your workshop involves specific appliance models (FortiGate 90G, FortiSwitch 248E), loading the datasheets lets Claude reference real specs like port counts, throughput ratings, and supported features.

**Release notes help with version-specific content.** If you're training on a specific firmware version, the release notes tell Claude what's new, what changed, and what caveats to mention.

**Don't worry about overlap.** If the admin guide and CLI reference both cover the same topic, that's fine. Claude picks the best chunks for the job. Redundancy in your reference material leads to better-grounded modules.

**Avoid marketing PDFs and solution briefs.** These are light on technical detail and heavy on positioning language. They won't help Claude write lab exercises.

### Organizing workshops

**One workshop per engagement.** Create a named workshop for each customer or training event (e.g., `cisco-to-fortinet`, `acme-corp-onboarding`). All docs and modules stay organized under that workshop name.

**Reuse docs across workshops.** The same admin guide can be loaded into multiple workshops. Convert once, chunk into each workshop that needs it.

**Name workshops descriptively.** Use lowercase and hyphens: `cisco-to-fortinet`, `financial-services-onboarding`, `fortigate-ha-deep-dive`. You'll thank yourself later when you have a dozen.

### Building modules

**Let Claude search, don't dump.** The whole point is token efficiency. Claude queries SQLite for just the chunks it needs instead of reading entire documents. Don't paste raw PDF content into the chat — that defeats the purpose.

**Build modules in order.** Start with foundational topics (initial setup, basic connectivity) before advanced ones (HA, SD-WAN). Modules can reference prerequisites, and it helps learners progress logically.

**Ask Claude what's available.** Before deciding what modules to build, ask: "What topics can I build from these docs?" Claude will search the chunks and suggest what's well-covered vs. thin.

**Review the output.** Modules are grounded in real docs, but always check CLI commands against your lab environment. Look for `<!-- VERIFY -->` comments — those flag anything Claude wasn't 100% sure about from the reference material.

**Customize after generation.** The generated module is a solid first draft. Add your own war stories, adjust timing for your audience, swap in environment-specific IP addresses and hostnames. The structure is the hard part — personalizing it is quick.

### General

**Keep your database.** `labsmith.db` is your reference store. Converting a 4,600-page admin guide takes ~17 minutes. Don't delete the database unless you're starting fresh. You can always add more docs to an existing workshop.

**Conversion is free.** It runs locally on your laptop — no API calls, no tokens, no rate limits. The only cost is time (~4-5 pages per second on a modern Mac). Convert everything you might need upfront.

---

## Directory structure

```
labsmith/
  labsmith.sh              # Main entry: wizard (prereqs → workshop → PDFs → convert → done)
  setup.sh                 # Optional: same prereqs + extra verification; can launch labsmith.sh after
  scripts/
    prereqs-common.sh      # Shared Python/git/venv install logic (sourced by setup.sh and labsmith.sh)
    labsmith-tui.sh        # Experimental Textual UI bootstrap (testing only)
  tui/                     # Textual app (used only by labsmith-tui.sh)
  marker/
    process-now.sh         # PDF conversion script
    to-process/            # Drop PDFs here
    output/                # Converted markdown (gitignored)
    processed/             # PDFs after conversion (gitignored)
    venv/                  # Python environment for pymupdf4llm
  workshops/               # Generated modules live here (gitignored)
    my-workshop/
      modules/             # One .md file per module
  plugin/
    plugin.json            # Plugin metadata
    skills/
      convert/SKILL.md     # Convert skill definition
      build-module/
        SKILL.md           # Build module skill definition
        references/
          module-format.md # Canonical module structure
  chunker.py               # Splits markdown into SQLite chunks
  query.py                 # Searches and retrieves chunks
  labsmith.db              # SQLite reference store (gitignored)
  labsmith.plugin          # Installable Cowork plugin file
```

---

## A note on how this was built

LabSmith was built by a presales SE, not a software engineer. The code — Python scripts, shell pipelines, Cowork plugin structure, this guide — was written with significant help from Claude. I brought the problem (we spend too long building workshops from scratch), the domain knowledge (what makes a good lab module), and the design decisions. Claude helped turn that into working code.

I mention this for two reasons. First, transparency — you should know that AI wrote most of the code you're running. Second, encouragement — if you see ways to improve this, you don't need to be a developer to do it. Open a Cowork session, describe what you want to change, and iterate. That's how this whole project was built.

---

## Troubleshooting

**"pymupdf4llm not found"** — Run `bash labsmith.sh --step prereqs` (or `bash setup.sh`) to install into `marker/venv/`. Or manually: `cd marker && python3 -m venv venv && venv/bin/pip install pymupdf4llm`.

**"No files in to-process/"** — Put your PDFs in `marker/to-process/` before running `process-now.sh`.

**Chunker says "invalid doc-type"** — Valid types are: `reference` (default), `admin`, `cli`, `datasheet`, `release-notes`. Omit the flag to use `reference`.

**query.py returns nothing** — Run `python3 query.py stats` to check if the database has any chunks. If empty, you need to run the convert pipeline first.

**Module is too short** — Tell Claude to expand it. Anything under 100 lines is incomplete.

**Plugin skills not showing in Cowork** — Make sure the labsmith plugin is installed and your labsmith folder is mounted in the Cowork session.

**Large PDF seems stuck** — It's not stuck. A 4,600-page PDF takes ~17 minutes. Watch the progress output — it updates every 50 pages.

**SQLite error in Cowork** — The convert pipeline must run from Terminal, not inside Cowork. SQLite can't write to Cowork-mounted directories. Building modules (read-only queries) works fine in Cowork.
