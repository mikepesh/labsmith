# LabSmith v2 — Project State

## Current version
v0.1.0-beta (committed, not tagged)

## Last completed (2026-03-31)
- Plugin structure built, packaged as labsmith.plugin, installed in Cowork
- plugin.json spec-compliant (no skills array, author/keywords, v0.1.0)
- Skill descriptions tuned for aggressive triggering per Cowork best practices
- chunker.py + query.py built and tested (13/13 automated tests pass)
- Token efficiency validated: search metadata 29x cheaper, 10.3x projected reduction for 7-doc workshop
- FortiOS 7.6.6 Admin Guide converted (4,672 pages → 1,653 chunks via h1–h3 splitting)
- process-now.sh upgraded with 50-page batch progress output
- Three modules built from admin guide: Initial Setup (429 lines), Firewall Policies (496 lines), Security Fabric (438 lines)
- workshops/ gitignored — modules are per-engagement output, not source
- GETTING-STARTED.md in repo

## Open issues
- Chunk titles: many are CLI commands instead of meaningful section names (chunker picks up code examples as headings). Doesn't block module generation but hurts discoverability.
- SQLite writes blocked on Cowork mounts — convert skill must run from Terminal (documented, by design)

## Repo
`~/Documents/labsmith/` → origin/main

## Quick reference
- Convert docs: `bash marker/process-now.sh` then `python3 chunker.py ...`
- Query chunks: `python3 query.py --db labsmith.db [list|search|get|stats]`
- Run tests: `bash test-pipeline.sh`
- Modules live in: `workshops/<name>/modules/` (gitignored)
- Plugin skills: `plugin/skills/convert/` and `plugin/skills/build-module/`
- Install plugin: drop `labsmith.plugin` into a Cowork session
