"""SQLite helpers for workshop lists and defaults (read-only)."""

from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import List, Optional, Tuple


def db_exists(db_path: Path) -> bool:
    return db_path.is_file()


def list_workshops(db_path: Path) -> List[str]:
    if not db_exists(db_path):
        return []
    conn = sqlite3.connect(str(db_path))
    try:
        rows = conn.execute(
            "SELECT DISTINCT workshop FROM chunks ORDER BY workshop COLLATE NOCASE"
        ).fetchall()
        return [r[0] for r in rows if r[0]]
    except sqlite3.Error:
        return []
    finally:
        conn.close()


def default_workshop(db_path: Path) -> str:
    """Workshop with the highest chunk id (most recently inserted activity)."""
    if not db_exists(db_path):
        return ""
    conn = sqlite3.connect(str(db_path))
    try:
        row = conn.execute(
            "SELECT workshop FROM chunks GROUP BY workshop "
            "ORDER BY MAX(id) DESC LIMIT 1"
        ).fetchone()
        return row[0] if row and row[0] else ""
    except sqlite3.Error:
        return ""
    finally:
        conn.close()


def chunk_stats(db_path: Path) -> Tuple[int, int]:
    """Total chunks and sum of line_count."""
    if not db_exists(db_path):
        return 0, 0
    conn = sqlite3.connect(str(db_path))
    try:
        row = conn.execute(
            "SELECT COUNT(*), COALESCE(SUM(line_count), 0) FROM chunks"
        ).fetchone()
        if row:
            return int(row[0]), int(row[1])
    except sqlite3.Error:
        pass
    finally:
        conn.close()
    return 0, 0


def db_file_size(db_path: Path) -> Optional[int]:
    if not db_exists(db_path):
        return None
    try:
        return db_path.stat().st_size
    except OSError:
        return None
