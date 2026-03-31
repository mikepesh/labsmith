# LabSmith v2 — Project State

## Current version
v2.0-beta (committed, not tagged)

## Last completed (2026-03-31)
- Phase 1: chunker.py + query.py built and tested (13/13 automated tests pass)
- Phase 2: Plugin structure built and packaged as labsmith.plugin
  - plugin.json cleaned up (no skills array, added author/keywords, v0.1.0)
  - Skill descriptions expanded for aggressive triggering per Cowork best practices
  - Plugin installed in Cowork — both skills active
- Phase 3: Manual validation complete
  - Build-module skill tested: generated Module-02-FortiOS-CLI-Basics (395 lines, all sections, grounded in chunks)
  - Convert skill tested: correctly surfaces Terminal-only constraint and provides commands
  - Module-01-FortiGate-90G-Initial-Setup also validated (318 lines, all sections)
- Quality validation: both modules pass all format checks (6 required sections, 4 instructor note subsections, 6 lab parts each, VERIFY comments present)
- Token efficiency measured:
  - Search metadata: 29x cheaper than loading all content
  - Selective chunk loading: 51% reduction even within a single doc
  - Projected 7-doc workshop: 10.3x reduction (~90% fewer tokens per module build)
- GETTING-STARTED.md, COWORK.md, test-pipeline.sh all in repo
- Committed to git

## Next priority
- Convert more real PDFs (admin guide, CLI reference) to build richer reference material
- Build additional modules to further validate the workflow at scale
- Tag v0.1.0 release when ready

## Open issues
- SQLite writes blocked on Cowork mounts — convert skill must run from Terminal (documented, by design)
- Old repo (~/Documents/labsmith/) still points to v1 state — leave as-is for reference

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
- Install plugin: drop `labsmith.plugin` into a Cowork session
