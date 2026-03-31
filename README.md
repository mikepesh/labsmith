# LabSmith

Foundation for a Cowork plugin that helps presales engineers build hands-on workshops from vendor documentation: PDFs through Marker to markdown, chunked into SQLite, queried when authoring lab modules.

See `PROJECT.md` for scope, architecture, and roadmap. Phase 1 delivers `chunker.py`, `query.py`, and the `marker/` + `workshops/` layout.

## Related folders

- **This repo:** `~/Documents/CODING/labsmith/` (Cowork / SQLite / Marker foundation).
- **Previous Streamlit UI** (same `labsmith` path before 2026-03): `~/Documents/CODING/labsmith-streamlit/`.

## Quick use

```bash
# Ingest markdown (after Marker conversion)
python3 chunker.py path/to/doc.md --workshop cisco-to-fortinet --doc-type admin --db labsmith.db

# CLI-style reference PDFs → markdown
python3 chunker.py path/to/cli.md --workshop cisco-to-fortinet --doc-type cli --db labsmith.db

# Query (default DB: labsmith.db in cwd). If you pass `--db`, put it before the subcommand.
python3 query.py search "VLAN" --workshop cisco-to-fortinet
python3 query.py list --workshop cisco-to-fortinet
python3 query.py get 1 2
python3 query.py stats --workshop cisco-to-fortinet
```

PDF conversion: `bash marker/process-now.sh` (requires Python with `pymupdf4llm` in the Marker venv or globally).
