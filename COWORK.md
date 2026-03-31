# LabSmith v2 — Project State

## Current version
v2.0-beta (not yet tagged)

## Last completed (2026-03-30)
- Phase 1: chunker.py + query.py built and tested (13/13 automated tests pass)
- Phase 2: Plugin structure built (plugin.json, convert SKILL.md, build-module SKILL.md, module-format.md)
- Phase 3 (in progress): Manual validation of build-module flow
  - Chunked FortiGate 90G datasheet into SQLite (4 chunks)
  - Generated Module-01-FortiGate-90G-Initial-Setup.md (~350 lines, all sections, grounded in datasheet)
  - Convert SKILL.md updated for Terminal-only constraint (SQLite can't write to Cowork mounts)
- GETTING-STARTED.md written
- test-pipeline.sh automated suite working (with real PDF support)

## Next priority
- Review Module-01 quality against module-format.md standards
- Package plugin for Cowork installation (format TBD)
- Run manual Cowork skill tests (C3-C5 from TEST-PLAN.md)
- Token efficiency measurement (C5): compare loaded chunks vs full doc size

## Open issues
- Plugin packaging format not finalized — need to understand Cowork plugin distribution
- SQLite writes blocked on Cowork mounts — convert skill must run from Terminal (documented)
- Open Brain MCP was timing out — session thoughts not fully pushed
- COWORK.md in old repo (~/Documents/labsmith/) still points to v1 state

## Repo
`~/Documents/CODING/labsmith/` → origin/main
Old repo (reference only): `~/Documents/labsmith/`

## Quick reference
- Convert docs: `bash marker/process-now.sh` then `python3 chunker.py ...`
- Query chunks: `python3 query.py --db labsmith.db [list|search|get|stats]`
- Run tests: `bash test-pipeline.sh`
- Run tests with PDF: `bash test-pipeline.sh /path/to/doc.pdf`
- Modules live in: `workshops/<name>/modules/`
- Plugin skills: `plugin/skills/convert/` and `plugin/skills/build-module/`
