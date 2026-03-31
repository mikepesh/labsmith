# LabSmith v2 — Getting Started

## What is LabSmith?

LabSmith is a Cowork plugin that helps presales engineers build hands-on training workshops from vendor documentation. Drop in PDFs, convert them to searchable reference chunks, then tell Claude what module you want — it pulls only the relevant context and writes a structured lab exercise.

Three steps: **Convert → Build → Deliver.**

## Prerequisites

- **Claude Desktop** with Cowork mode enabled
- **Python 3.9+** installed on your Mac
- **Git** (for cloning the repo)
- A set of vendor PDFs you want to build a workshop from (datasheets, admin guides, CLI references, release notes)

## 1. Clone the repo

```bash
git clone git@github.com:mikepesh/labsmith.git ~/Documents/labsmith
cd ~/Documents/labsmith
```

## 2. Set up Marker (PDF converter)

Marker converts PDFs to clean markdown using pymupdf4llm. It needs a Python virtual environment:

```bash
cd marker
python3 -m venv venv
venv/bin/pip install pymupdf4llm
cd ..
```

Verify it works:

```bash
bash marker/process-now.sh
# Should print "No files in to-process/ — nothing to do."
```

## 3. Install the Cowork plugin

In Claude Desktop, install the LabSmith plugin. This gives you two skills:

- **convert** — processes PDFs into searchable reference chunks
- **build-module** — generates lab modules from your reference material

*(Plugin installation instructions depend on how you distribute the .plugin file — see Plugin Packaging below.)*

## 4. Convert your first docs

### Option A: Using the Cowork plugin (recommended)

1. Open a Cowork session and mount your labsmith folder
2. Drop a PDF into the session or place it in `marker/to-process/`
3. Say: **"Convert this for the cisco-to-fortinet workshop, it's an admin guide"**
4. Claude runs Marker, chunks the output by heading, and stores it in SQLite

### Option B: From the terminal

```bash
# Step 1 — Drop PDFs in the input folder
cp ~/Downloads/FortiOS-Admin-Guide.pdf marker/to-process/

# Step 2 — Run Marker
bash marker/process-now.sh

# Step 3 — Chunk into SQLite
python3 chunker.py marker/output/FortiOS-Admin-Guide.md \
  --workshop cisco-to-fortinet \
  --doc-type admin

# Step 4 — Verify
python3 query.py list --workshop cisco-to-fortinet
```

### Doc types

Use the right `--doc-type` flag for each document:

| Type | Use for |
|------|---------|
| `admin` | Administration guides, user guides |
| `cli` | CLI references, command references |
| `datasheet` | Product datasheets, spec sheets |
| `release-notes` | Release notes, what's new docs |

## 5. Build your first module

### In Cowork (recommended)

Say: **"Build a module on VLAN configuration for the cisco-to-fortinet workshop"**

Claude will:
1. Query SQLite for chunks related to VLANs
2. Load only the relevant reference material
3. Write a complete lab module with objectives, conceptual overview, command tables, exercises, and instructor notes
4. Save it to `workshops/cisco-to-fortinet/modules/`

### What a module looks like

Each module is a self-contained `.md` file following this structure:

```
# Module 05 — VLAN Configuration

**Workshop:** Cisco to Fortinet Migration
**Estimated Time:** 60 minutes
**Prerequisites:** Modules 00, 01

---

## Overview
## Learning Objectives
## Conceptual Overview       ← includes platform comparison if relevant
## Command Reference Table   ← 8-15 common tasks with CLI commands
## Lab Exercise              ← numbered steps with verification
## Instructor Notes          ← talking points, common mistakes, Q&A
```

See `examples/` for full sample modules.

## 6. Deliver

Each lab is its own `.md` file in `workshops/<name>/modules/`. When you're ready to hand out materials, ask Claude in Cowork to compile them into a docx or PDF — no dedicated skill needed, just ask.

## Useful commands

```bash
# List all chunks for a workshop
python3 query.py list --workshop cisco-to-fortinet

# Search for chunks by topic
python3 query.py search "firewall policy" --workshop cisco-to-fortinet

# Get full content of specific chunks
python3 query.py get 12 13 14

# Stats: chunk count, total lines, breakdown by doc type
python3 query.py stats --workshop cisco-to-fortinet

# Run the automated test suite
bash test-pipeline.sh

# Run tests with a real PDF
bash test-pipeline.sh /path/to/your-doc.pdf
```

## Directory structure

```
labsmith/
  marker/
    process-now.sh         ← PDF conversion pipeline
    to-process/            ← Drop PDFs here
    output/                ← Marker markdown output
    processed/             ← PDFs moved here after conversion
    venv/                  ← Python venv with pymupdf4llm
  workshops/
    cisco-to-fortinet/
      references/          ← Converted markdown (flat files)
      modules/             ← Generated lab modules (.md each)
  plugin/
    plugin.json            ← Plugin metadata
    skills/
      convert/SKILL.md     ← Convert skill definition
      build-module/
        SKILL.md           ← Build module skill definition
        references/
          module-format.md ← Canonical module format
  examples/                ← Sample module output for reference
  chunker.py               ← Markdown → SQLite chunker
  query.py                 ← SQLite search and retrieval
  labsmith.db              ← Shared reference store (gitignored)
  test-pipeline.sh         ← Automated test suite
  PROJECT.md               ← Full project definition and architecture
  TEST-PLAN.md             ← Test plan (automated + manual)
```

## Plugin packaging

To package the plugin for distribution:

```bash
cd ~/Documents/labsmith
# TODO: packaging command TBD — depends on Cowork plugin format
```

*(This section will be updated once plugin packaging is finalized.)*

## Token efficiency — why SQLite?

The whole point of LabSmith is token efficiency. Here's the flow:

1. **Without LabSmith:** Feed 20 raw PDFs to Claude → burns thousands of tokens on PDF processing → Claude tries to find relevant info in a sea of content
2. **With LabSmith:** Marker converts PDFs offline (zero tokens). Chunker stores sections in SQLite. When building a module, Claude queries for just the 10-20 relevant paragraphs instead of loading 20 full documents. **8-10x token reduction.**

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `pymupdf4llm` not found | `cd marker && python3 -m venv venv && venv/bin/pip install pymupdf4llm` |
| Marker says "No files in to-process/" | Put PDFs in `marker/to-process/` first |
| Chunker says invalid doc-type | Use one of: `admin`, `cli`, `datasheet`, `release-notes` |
| query.py returns nothing | Run `python3 query.py stats` to check if anything is in the DB |
| Module is too short (<100 lines) | Tell Claude to expand — short modules are always incomplete |
| Plugin skills not showing in Cowork | Check that the labsmith plugin is installed and the folder is mounted |
