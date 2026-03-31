#!/usr/bin/env python3
"""
Chunk Marker markdown output and store sections in SQLite.

Merges heading-based splitting (admin-style TOC chapters + h1/h2 fallback) and
CLI reference config-block splitting from the legacy LabSmith marker scripts.
"""

import argparse
import re
import sqlite3
import sys
from pathlib import Path


SCHEMA = """
CREATE TABLE IF NOT EXISTS chunks (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    workshop      TEXT NOT NULL,
    source_doc    TEXT NOT NULL,
    doc_type      TEXT NOT NULL,
    section_title TEXT NOT NULL,
    content       TEXT NOT NULL,
    line_count    INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_workshop ON chunks(workshop);
CREATE INDEX IF NOT EXISTS idx_doc_type ON chunks(doc_type);
CREATE INDEX IF NOT EXISTS idx_section_title ON chunks(section_title);
"""


def clean_markdown(content: str) -> str:
    """Clean up common pymupdf4llm conversion artifacts."""
    lines = content.split("\n")
    cleaned = []

    for line in lines:
        line = line.rstrip()

        stripped = line.strip()
        if stripped:
            pipe_ratio = stripped.count("|") / len(stripped)
            dash_ratio = stripped.count("-") / len(stripped)
            if pipe_ratio > 0.4 or (dash_ratio > 0.5 and "|" in stripped):
                cells = [c.strip() for c in stripped.split("|") if c.strip()]
                avg_cell_len = sum(len(c) for c in cells) / max(len(cells), 1) if cells else 0
                if avg_cell_len < 5:
                    continue

        cleaned.append(line)

    result = "\n".join(cleaned)
    result = re.sub(r"\n{4,}", "\n\n\n", result)

    return result


def find_toc_chapters(content: str):
    """Extract bold chapter names from the TOC section (admin guides)."""
    chapters = []

    toc_end = min(len(content), 50000)
    toc_text = content[:toc_end]

    skip_patterns = {
        "TABLE OF CONTENTS",
        "FORTINET",
        "CUSTOMER",
        "END USER",
        "FEEDBACK",
        "Administration Guide",
    }

    matches = re.findall(r"\*\*([A-Z][^*]{2,50})\*\*", toc_text)

    for match in matches:
        match = match.strip()
        if any(skip in match for skip in skip_patterns):
            continue
        if match.isupper() and len(match) > 20:
            continue
        if match not in chapters:
            chapters.append(match)

    return chapters


def find_chapter_lines(lines, chapters):
    """Map chapter names to body line numbers (## **Chapter** after line 500)."""
    chapter_starts = {}

    for i, line in enumerate(lines):
        stripped = line.strip()
        for chapter in chapters:
            if stripped == f"## **{chapter}**":
                if chapter not in chapter_starts and i > 500:
                    chapter_starts[chapter] = i

    return chapter_starts


def split_by_chapters(lines, chapter_starts):
    """Split content into chapter-based sections."""
    sections = []

    sorted_chapters = sorted(chapter_starts.items(), key=lambda x: x[1])

    if sorted_chapters and sorted_chapters[0][1] > 500:
        intro_content = "\n".join(lines[: sorted_chapters[0][1]])
        if len(intro_content.strip()) > 100:
            sections.append(
                {
                    "heading": "Introduction and Setup",
                    "content": intro_content,
                }
            )

    for i, (chapter, start_line) in enumerate(sorted_chapters):
        if i + 1 < len(sorted_chapters):
            end_line = sorted_chapters[i + 1][1]
        else:
            end_line = len(lines)

        content = "\n".join(lines[start_line:end_line])
        sections.append({"heading": chapter, "content": content})

    return sections


def extract_sections(content: str, min_lines: int = 10):
    """Split markdown by top-level # / ## headings."""
    sections = []
    current_heading = None
    current_lines = []

    for line in content.split("\n"):
        heading_match = re.match(r"^(#{1,2})\s+(.+)$", line)

        if heading_match:
            if current_heading and len(current_lines) >= min_lines:
                sections.append(
                    {
                        "heading": current_heading,
                        "content": "\n".join(current_lines),
                    }
                )

            current_heading = heading_match.group(2).strip()
            current_lines = [line]
        else:
            current_lines.append(line)

    if current_heading and len(current_lines) >= min_lines:
        sections.append(
            {
                "heading": current_heading,
                "content": "\n".join(current_lines),
            }
        )

    return sections


def extract_config_blocks(content: str):
    """
    FortiOS CLI reference: group by config category, diagnose/execute groups.
    Sub-headings stay inside their parent section.
    """
    lines = content.split("\n")
    sections = []
    current_heading = None
    current_type = None
    current_group = None
    current_lines = []

    skip_headings = {
        "fortios cli reference",
        "availability of commands and options",
        "fortigate model",
        "hardware configuration",
        "command tree",
        "cli configuration commands",
    }

    def save_current():
        if current_heading and len(current_lines) > 3:
            sections.append(
                {"heading": current_heading, "content": "\n".join(current_lines)}
            )

    for line in lines:
        heading_match = re.match(r"^##\s+\*\*([^*]+)\*\*\s*$", line)

        if not heading_match:
            current_lines.append(line)
            continue

        heading_text = heading_match.group(1).strip()
        heading_lower = heading_text.lower()

        if heading_lower in skip_headings or "fortigate" in heading_lower or "fortios" in heading_lower:
            current_lines.append(line)
            continue

        if heading_lower.startswith("config "):
            current_lines.append(line)

        elif heading_lower.startswith("diagnose "):
            parts = heading_lower.split()
            group_key = parts[1] if len(parts) > 1 else "general"

            if current_type == "diagnose" and current_group == group_key:
                current_lines.append(line)
            else:
                save_current()
                current_heading = f"diagnose {group_key}"
                current_type = "diagnose"
                current_group = group_key
                current_lines = [line]

        elif heading_lower.startswith("execute "):
            parts = heading_lower.split()
            group_key = parts[1] if len(parts) > 1 else "general"

            if current_type == "execute" and current_group == group_key:
                current_lines.append(line)
            else:
                save_current()
                current_heading = f"execute {group_key}"
                current_type = "execute"
                current_group = group_key
                current_lines = [line]

        else:
            save_current()
            current_heading = heading_text
            current_type = "config"
            current_group = heading_lower
            current_lines = [line]

    save_current()

    return sections


def init_db(conn: sqlite3.Connection) -> None:
    conn.executescript(SCHEMA)
    conn.commit()


def split_general(raw_content: str, cleaned: str):
    """Admin-style chapter split when TOC matches body; else h1/h2 sections."""
    lines = cleaned.split("\n")
    chapters = find_toc_chapters(raw_content)
    chapter_starts = find_chapter_lines(lines, chapters)

    if chapter_starts:
        return split_by_chapters(lines, chapter_starts)

    sections = extract_sections(cleaned, min_lines=5)
    if sections:
        return sections

    stripped = cleaned.strip()
    if not stripped:
        return []
    return [{"heading": "Document", "content": cleaned}]


def main() -> None:
    parser = argparse.ArgumentParser(description="Chunk markdown into labsmith.db")
    parser.add_argument("input", type=Path, help="Input .md file")
    parser.add_argument("--workshop", required=True, help="Workshop tag (e.g. cisco-to-fortinet)")
    parser.add_argument("--doc-type", required=True, dest="doc_type", help="admin, cli, datasheet, ...")
    parser.add_argument("--db", default="labsmith.db", help="SQLite database path")
    args = parser.parse_args()

    input_path: Path = args.input
    if not input_path.is_file():
        print(f"Error: {input_path} not found", file=sys.stderr)
        sys.exit(1)

    raw_content = input_path.read_text(encoding="utf-8")
    cleaned = clean_markdown(raw_content)

    if args.doc_type == "cli":
        sections = extract_config_blocks(cleaned)
    else:
        sections = split_general(raw_content, cleaned)

    if not sections:
        print("No sections extracted; nothing inserted.", file=sys.stderr)
        sys.exit(1)

    source_doc = input_path.name
    conn = sqlite3.connect(args.db)
    try:
        init_db(conn)
        cur = conn.cursor()
        cur.execute(
            "DELETE FROM chunks WHERE workshop = ? AND source_doc = ?",
            (args.workshop, source_doc),
        )

        total_lines = 0
        inserted = 0
        for sec in sections:
            title = sec["heading"] or "Untitled"
            body = sec["content"]
            line_count = len(body.split("\n"))
            if not body.strip():
                continue
            cur.execute(
                """
                INSERT INTO chunks (workshop, source_doc, doc_type, section_title, content, line_count)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (args.workshop, source_doc, args.doc_type, title, body, line_count),
            )
            total_lines += line_count
            inserted += 1

        if inserted == 0:
            conn.rollback()
            print("No non-empty sections to insert.", file=sys.stderr)
            sys.exit(1)

        conn.commit()
    finally:
        conn.close()
    avg = total_lines / inserted if inserted else 0
    print(f"Chunks inserted: {inserted}")
    print(f"Total lines (sum of chunks): {total_lines}")
    print(f"Average chunk size (lines): {avg:.1f}")


if __name__ == "__main__":
    main()
