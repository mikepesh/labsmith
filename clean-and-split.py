#!/usr/bin/env python3
"""
Admin Guide Post-Processor & Chapter Splitter

Cleans up pymupdf4llm markdown output and splits by chapter headings.
Works with any Fortinet doc that has bold chapter headings in a TOC.

Usage:
    python3 clean-and-split.py <input.md> <output-dir> [--prefix admin]

Examples:
    python3 clean-and-split.py FortiOS-7.6.6-Administration_Guide.md references/fortios-7.6/ --prefix admin
"""

import sys
import re
from pathlib import Path


def slugify(text):
    """Convert heading text to a filename-safe slug."""
    text = text.lower().strip()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_]+', '-', text)
    text = re.sub(r'-+', '-', text)
    return text.strip('-')


def clean_markdown(content):
    """Clean up common pymupdf4llm conversion artifacts."""
    lines = content.split('\n')
    cleaned = []

    for line in lines:
        # Strip trailing whitespace (the main culprit)
        line = line.rstrip()

        # Skip lines that are mostly pipes/dashes (mangled TOC tables)
        stripped = line.strip()
        if stripped:
            pipe_ratio = stripped.count('|') / len(stripped)
            dash_ratio = stripped.count('-') / len(stripped)
            if pipe_ratio > 0.4 or (dash_ratio > 0.5 and '|' in stripped):
                # But keep legitimate data tables (those with actual content between pipes)
                cells = [c.strip() for c in stripped.split('|') if c.strip()]
                avg_cell_len = sum(len(c) for c in cells) / max(len(cells), 1) if cells else 0
                if avg_cell_len < 5:
                    continue  # Skip TOC junk

        cleaned.append(line)

    # Collapse excessive blank lines (3+ → 2)
    result = '\n'.join(cleaned)
    result = re.sub(r'\n{4,}', '\n\n\n', result)

    return result


def find_toc_chapters(content):
    """
    Extract bold chapter names from the TOC section.
    Looks for **ChapterName** patterns where ChapterName starts with uppercase.
    Returns list of chapter names.
    """
    chapters = []

    # Find TOC section (usually near the top, before main content)
    toc_end = min(len(content), 50000)  # TOC should be in first ~50K chars
    toc_text = content[:toc_end]

    # Find bold chapter headings in TOC: **Name** where Name starts with uppercase
    # and is NOT a known non-chapter heading
    skip_patterns = {
        'TABLE OF CONTENTS', 'FORTINET', 'CUSTOMER', 'END USER',
        'FEEDBACK', 'Administration Guide'
    }

    matches = re.findall(r'\*\*([A-Z][^*]{2,50})\*\*', toc_text)

    for match in matches:
        match = match.strip()
        if any(skip in match for skip in skip_patterns):
            continue
        if match.isupper() and len(match) > 20:
            continue  # Skip all-caps long strings (likely front matter)
        if match not in chapters:
            chapters.append(match)

    return chapters


def find_chapter_lines(lines, chapters):
    """
    Find the line numbers where each chapter starts in the document body.
    Matches ## **Chapter Name** with possible trailing whitespace.
    Returns dict of {chapter_name: line_number}
    """
    chapter_starts = {}

    for i, line in enumerate(lines):
        stripped = line.strip()
        for chapter in chapters:
            # Match with possible trailing whitespace
            if stripped == f'## **{chapter}**':
                # Only take the first occurrence after line 500 (skip TOC)
                if chapter not in chapter_starts and i > 500:
                    chapter_starts[chapter] = i

    return chapter_starts


def split_by_chapters(lines, chapter_starts, prefix):
    """Split content into chapter-based sections."""
    sections = []

    # Sort chapters by line number
    sorted_chapters = sorted(chapter_starts.items(), key=lambda x: x[1])

    # Add content before first chapter as "intro"
    if sorted_chapters and sorted_chapters[0][1] > 500:
        intro_content = '\n'.join(lines[:sorted_chapters[0][1]])
        if len(intro_content.strip()) > 100:
            sections.append({
                'heading': 'Introduction and Setup',
                'content': intro_content
            })

    # Split between chapters
    for i, (chapter, start_line) in enumerate(sorted_chapters):
        if i + 1 < len(sorted_chapters):
            end_line = sorted_chapters[i + 1][1]
        else:
            end_line = len(lines)

        content = '\n'.join(lines[start_line:end_line])
        sections.append({
            'heading': chapter,
            'content': content
        })

    return sections


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 clean-and-split.py <input.md> <output-dir> [--prefix admin]")
        print("")
        print("Examples:")
        print("  python3 clean-and-split.py FortiOS-7.6.6-Administration_Guide.md refs/ --prefix admin")
        sys.exit(1)

    input_file = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    prefix = "admin"

    if "--prefix" in sys.argv:
        idx = sys.argv.index("--prefix")
        if idx + 1 < len(sys.argv):
            prefix = sys.argv[idx + 1]

    if not input_file.exists():
        print(f"Error: {input_file} not found")
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    # Read and clean
    print(f"Reading: {input_file}")
    raw_content = input_file.read_text(encoding='utf-8')
    total_lines_raw = len(raw_content.split('\n'))
    print(f"Raw lines: {total_lines_raw}")

    print("Cleaning markdown...")
    content = clean_markdown(raw_content)
    lines = content.split('\n')
    print(f"Cleaned lines: {len(lines)}")

    # Find chapters from TOC
    print("Scanning TOC for chapter headings...")
    chapters = find_toc_chapters(raw_content)
    print(f"Found {len(chapters)} chapter headings in TOC:")
    for ch in chapters:
        print(f"  - {ch}")

    # Find where chapters start in body
    print("\nLocating chapters in document body...")
    chapter_starts = find_chapter_lines(lines, chapters)
    print(f"Matched {len(chapter_starts)} chapters to line numbers:")
    for ch, line_num in sorted(chapter_starts.items(), key=lambda x: x[1]):
        print(f"  Line {line_num}: {ch}")

    # Report missing chapters
    missing = [ch for ch in chapters if ch not in chapter_starts]
    if missing:
        print(f"\n⚠️  {len(missing)} chapters not found in body (may be sub-sections in TOC):")
        for ch in missing:
            print(f"  - {ch}")

    # Split
    print("\nSplitting by chapters...")
    sections = split_by_chapters(lines, chapter_starts, prefix)

    # Write files
    written = 0
    manifest = []

    for section in sections:
        slug = slugify(section['heading'])
        if not slug:
            continue

        filename = f"{prefix}-{slug}.md"
        filepath = output_dir / filename
        line_count = len(section['content'].split('\n'))

        filepath.write_text(section['content'], encoding='utf-8')
        written += 1
        manifest.append({
            'file': filename,
            'heading': section['heading'],
            'lines': line_count
        })
        print(f"  ✅ {filename} ({line_count} lines)")

    # Write manifest
    manifest_path = output_dir / f"{prefix}-manifest.md"
    manifest_lines = [f"# {prefix.upper()} Reference Manifest\n"]
    manifest_lines.append(f"Source: {input_file.name}\n")
    manifest_lines.append(f"Extracted: {written} sections\n\n")
    manifest_lines.append("| File | Section | Lines |")
    manifest_lines.append("|------|---------|-------|")
    for entry in manifest:
        manifest_lines.append(f"| {entry['file']} | {entry['heading']} | {entry['lines']} |")

    manifest_path.write_text('\n'.join(manifest_lines), encoding='utf-8')

    # Verify line coverage
    total_extracted = sum(e['lines'] for e in manifest)
    print(f"\nWritten: {written} files to {output_dir}/")
    print(f"Manifest: {manifest_path}")
    print(f"Lines: {total_extracted} extracted / {len(lines)} total ({total_extracted * 100 // len(lines)}%)")

    # Module mapping hints
    print("\n=== Suggested Module Mappings ===")
    module_map = {
        'Getting started': 'Module 01',
        'Network': 'Module 02',
        'Interfaces': 'Module 02',
        'Policy and Objects': 'Module 03',
        'Security Profiles': 'Module 08',
        'SD-WAN': 'Module 09 (future)',
        'IPsec VPN': 'Module 07',
        'Agentless VPN': 'Module 07',
        'Log and Report': 'Module 08',
        'Switch Controller': 'Module 05',
        'Wireless configuration': 'Module 06',
        'System': 'Module 01',
        'User & Authentication': 'Module 17 (future)',
        'Zero Trust Network Access': 'Module 13 (future)',
        'WAN optimization': 'Reference',
        'VM': 'Reference',
        'Hyperscale firewall': 'Reference',
        'Troubleshooting': 'Module 08',
        'Dashboards and Monitors': 'Module 01',
        'Fortinet Security Fabric': 'Module 14 (future)',
    }
    for entry in manifest:
        if entry['heading'] in module_map:
            print(f"  {entry['file']} → {module_map[entry['heading']]}")


if __name__ == "__main__":
    main()
