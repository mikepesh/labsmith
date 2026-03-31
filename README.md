# LabSmith

Foundation for a Cowork plugin that helps presales engineers build hands-on workshops from vendor documentation: PDFs through Marker to markdown, chunked into SQLite, queried when authoring lab modules.

See `PROJECT.md` for scope, architecture, and roadmap. Phase 1 delivers `chunker.py`, `query.py`, and the `marker/` + `workshops/` layout.

## Directory name

The **canonical** repo folder is `~/Documents/CODING/labsmith/`. If this checkout is still named `labsmith-v2`, rename it after freeing that name: you may already have a different project at `CODING/labsmith` (for example the Streamlit app). Rename or archive that folder first, then:

```bash
cd /Users/baymax/Documents/CODING
mv labsmith-v2 labsmith
```

Reopen the project in Cursor from `labsmith/`. Git history stays intact (`.git` moves with the directory).

## Quick use

```bash
# Ingest markdown (after Marker conversion)
python3 chunker.py path/to/doc.md --workshop cisco-to-fortinet --doc-type admin --db labsmith.db

# CLI-style reference PDFs → markdown
python3 chunker.py path/to/cli.md --workshop cisco-to-fortinet --doc-type cli --db labsmith.db

# Query
python3 query.py search "VLAN" --workshop cisco-to-fortinet
python3 query.py list --workshop cisco-to-fortinet
python3 query.py get 1 2
python3 query.py stats --workshop cisco-to-fortinet
```

PDF conversion: `bash marker/process-now.sh` (requires Python with `pymupdf4llm` in the Marker venv or globally).
