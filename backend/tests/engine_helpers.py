"""Utilitare comune pentru testele motorului (B2): pacientul demo, cheia de comparație, o kb sintetică mică."""

from __future__ import annotations

import copy
import json
import sqlite3
from datetime import date
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
FIX = ROOT / "contracts" / "fixtures"
KB_PATH = ROOT / "kb" / "kb.sqlite"
TODAY = date(2026, 11, 14)

DEMO = json.loads((FIX / "demo_patient.json").read_text(encoding="utf-8"))
MED_09 = json.loads((FIX / "med_09_fromilid.json").read_text(encoding="utf-8"))
EXPECTED = json.loads((FIX / "expected_alerts.json").read_text(encoding="utf-8"))


def demo():
    return copy.deepcopy(DEMO["patient"]), copy.deepcopy(DEMO["meds"])


def key(a: dict) -> tuple:
    """Golden-ul compară (kind, severity, sorted(med_ids), basis) (fixtures/README.md)."""
    return (a["kind"], a["severity"], tuple(sorted(a["med_ids"])), a["basis"])


def real_kb():
    if not KB_PATH.exists():
        pytest.skip("kb/kb.sqlite nu e construit (make kb; datele brute nu sunt în CI)")
    from polygraph.kb import Kb

    return Kb(KB_PATH)


def med(mid: str, brand: str, inn: str, atc: str, *, start="2026-01-01", end=None, expiry=None, specialty="medicină de familie"):
    return {
        "id": mid,
        "source": "manual",
        "product": {
            "brand": brand,
            "strength_text": None,
            "form": None,
            "gtin": None,
            "pack_size": None,
            "expiry": expiry,
            "batch": None,
        },
        "substances": [{"dci": None, "inn": inn, "atc": atc, "strength_mg": None}],
        "dosage": {
            "raw": "1-0-0",
            "pattern": {"morning": 1, "noon": 0, "evening": 0, "bedtime": 0},
            "as_needed": False,
            "with_food": "any",
        },
        "prescriber": {"name": None, "specialty": specialty},
        "start_date": start,
        "end_date": end,
        "photo_url": None,
        "match": {"method": "manual", "confidence": 1.0, "needs_review": False},
    }


# Substanțe sintetice: (id, inn, dci, atc, ddinter_id)
MINI_SUBSTANCES = [
    (1, "acenocoumarol", "ACENOCUMAROLUM", "B01AA07", "D1"),
    (2, "warfarin", "WARFARINUM", "B01AA03", "D2"),
    (3, "omeprazole", "OMEPRAZOLUM", "A02BC01", "D3"),
    (4, "simvastatin", "SIMVASTATINUM", "C10AA01", "D4"),
    (5, "amlodipine", "AMLODIPINUM", "C08CA01", "D5"),
    (6, "ibuprofen", "IBUPROFENUM", "M01AE01", "D6"),
    (7, "naproxen", "NAPROXENUM", "M01AE02", "D7"),
    (8, "esomeprazole", "ESOMEPRAZOLUM", "A02BC05", "D8"),
]
# (a, b, level, source, basis, analogy_via, mechanism)
MINI_DDI = [
    (1, 3, "Unknown", "ddinter", "direct", None, None),  # acenocumarol + omeprazol: Unknown → analogie
    (2, 3, "Moderate", "ddinter", "direct", None, None),  # warfarină + omeprazol: Moderate (sora)
    (1, 4, "Unknown", "ddinter", "direct", None, None),  # acenocumarol + simvastatină: Unknown, fără soră → nimic
    (1, 5, "Unknown", "curated", "none", "warfarin", None),  # curated „Unknown” → nimic, chiar dacă sora are nivel
    (2, 5, "Major", "ddinter", "direct", None, None),
    (4, 5, "Major", "curated", "direct", None, "Amlodipina crește concentrația de simvastatină."),
]


@pytest.fixture
def mini_kb(tmp_path):
    """O kb.sqlite cu schema din kb/build.py și câteva rânduri, ca regulile să se poată testa și în CI."""
    import build  # kb/build.py (kb/ e în sys.path din conftest)

    path = tmp_path / "kb.sqlite"
    conn = sqlite3.connect(path)
    conn.executescript(build.SCHEMA)
    conn.executemany("INSERT INTO drug(ddinter_id, name) VALUES (?, ?)", [(s[4], s[1]) for s in MINI_SUBSTANCES])
    conn.executemany("INSERT INTO substance(id, inn, dci_ro, atc, ddinter_id) VALUES (?, ?, ?, ?, ?)", MINI_SUBSTANCES)
    conn.executemany(
        "INSERT INTO ddi(a_id, b_id, level, source, basis, analogy_via, mechanism, ref) VALUES (?, ?, ?, ?, ?, ?, ?, 'test')",
        MINI_DDI,
    )
    conn.executemany("INSERT INTO kb_meta(key, value) VALUES (?, ?)", [("elderly_age_min", "65"), ("acb_threshold_alert", "3")])
    conn.commit()
    conn.close()
    from polygraph.kb import Kb

    return Kb(path)


PATIENT = {"id": "pat_t", "name": "Test", "birth_year": 1980, "caregiver_name": None, "anchors": DEMO["patient"]["anchors"]}
