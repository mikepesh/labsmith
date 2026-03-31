# LabSmith — User Guide

LabSmith builds hands-on training modules from vendor PDFs. You convert documentation once, then generate as many lab modules as you need — each one grounded in the actual product docs, not hallucinated.

It runs as a Cowork plugin inside Claude Desktop. Two skills: **convert** (PDF to searchable chunks) and **build-module** (chunks to lab exercise).

---

## Prerequisites

- **Claude Pro, Team, or Enterprise subscription** — Cowork mode is required, which is not available on the free tier
- **Python 3.10+** and **git** — the setup script checks both
- **macOS or Linux** — the PDF converter and shell scripts assume a Unix environment

## Setup (one time, ~5 minutes)

### 1. Clone and run setup

```bash
git clone git@github.com:mikepesh/labsmith.git ~/Documents/CODING/labsmith
cd ~/Documents/CODING/labsmith
bash setup.sh
```

The setup script checks Python 3.10+, installs the PDF converter, runs the test suite, and tells you if anything is wrong. If everything passes, you're ready.

### 2. Install the Cowork plugin

Open Claude Desktop. Drag `labsmith.plugin` into a Cowork session, or install it however your team distributes plugins. Once installed, you'll have two skills available in every Cowork session: **convert** and **build-module**.

---

## The workflow

Everything happens in two phases, both from Terminal.

### Phase 1 — Convert your docs

Put your vendor PDFs in `marker/to-process/` and run the pipeline. Do this from Terminal (not Cowork) because the chunker writes to SQLite, which doesn't work on Cowork-mounted directories.

```bash
cd ~/Documents/CODING/labsmith

# Step 1: Drop PDFs in
cp ~/Downloads/FortiOS-Admin-Guide.pdf marker/to-process/

# Step 2: Convert PDF to markdown
bash marker/process-now.sh

# Step 3: Chunk the markdown into SQLite
python3 chunker.py marker/output/FortiOS-Admin-Guide.md \
  --workshop my-workshop --doc-type admin

# Step 4: Verify
python3 query.py stats --workshop my-workshop
```

Large PDFs (100+ MB) take time. The script shows progress as it goes — page count, percentage, estimated time remaining.

**Doc types:** Use `--doc-type admin` for admin guides, `cli` for CLI references, `datasheet` for datasheets, `release-notes` for release notes. Pick whichever matches the document. You can load multiple documents into the same workshop.

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

Run these from `~/Documents/CODING/labsmith`:

```bash
# See what's in the database
python3 query.py stats --workshop my-workshop

# List all chunks (shows id, title, source doc, line count)
python3 query.py list --workshop my-workshop

# Search for chunks by keyword
python3 query.py search "VLAN" --workshop my-workshop

# Load specific chunks by ID
python3 query.py get 12 13 14

# Run the automated test suite
bash test-pipeline.sh
```

---

## Best practices

**Start with the admin guide.** It has the broadest coverage and gives you the most topics to build from. Add CLI references and datasheets later for richer command tables and hardware-specific modules.

**One workshop per engagement.** Create a named workshop for each customer or training event (e.g., `cisco-to-fortinet`, `acme-corp-onboarding`). All docs and modules stay organized under that workshop name.

**Let Claude search, don't dump.** The whole point is token efficiency. Claude queries SQLite for just the chunks it needs instead of reading entire documents. Don't paste raw PDF content into the chat — that defeats the purpose.

**Review the output.** Modules are grounded in real docs, but always check CLI commands against your lab environment. Look for `<!-- VERIFY -->` comments — those flag anything Claude wasn't 100% sure about from the reference material.

**Build modules in order.** Start with foundational topics (initial setup, basic connectivity) before advanced ones (HA, SD-WAN). Modules can reference prerequisites, and it helps learners progress logically.

**Customize after generation.** The generated module is a solid first draft. Add your own war stories, adjust timing for your audience, swap in environment-specific IP addresses and hostnames. The structure is the hard part — personalizing it is quick.

**Keep your database.** `labsmith.db` is your reference store. Converting a 4,600-page admin guide takes ~17 minutes. Don't delete the database unless you're starting fresh. You can always add more docs to an existing workshop.

---

## Directory structure

```
labsmith/
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
  test-pipeline.sh         # Automated tests
```

---

## A note on how this was built

LabSmith was built by a presales SE, not a software engineer. The code — Python scripts, shell pipelines, Cowork plugin structure, this guide — was written with significant help from Claude. I brought the problem (we spend too long building workshops from scratch), the domain knowledge (what makes a good lab module), and the design decisions. Claude helped turn that into working code.

I mention this for two reasons. First, transparency — you should know that AI wrote most of the code you're running. Second, encouragement — if you see ways to improve this, you don't need to be a developer to do it. Open a Cowork session, describe what you want to change, and iterate. That's how this whole project was built.

---

## Troubleshooting

**"pymupdf4llm not found"** — Re-run `bash setup.sh` — it installs this automatically. Or manually: `cd marker && python3 -m venv venv && venv/bin/pip install pymupdf4llm`.

**"No files in to-process/"** — Put your PDFs in `marker/to-process/` before running `process-now.sh`.

**Chunker says "invalid doc-type"** — Valid types are: `admin`, `cli`, `datasheet`, `release-notes`.

**query.py returns nothing** — Run `python3 query.py stats` to check if the database has any chunks. If empty, you need to run the convert pipeline first.

**Module is too short** — Tell Claude to expand it. Anything under 100 lines is incomplete.

**Plugin skills not showing in Cowork** — Make sure the labsmith plugin is installed and your labsmith folder is mounted in the Cowork session.

**Large PDF seems stuck** — It's not stuck. A 4,600-page PDF takes ~17 minutes. Watch the progress output — it updates every 50 pages.

**SQLite error in Cowork** — The convert pipeline must run from Terminal, not inside Cowork. SQLite can't write to Cowork-mounted directories. Building modules (read-only queries) works fine in Cowork.
