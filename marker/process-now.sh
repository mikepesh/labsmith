#!/bin/bash

# LabSmith — One-shot PDF processor
# Converts all PDFs in to-process/ and moves originals to processed/
# Same conversion logic as watch.sh but runs once and exits.
# Designed to be called from Cowork or CLI.
#
# Usage:
#   bash marker/process-now.sh              # process all PDFs in to-process/
#   bash marker/process-now.sh file.pdf     # process a specific file

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
WATCH_DIR="$BASE_DIR/to-process"
OUTPUT_DIR="$BASE_DIR/output"
DONE_DIR="$BASE_DIR/processed"

mkdir -p "$WATCH_DIR" "$OUTPUT_DIR" "$DONE_DIR"

# ── Find a working Python with pymupdf4llm ──
PYTHON=""
if [ -d "$BASE_DIR/venv" ] && [ -f "$BASE_DIR/venv/bin/python3" ]; then
    PYTHON="$BASE_DIR/venv/bin/python3"
elif command -v python3 &>/dev/null; then
    # Check if pymupdf4llm is importable
    if python3 -c "import pymupdf4llm" 2>/dev/null; then
        PYTHON="python3"
    fi
fi

if [ -z "$PYTHON" ]; then
    echo "❌ No Python environment with pymupdf4llm found."
    echo "   Either create the venv:  python3 -m venv $BASE_DIR/venv && $BASE_DIR/venv/bin/pip install pymupdf4llm"
    echo "   Or install globally:     pip install pymupdf4llm"
    exit 1
fi

# ── Conversion function ──
process_file() {
    local file="$1"
    local filename=$(basename "$file")
    local name="${filename%.*}"
    local ext=$(echo "${filename##*.}" | tr '[:upper:]' '[:lower:]')

    if [ "$ext" != "pdf" ]; then
        echo "⏭️  Skipping non-PDF: $filename"
        return 0
    fi

    # Skip if output already exists and is newer than source
    if [ -f "$OUTPUT_DIR/$name.md" ] && [ "$OUTPUT_DIR/$name.md" -nt "$file" ]; then
        echo "⏩ Already converted: $name.md — moving original"
        mv "$file" "$DONE_DIR/$filename"
        return 0
    fi

    echo "🔄 Converting: $filename"

    "$PYTHON" << PYEOF
import pymupdf4llm
import pymupdf
from pathlib import Path
import re
import sys
import time

filepath = "$file"
outpath = Path("$OUTPUT_DIR") / "$name.md"

# Get page count first for progress reporting
doc = pymupdf.open(filepath)
total_pages = len(doc)
doc.close()

print(f"   PDF has {total_pages} pages")
print(f"   Converting...", flush=True)

start_time = time.time()

# Process in batches for progress reporting on large files
BATCH_SIZE = 50
md_parts = []

for batch_start in range(0, total_pages, BATCH_SIZE):
    batch_end = min(batch_start + BATCH_SIZE, total_pages)
    pages = list(range(batch_start, batch_end))
    batch_md = pymupdf4llm.to_markdown(filepath, pages=pages)
    md_parts.append(batch_md)

    elapsed = time.time() - start_time
    pct = (batch_end / total_pages) * 100
    pages_per_sec = batch_end / elapsed if elapsed > 0 else 0
    remaining = ((total_pages - batch_end) / pages_per_sec) if pages_per_sec > 0 else 0

    print(f"   [{pct:5.1f}%] {batch_end}/{total_pages} pages — {elapsed:.0f}s elapsed, ~{remaining:.0f}s remaining", flush=True)

md = "\n\n".join(md_parts)

elapsed_total = time.time() - start_time
print(f"   Conversion done in {elapsed_total:.0f}s ({total_pages / elapsed_total:.1f} pages/sec)")

# Clean up mangled TOC entries (rows of pipes and dashes)
print("   Cleaning up TOC artifacts...", flush=True)
lines = md.split('\n')
clean_lines = []
for line in lines:
    stripped = line.strip()
    if stripped:
        pipe_ratio = stripped.count('|') / len(stripped)
        dash_ratio = stripped.count('-') / len(stripped)
        if pipe_ratio > 0.3 or (dash_ratio > 0.5 and '|' in stripped):
            continue
    clean_lines.append(line)

# Remove excessive blank lines (3+ in a row → 2)
cleaned = '\n'.join(clean_lines)
cleaned = re.sub(r'\n{4,}', '\n\n\n', cleaned)

outpath.write_bytes(cleaned.encode())
size_kb = outpath.stat().st_size / 1024
print(f"   Output: {size_kb:.0f} KB → {outpath.name}")
PYEOF

    if [ $? -eq 0 ]; then
        echo "✅ Done: $name.md"
        mv "$file" "$DONE_DIR/$filename"
        echo "📦 Original moved to processed/"
        return 0
    else
        echo "❌ Conversion failed for $filename"
        return 1
    fi
}

# ── Main ──
echo "╔══════════════════════════════════════════════════════╗"
echo "║        LabSmith — PDF Processor (one-shot)           ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

FAILURES=0
PROCESSED=0

if [ -n "$1" ]; then
    # Process a specific file
    TARGET="$WATCH_DIR/$1"
    if [ ! -f "$TARGET" ]; then
        # Maybe they gave a full path
        TARGET="$1"
    fi
    if [ ! -f "$TARGET" ]; then
        echo "❌ File not found: $1"
        exit 1
    fi
    process_file "$TARGET"
    [ $? -ne 0 ] && FAILURES=$((FAILURES + 1)) || PROCESSED=$((PROCESSED + 1))
else
    # Process everything in to-process/
    FOUND=0
    for file in "$WATCH_DIR"/*; do
        [ -f "$file" ] || continue
        FOUND=$((FOUND + 1))
        process_file "$file"
        [ $? -ne 0 ] && FAILURES=$((FAILURES + 1)) || PROCESSED=$((PROCESSED + 1))
        echo ""
    done

    if [ $FOUND -eq 0 ]; then
        echo "📭 No files in to-process/ — nothing to do."
        exit 0
    fi
fi

echo "════════════════════════════════════════════════════════"
echo "📊 Processed: $PROCESSED  |  Failed: $FAILURES"
echo "════════════════════════════════════════════════════════"

[ $FAILURES -gt 0 ] && exit 1
exit 0
