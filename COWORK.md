# LabSmith v2 — Project State

## Current version
v0.1.0 (tagged, released on GitHub)

## Last completed (2026-03-31)
- Plugin packaged as labsmith.plugin, installed in Cowork, both skills working
- Token efficiency validated: 10.3x projected reduction for 7-doc workshop
- FortiOS 7.6.6 Admin Guide converted (4,672 pages → 249 chunks after chunker fix)
- Chunker fixed to split on h1–h3, skip CLI-looking headings (was 1,653 noisy chunks, now 249 clean)
- process-now.sh upgraded with 50-page batch progress output
- Three modules built: Initial Setup (429 lines), Firewall Policies (496 lines), Security Fabric (438 lines)
- workshops/ gitignored — modules are per-engagement output, not source
- setup.sh with interactive prereq install (Homebrew/apt), tested with test-setup.sh simulation harness
- GETTING-STARTED.md removed — replaced by USER-GUIDE.md
- USER-GUIDE.md with expanded best practices (document selection, workshop organization, module building)
- README.md cleaned up — concise, links to USER-GUIDE.md, AI disclosure, feedback link
- TODO.md documents remaining chunk title quality issue
- labsmith.plugin repackaged with latest skill descriptions
- All paths updated from ~/Documents/CODING/labsmith to ~/Documents/labsmith
- v0.1.0 tagged and GitHub release created with .plugin attachment
- Clone URL switched from SSH to HTTPS for non-dev users

## In progress (Cursor)
- labsmith.sh — interactive terminal script replacing manual setup/convert workflow
- --doc-type made optional (default: `reference`) to reduce user friction
- Chunker title quality improvements (remaining ~23 junk titles)

## Open issues
- ~23 chunk titles are still junk (snmpwalk, log output, ktpass) — cosmetic, doesn't block module building
- SQLite writes blocked on Cowork mounts — convert must run from Terminal (by design)
- labsmith.plugin may need repackaging after Cursor completes current changes

## Documentation rule
Update USER-GUIDE.md as the last step of every feature, not as a separate task. Include doc updates in Cursor prompts.

## Repo
`~/Documents/labsmith/` → github.com/mikepesh/labsmith (public)

## Quick reference
- Interactive workflow: `bash labsmith.sh`
- Convert docs: `bash marker/process-now.sh` then `python3 chunker.py ...`
- Query chunks: `python3 query.py [list|search|get|stats]`
- Run tests: `bash test-pipeline.sh`
- Test setup scenarios: `bash test-setup.sh [--no-python|--no-git|--no-brew|--clean]`
- Modules live in: `workshops/<name>/modules/` (gitignored)
- Plugin skills: `plugin/skills/convert/` and `plugin/skills/build-module/`
