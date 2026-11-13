"""B1: baza de cunoștințe kb/kb.sqlite și regulile din kb/rules/.

Testele pe kb.sqlite se sar dacă baza nu e construită (datele brute din kb/raw/ nu sunt în git, deci nici în CI);
local: make kb, apoi make test.
"""

import csv
import json
import sqlite3
from itertools import combinations
from pathlib import Path

import pytest
from pydantic import ValidationError

ROOT = Path(__file__).resolve().parents[2]
KB = ROOT / "kb"
FIX = ROOT / "contracts" / "fixtures"

from common import brand_norm, norm_dci  # noqa: E402  (kb/ e în sys.path din conftest)
from load_rules import ElderlyRule, load_all, symptom_codes  # noqa: E402


def demo_meds() -> list[dict]:
    demo = json.loads((FIX / "demo_patient.json").read_text(encoding="utf-8"))
    return demo["meds"] + [json.loads((FIX / "med_09_fromilid.json").read_text(encoding="utf-8"))]


@pytest.fixture(scope="module")
def kb():
    path = KB / "kb.sqlite"
    if not path.exists():
        pytest.skip("kb/kb.sqlite nu e construit (make kb; datele brute nu sunt în CI)")
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    yield conn
    conn.close()


def substance_by_inn(conn, inn: str) -> int:
    row = conn.execute("SELECT id FROM substance WHERE inn = ? AND ddinter_id IS NOT NULL", (inn,)).fetchone()
    assert row, f"substanța {inn} nu e legată la DDInter"
    return row[0]


# --- T-B1-03, T-B1-04: regulile YAML (rulează și în CI) -----------------------------------


def test_rules_validate_and_have_source():
    rules = load_all()
    assert len(rules["elderly"].rules) == 13
    for r in rules["elderly"].rules + rules["timing"].rules + rules["adverse_effects"].substances + rules["food_alias"].foods:
        assert r.source.strip()
    assert rules["acb"].source.strip()


def test_rule_without_source_is_rejected():
    rule = {
        "id": "x",
        "atc": ["N06AA09"],
        "severity": "major",
        "title": "t",
        "detail": "d",
        "recommendation": "r",
    }
    with pytest.raises(ValidationError):
        ElderlyRule.model_validate(rule)
    with pytest.raises(ValidationError):
        ElderlyRule.model_validate(rule | {"source": ""})


def test_adverse_effect_codes_are_in_symptoms_contract():
    codes = symptom_codes()
    assert len(codes) >= 30
    used = {c for a in load_all()["adverse_effects"].substances for c in a.effects}
    assert used <= codes, sorted(used - codes)


def test_adverse_effects_cover_demo_checkin():
    """Check-in-ul demo: amețeala la ridicare se corelează cu amlodipina și amitriptilina (plan 5.8)."""
    by_inn = {a.inn: set(a.effects) for a in load_all()["adverse_effects"].substances}
    assert "dizziness_orthostatic" in by_inn["amlodipine"]
    assert "dizziness_orthostatic" in by_inn["amitriptyline"]
    for m in demo_meds():
        for s in m["substances"]:
            assert s["inn"] in by_inn, f"{s['inn']} nu are efecte adverse în adverse_effects.yaml"


# --- T-B1-01: pacientul demo, după brand și după DCI ---------------------------------------


@pytest.mark.parametrize("med", demo_meds(), ids=lambda m: m["id"])
def test_demo_med_found_by_brand(kb, med):
    q = brand_norm(med["product"]["brand"])
    rows = kb.execute("SELECT p.id FROM product p WHERE p.brand_norm = ? OR p.brand_norm LIKE ? || ' %'", (q, q)).fetchall()
    assert rows, f"niciun produs pentru brandul {med['product']['brand']!r}"
    want = {s["inn"] for s in med["substances"]}
    ok = False
    for (pid,) in rows:
        got = {
            r[0]
            for r in kb.execute(
                "SELECT s.inn FROM product_substance ps JOIN substance s ON s.id = ps.substance_id WHERE ps.product_id = ?",
                (pid,),
            )
        }
        ok = ok or want <= got
    assert ok, f"{med['product']['brand']}: niciun produs nu conține {sorted(want)}"


@pytest.mark.parametrize("sub", [s for m in demo_meds() for s in m["substances"]], ids=lambda s: s["dci"])
def test_demo_substance_found_by_dci(kb, sub):
    dci = norm_dci(sub["dci"])
    rows = kb.execute(
        "SELECT s.inn, s.atc, s.ddinter_id FROM substance s"
        " WHERE s.dci_ro = ? OR EXISTS (SELECT 1 FROM json_each(s.synonyms) WHERE value = ?)",
        (dci, dci),
    ).fetchall()
    assert len(rows) == 1, f"{dci}: {rows}"
    inn, atc, ddinter_id = rows[0]
    assert (inn, atc) == (sub["inn"], sub["atc"])
    assert ddinter_id


def test_calcium_d3_combination_split(kb):
    rows = kb.execute(
        "SELECT s.inn FROM product p JOIN product_substance ps ON ps.product_id = p.id"
        " JOIN substance s ON s.id = ps.substance_id WHERE p.brand_norm = 'calciu + vitamina d3'"
    ).fetchall()
    assert {r[0] for r in rows} == {"calcium carbonate", "cholecalciferol"}


# --- T-B1-02: ddi simetric -----------------------------------------------------------------


def test_ddi_symmetric(kb):
    pairs = kb.execute("SELECT a_id, b_id FROM ddi ORDER BY random() LIMIT 300").fetchall()
    for a, b in pairs:
        ab = kb.execute("SELECT level, ref, source FROM ddi_sym WHERE a = ? AND b = ?", (a, b)).fetchall()
        ba = kb.execute("SELECT level, ref, source FROM ddi_sym WHERE a = ? AND b = ?", (b, a)).fetchall()
        assert len(ab) == 1 and ab == ba
    assert kb.execute("SELECT count(*) FROM ddi WHERE a_id >= b_id").fetchone()[0] == 0


def test_ddinter_counts_match_readme(kb):
    """kb/raw/ddinter/README.md: 160.235 de perechi unice, 1.939 de substanțe."""
    assert kb.execute("SELECT count(*) FROM drug").fetchone()[0] == 1939
    assert kb.execute("SELECT count(*) FROM ddi").fetchone()[0] == 160235
    assert kb.execute("SELECT count(*) FROM ddi WHERE level = 'Unknown'").fetchone()[0] > 0


# --- Perechile din plan 5.8 ----------------------------------------------------------------

# Nivelul final din kb (curated → DDInter); regula de clasă pentru Unknown se aplică în B2.
EXPECTED_58 = {
    ("acenocoumarol", "ibuprofen"): "Major",
    ("acenocoumarol", "clarithromycin"): "Major",
    ("acenocoumarol", "levothyroxine"): "Moderate",
    ("acenocoumarol", "omeprazole"): "Moderate",
    ("acenocoumarol", "simvastatin"): "Minor",
    ("simvastatin", "clarithromycin"): "Contraindicated",
    ("simvastatin", "amlodipine"): "Major",
    ("levothyroxine", "calcium carbonate"): "Moderate",
    ("levothyroxine", "omeprazole"): "Moderate",
    ("ibuprofen", "amlodipine"): "Moderate",
    ("simvastatin", "omeprazole"): "Moderate",
    ("amlodipine", "calcium carbonate"): "Moderate",
    ("levothyroxine", "amitriptyline"): "Moderate",
    ("amitriptyline", "clarithromycin"): "Moderate",
    ("amlodipine", "clarithromycin"): "Moderate",
    ("simvastatin", "levothyroxine"): "Minor",
    ("omeprazole", "clarithromycin"): "Minor",
}


def level(kb, a: str, b: str):
    row = kb.execute(
        "SELECT level, ddinter_level, source FROM ddi_sym WHERE a = ? AND b = ?",
        (substance_by_inn(kb, a), substance_by_inn(kb, b)),
    ).fetchone()
    return row or ("absent", "absent", None)


def test_demo_pairs_match_plan(kb, capsys):
    inns = sorted({s["inn"] for m in demo_meds() for s in m["substances"]})
    with (KB / "raw" / "ddinter" / "demo_pairs_report.csv").open(encoding="utf-8") as fh:
        report = {frozenset((r["drug_a"], r["drug_b"])): r["ddinter_level"] for r in csv.DictReader(fh)}
    lines = []
    for a, b in combinations(inns, 2):
        final, ddinter, source = level(kb, a, b)
        lines.append(f"{a:18s} {b:18s} DDInter={ddinter or 'absent':9s} kb={final:15s} {source or ''}")
        if frozenset((a, b)) in report:
            assert (ddinter or "absent") == report[frozenset((a, b))], (a, b)
    with capsys.disabled():
        print("\nPerechile pacientului demo (plan 5.8):\n  " + "\n  ".join(lines))
    for (a, b), want in EXPECTED_58.items():
        assert level(kb, a, b)[0] == want, (a, b)
