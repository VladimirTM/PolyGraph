"""Accesul read-only la kb/kb.sqlite (construit de B1 cu `make kb`).

Singurul loc din backend care citește baza de cunoștințe. Calea se poate schimba cu PG_KB (teste, demo).
Interogările sunt mici și repetate (aceleași perechi la fiecare analiză), deci sunt memorate per instanță.
"""

from __future__ import annotations

import json
import os
import re
import sqlite3
import threading
import unicodedata
from dataclasses import dataclass
from functools import cache
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_KB = ROOT / "kb" / "kb.sqlite"

LEVELS = ("Contraindicated", "Major", "Moderate", "Minor", "Unknown")
SEVERITY_OF_LEVEL = {"Contraindicated": "critical", "Major": "major", "Moderate": "moderate", "Minor": "minor"}
SEV_RANK = {"critical": 0, "major": 1, "moderate": 2, "minor": 3, "info": 4}


class KbMissing(RuntimeError):
    pass


def norm(text: str | None) -> str:
    """Litere mici, fără diacritice, doar litere / cifre / spații (ca kb/common.norm)."""
    if not text:
        return ""
    text = "".join(c for c in unicodedata.normalize("NFKD", text) if not unicodedata.combining(c)).lower()
    text = re.sub(r"[^a-z0-9]+", " ", text.replace("µ", "u"))
    return re.sub(r"\s+", " ", text).strip()


@dataclass(frozen=True)
class Substance:
    id: int
    inn: str
    dci_ro: str | None
    atc: str | None
    ddinter_id: str | None

    @property
    def atc4(self) -> str | None:
        return self.atc[:5] if self.atc and len(self.atc) >= 5 else None


@dataclass(frozen=True)
class Ddi:
    level: str
    source: str  # ddinter | curated
    basis: str | None
    analogy_via: str | None
    mechanism: str | None
    management: str | None
    ref: str | None
    source_url: str | None


class Kb:
    def __init__(self, path: Path | str | None = None):
        self.path = Path(path or os.environ.get("PG_KB") or DEFAULT_KB)
        if not self.path.exists():
            raise KbMissing(f"{self.path} nu există (make kb)")
        self._local = threading.local()
        self.meta = dict(self._q("SELECT key, value FROM kb_meta"))
        self.age_min = int(self.meta.get("elderly_age_min", 65))
        self.acb_threshold = int(self.meta.get("acb_threshold_alert", 3))
        self.elderly_rules = [
            {**json.loads(spec), "severity": sev, "title": t, "detail": d, "recommendation": r, "source": s}
            for sev, t, d, r, s, spec in self._q(
                "SELECT severity, title, detail, recommendation, source, spec FROM elderly_rule ORDER BY rowid"
            )
        ]
        self.acb_by_sub: dict[int, int] = {}
        self.acb_by_inn: dict[str, int] = {}
        for inn, sid, score in self._q("SELECT inn, substance_id, score FROM acb"):
            self.acb_by_inn[inn] = max(score, self.acb_by_inn.get(inn, 0))
            if sid is not None:
                self.acb_by_sub[sid] = max(score, self.acb_by_sub.get(sid, 0))
        self.foods = {
            k: {"label_ro": label, "synonyms": json.loads(syn)}
            for k, label, syn in self._q("SELECT key, label_ro, synonyms FROM food_alias")
        }
        self.timing: dict[int, dict[str, Any]] = {}
        for sid, spec in self._q("SELECT substance_id, spec FROM timing_rule WHERE substance_id IS NOT NULL"):
            self.timing[sid] = json.loads(spec)
        self.adverse: dict[int, set[str]] = {}
        for sid, code in self._q("SELECT substance_id, symptom_code FROM adverse_effect WHERE substance_id IS NOT NULL"):
            self.adverse.setdefault(sid, set()).add(code)
        self.duplication = {frozenset((a, b)): note for a, b, note in self._q("SELECT a_id, b_id, note FROM duplication")}

    # ------------------------------------------------------------------ conexiunea

    def _conn(self) -> sqlite3.Connection:
        conn = getattr(self._local, "conn", None)
        if conn is None:
            conn = sqlite3.connect(f"file:{self.path}?mode=ro", uri=True, check_same_thread=False)
            self._local.conn = conn
        return conn

    def _q(self, sql: str, args: tuple = ()) -> list[tuple]:
        return self._conn().execute(sql, args).fetchall()

    # ------------------------------------------------------------------ substanțe

    def substance(self, sid: int) -> Substance | None:
        return self._substance(sid)

    @cache  # noqa: B019  (instanța Kb trăiește cât procesul)
    def _substance(self, sid: int) -> Substance | None:
        row = self._q("SELECT id, inn, dci_ro, atc, ddinter_id FROM substance WHERE id = ?", (sid,))
        return Substance(*row[0]) if row else None

    @cache  # noqa: B019
    def resolve(self, inn: str | None, dci: str | None, atc: str | None) -> Substance | None:
        """Substanța din kb pentru o componentă din MedicationItem: INN → DCI → ATC5; cele legate la DDInter primele."""
        cols = "id, inn, dci_ro, atc, ddinter_id"
        order = " ORDER BY ddinter_id IS NULL, id LIMIT 1"
        if inn:
            row = self._q(f"SELECT {cols} FROM substance WHERE inn = ?{order}", (norm(inn),))
            if row:
                return Substance(*row[0])
        if dci:
            key = re.sub(r"\s+", " ", "".join(c for c in unicodedata.normalize("NFKD", dci) if not unicodedata.combining(c)))
            key = key.upper().strip(" .,;")
            row = self._q(
                f"SELECT {cols} FROM substance WHERE dci_ro = ?"
                f" OR EXISTS (SELECT 1 FROM json_each(substance.synonyms) WHERE value = ?){order}",
                (key, key),
            )
            if row:
                return Substance(*row[0])
        if atc:
            row = self._q(f"SELECT {cols} FROM substance WHERE atc = ?{order}", (atc,))
            if row:
                return Substance(*row[0])
        return None

    @cache  # noqa: B019
    def class_members(self, atc4: str) -> tuple[Substance, ...]:
        """Substanțele legate la DDInter din aceeași clasă ATC nivel 4 (pentru regula de clasă)."""
        rows = self._q(
            "SELECT id, inn, dci_ro, atc, ddinter_id FROM substance"
            " WHERE ddinter_id IS NOT NULL AND substr(atc, 1, 5) = ? ORDER BY inn",
            (atc4,),
        )
        return tuple(Substance(*r) for r in rows)

    # ------------------------------------------------------------------ interacțiuni

    @cache  # noqa: B019
    def ddi(self, a: int, b: int) -> Ddi | None:
        lo, hi = (a, b) if a < b else (b, a)
        row = self._q(
            "SELECT level, source, basis, analogy_via, mechanism, management, ref, source_url FROM ddi"
            " WHERE a_id = ? AND b_id = ?",
            (lo, hi),
        )
        return Ddi(*row[0]) if row else None

    @cache  # noqa: B019
    def dfi(self, sid: int) -> tuple[dict[str, Any], ...]:
        rows = self._q(
            "SELECT food, food_ro, level, description, management, basis, source, source_url FROM dfi"
            " WHERE substance_id = ? ORDER BY food",
            (sid,),
        )
        keys = ("food", "food_ro", "level", "description", "management", "basis", "source", "source_url")
        return tuple(dict(zip(keys, r, strict=True)) for r in rows)

    # ------------------------------------------------------------------ căutare (autocomplete, what-if)

    def search(self, q: str, limit: int = 20) -> list[dict[str, Any]]:
        """Produse după brand (prefix) sau după substanță (INN / DCI). Fiecare cu substanțele din kb."""
        key = norm(q)
        if len(key) < 2:
            return []
        rows = self._q(
            "SELECT p.id, p.brand, p.strength_text, p.form FROM product p WHERE p.brand_norm LIKE ? || '%'"
            " ORDER BY (p.brand_norm = ?) DESC, p.source = 'extra' DESC, length(p.brand_norm), p.brand LIMIT ?",
            (key, key, limit),
        )
        if len(rows) < limit:
            seen = {r[0] for r in rows}
            more = self._q(
                "SELECT DISTINCT p.id, p.brand, p.strength_text, p.form FROM product p"
                " JOIN product_substance ps ON ps.product_id = p.id JOIN substance s ON s.id = ps.substance_id"
                " WHERE s.inn LIKE ? || '%' OR lower(s.dci_ro) LIKE ? || '%' ORDER BY length(p.brand), p.brand LIMIT ?",
                (key, key, limit),
            )
            rows += [r for r in more if r[0] not in seen][: limit - len(rows)]
        out = []
        for pid, brand, strength, form in rows:
            subs = self._q(
                "SELECT s.dci_ro, s.inn, s.atc FROM product_substance ps JOIN substance s ON s.id = ps.substance_id"
                " WHERE ps.product_id = ? ORDER BY s.inn",
                (pid,),
            )
            out.append(
                {
                    "brand": brand,
                    "strength_text": strength,
                    "form": form,
                    "substances": [
                        {
                            "dci": d,
                            "inn": i,
                            "atc": a if a and re.fullmatch(r"[A-Z]\d\d[A-Z]{2}\d\d", a) else None,
                            "strength_mg": None,
                        }
                        for d, i, a in subs
                    ],
                }
            )
        return out


_DEFAULT: Kb | None = None


def default_kb() -> Kb:
    global _DEFAULT
    if _DEFAULT is None:
        _DEFAULT = Kb()
    return _DEFAULT
