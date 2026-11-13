"""DDInter 2.0 (CSV-urile descărcabile) + interacțiunile curate → tabelele drug, ddi, dfi, duplication."""

from __future__ import annotations

import csv
import sqlite3
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

from common import KB_DIR, RAW_DIR, norm

DDINTER_DIR = RAW_DIR / "ddinter"
LEVELS = ("Contraindicated", "Major", "Moderate", "Minor", "Unknown")
_RANK = {lvl: i for i, lvl in enumerate(LEVELS)}


@dataclass
class DDInterData:
    drugs: dict[str, str] = field(default_factory=dict)  # DDInterID → nume (engleză)
    pairs: dict[tuple[str, str], str] = field(default_factory=dict)  # (id mic, id mare) → nivel
    rows: int = 0
    conflicts: int = 0


def load_ddinter(directory: Path = DDINTER_DIR) -> DDInterData:
    files = sorted(directory.glob("ddinter_downloads_code_*.csv"))
    if not files:
        raise SystemExit(f"Lipsesc CSV-urile DDInter în {directory} (vezi README-ul de acolo).")
    data = DDInterData()
    for path in files:
        with path.open(encoding="utf-8-sig", newline="") as fh:
            for row in csv.DictReader(fh):
                a, b = row["DDInterID_A"].strip(), row["DDInterID_B"].strip()
                level = row["Level"].strip()
                if level not in _RANK:
                    raise ValueError(f"{path.name}: nivel necunoscut {level!r}")
                data.drugs[a] = row["Drug_A"].strip()
                data.drugs[b] = row["Drug_B"].strip()
                data.rows += 1
                key = (a, b) if _id_num(a) < _id_num(b) else (b, a)
                old = data.pairs.get(key)
                if old is None:
                    data.pairs[key] = level
                elif old != level:
                    data.conflicts += 1
                    # aceeași pereche cu niveluri diferite în două fișiere: păstrăm nivelul cel mai grav
                    if _RANK[level] < _RANK[old]:
                        data.pairs[key] = level
    return data


def _id_num(ddinter_id: str) -> int:
    return int(ddinter_id.removeprefix("DDInter"))


def write_drugs(conn: sqlite3.Connection, data: DDInterData) -> None:
    conn.executemany(
        "INSERT INTO drug(ddinter_id, name) VALUES (?, ?)",
        sorted(data.drugs.items(), key=lambda kv: _id_num(kv[0])),
    )


def write_ddi(conn: sqlite3.Connection, data: DDInterData, sub_by_ddinter: dict[str, int]) -> None:
    rows = []
    for (a, b), level in data.pairs.items():
        sa, sb = sub_by_ddinter[a], sub_by_ddinter[b]
        lo, hi = (sa, sb) if sa < sb else (sb, sa)
        rows.append((lo, hi, level, None, None, f"{a} – {b}", "ddinter", "direct", None, None, level))
    conn.executemany(
        "INSERT INTO ddi(a_id, b_id, level, mechanism, management, ref, source, basis, analogy_via, source_url, ddinter_level)"
        " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        rows,
    )


def _dash(value: str | None) -> str | None:
    value = (value or "").strip()
    return None if value in ("", "-") else value


def apply_curated_ddi(conn: sqlite3.Connection, sub_by_inn: dict[str, int], path: Path = KB_DIR / "curated_ddi.csv") -> int:
    """Rândurile curate au prioritate: înlocuiesc nivelul și textele DDInter, păstrând nivelul original."""
    count = 0
    with path.open(encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            a, b = sub_by_inn[norm(row["drug_a"])], sub_by_inn[norm(row["drug_b"])]
            lo, hi = (a, b) if a < b else (b, a)
            level = row["level"].strip()
            if level not in _RANK:
                raise ValueError(f"curated_ddi.csv: nivel necunoscut {level!r}")
            old = conn.execute("SELECT ddinter_level FROM ddi WHERE a_id = ? AND b_id = ?", (lo, hi)).fetchone()
            conn.execute("DELETE FROM ddi WHERE a_id = ? AND b_id = ?", (lo, hi))
            conn.execute(
                "INSERT INTO ddi(a_id, b_id, level, mechanism, management, ref, source, basis, analogy_via, source_url,"
                " ddinter_level, needs_check, checked_by) VALUES (?, ?, ?, ?, ?, ?, 'curated', ?, ?, ?, ?, ?, ?)",
                (
                    lo,
                    hi,
                    level,
                    _dash(row["mechanism_ro"]),
                    _dash(row["management_ro"]),
                    row["source"].strip(),
                    row["basis"].strip() or "curated",
                    _dash(row["analogy_via"]),
                    _dash(row["source_url"]),
                    old[0] if old else None,
                    _dash(row["needs_check"]),
                    _dash(row["checked_by"]),
                ),
            )
            count += 1
    return count


def apply_curated_dfi(
    conn: sqlite3.Connection, sub_by_inn: dict[str, int], food_key_for, path: Path = KB_DIR / "curated_dfi.csv"
) -> tuple[int, Counter]:
    """DDInter descărcabil nu are alimente: dfi vine doar din curated_dfi.csv. Rândurile fără nivel sunt note."""
    count, skipped = 0, Counter()
    with path.open(encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            level = row["level"].strip()
            if not level:
                skipped["fără nivel (notă)"] += 1
                continue
            if level not in _RANK:
                raise ValueError(f"curated_dfi.csv: nivel necunoscut {level!r}")
            conn.execute(
                "INSERT INTO dfi(substance_id, food, food_ro, level, description, management, basis, source, source_url,"
                " needs_check) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    sub_by_inn[norm(row["drug"])],
                    food_key_for(row["food_ro"]),
                    row["food_ro"].strip(),
                    level,
                    _dash(row["effect_ro"]),
                    _dash(row["management_ro"]),
                    row["basis"].strip(),
                    row["source"].strip(),
                    _dash(row["source_url"]),
                    _dash(row["needs_check"]),
                ),
            )
            count += 1
    return count, skipped
