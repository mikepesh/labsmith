#!/usr/bin/env python3
"""
Search and retrieve chunks from labsmith.db for Cowork / CLI use.
"""

import argparse
import sqlite3
import sys
from pathlib import Path
from typing import List, Optional


def connect(db_path: str) -> sqlite3.Connection:
    p = Path(db_path)
    if not p.is_file():
        print(f"Error: database not found: {db_path}", file=sys.stderr)
        sys.exit(1)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


def like_fragments(keyword: str):
    """Build LIKE patterns for case-insensitive search (escape % and _)."""
    esc = keyword.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    pat = f"%{esc.lower()}%"
    return pat, pat


def cmd_search(conn, keyword: str, workshop: Optional[str], doc_type: Optional[str]) -> None:
    p1, p2 = like_fragments(keyword)
    sql = (
        "SELECT id, section_title, source_doc, doc_type, line_count FROM chunks "
        "WHERE (lower(section_title) LIKE ? ESCAPE '\\' OR lower(content) LIKE ? ESCAPE '\\')"
    )
    params: list = [p1, p2]
    if workshop:
        sql += " AND workshop = ?"
        params.append(workshop)
    if doc_type:
        sql += " AND doc_type = ?"
        params.append(doc_type)
    sql += " ORDER BY source_doc, id LIMIT 50"

    rows = conn.execute(sql, params).fetchall()
    for row in rows:
        print(
            f"{row['id']}\t{row['section_title']}\t{row['source_doc']}\t"
            f"{row['doc_type']}\t{row['line_count']}"
        )
    print(f"count={len(rows)}")


def cmd_list(conn, workshop: Optional[str]) -> None:
    sql = """
        SELECT id, section_title, source_doc, doc_type, line_count, workshop
        FROM chunks
        """
    params: list = []
    if workshop:
        sql += " WHERE workshop = ?"
        params.append(workshop)
    sql += " ORDER BY workshop, source_doc, id" if not workshop else " ORDER BY source_doc, id"
    rows = conn.execute(sql, params).fetchall()
    for row in rows:
        if workshop:
            print(
                f"{row['id']}\t{row['section_title']}\t{row['source_doc']}\t"
                f"{row['doc_type']}\t{row['line_count']}"
            )
        else:
            print(
                f"{row['id']}\t{row['workshop']}\t{row['section_title']}\t{row['source_doc']}\t"
                f"{row['doc_type']}\t{row['line_count']}"
            )
    print(f"count={len(rows)}")


def cmd_get(conn, ids: List[int]) -> None:
    placeholders = ",".join("?" * len(ids))
    rows = conn.execute(
        f"SELECT id, workshop, source_doc, doc_type, section_title, line_count, content "
        f"FROM chunks WHERE id IN ({placeholders}) ORDER BY id",
        ids,
    ).fetchall()
    found = {row["id"] for row in rows}
    missing = [i for i in ids if i not in found]
    if missing:
        print(f"Missing ids: {missing}", file=sys.stderr)

    for row in rows:
        print(f"--- chunk id={row['id']} workshop={row['workshop']} "
              f"source_doc={row['source_doc']} doc_type={row['doc_type']} "
              f"section_title={row['section_title']} line_count={row['line_count']}")
        print(row["content"])
        print()


def cmd_stats(conn, workshop: Optional[str]) -> None:
    if workshop:
        total = conn.execute(
            "SELECT COUNT(*) AS c, COALESCE(SUM(line_count), 0) AS lines FROM chunks WHERE workshop = ?",
            (workshop,),
        ).fetchone()
        by_type = conn.execute(
            "SELECT doc_type, COUNT(*) AS c, SUM(line_count) AS lines "
            "FROM chunks WHERE workshop = ? GROUP BY doc_type ORDER BY doc_type",
            (workshop,),
        ).fetchall()
    else:
        total = conn.execute(
            "SELECT COUNT(*) AS c, COALESCE(SUM(line_count), 0) AS lines FROM chunks",
        ).fetchone()
        by_type = conn.execute(
            "SELECT doc_type, COUNT(*) AS c, SUM(line_count) AS lines "
            "FROM chunks GROUP BY doc_type ORDER BY doc_type",
        ).fetchall()

    print(f"workshop={workshop if workshop else 'all'}")
    print(f"chunks={total['c']}")
    print(f"total_lines={total['lines']}")
    print("by_doc_type:")
    for row in by_type:
        print(f"  {row['doc_type']}\tchunks={row['c']}\tlines={row['lines']}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Query LabSmith chunk database")
    parser.add_argument("--db", default="labsmith.db", help="SQLite database path")

    sub = parser.add_subparsers(dest="command", required=True)

    p_search = sub.add_parser("search", help="Search section titles and content")
    p_search.add_argument("keyword", help="Search string")
    p_search.add_argument("--workshop", default=None)
    p_search.add_argument("--doc-type", dest="doc_type", default=None)

    p_list = sub.add_parser("list", help="List chunk summaries (optional workshop filter)")
    p_list.add_argument("--workshop", default=None)

    p_get = sub.add_parser("get", help="Fetch full chunk content by id")
    p_get.add_argument("ids", type=int, nargs="+", help="Chunk id(s)")

    p_stats = sub.add_parser("stats", help="Chunk counts and line totals")
    p_stats.add_argument("--workshop", default=None)

    args = parser.parse_args()
    conn = connect(args.db)
    try:
        if args.command == "search":
            cmd_search(conn, args.keyword, args.workshop, args.doc_type)
        elif args.command == "list":
            cmd_list(conn, args.workshop)
        elif args.command == "get":
            cmd_get(conn, args.ids)
        elif args.command == "stats":
            cmd_stats(conn, args.workshop)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
