"""B2, pe o kb sintetică (rulează și în CI): regula de clasă (T-B2-06), dublurile (T-B2-02), expirarea, textele."""

from __future__ import annotations

from engine_helpers import PATIENT, TODAY, med

from polygraph.engine import analyze, new_alerts
from polygraph.engine.texts_ro import GENERIC_RECOMMENDATION, articulated, ro_name, safe_recommendation


def ddi_alerts(r):
    return {tuple(a["med_ids"]): a for a in r["alerts"] if a["kind"] == "ddi"}


# --- T-B2-06 ---------------------------------------------------------------------------------


def test_unknown_with_class_sister_gets_analogy(mini_kb):
    meds = [med("med_01", "Sintrom", "acenocoumarol", "B01AA07"), med("med_02", "Omeprazol", "omeprazole", "A02BC01")]
    a = ddi_alerts(analyze(PATIENT, meds, TODAY, kb=mini_kb))[("med_01", "med_02")]
    assert (a["severity"], a["basis"]) == ("moderate", "class_analogy")
    assert a["analogy"] == {"via": "warfarină", "atc4": "B01AA"}
    assert "prin analogie cu warfarina" in a["detail"]


def test_sister_on_either_side(mini_kb):
    """Sora poate fi în clasa celeilalte substanțe: warfarină + esomeprazol nu există, dar warfarină + omeprazol da."""
    meds = [med("med_01", "Warfarin", "warfarin", "B01AA03"), med("med_02", "Esomeprazol", "esomeprazole", "A02BC05")]
    a = ddi_alerts(analyze(PATIENT, meds, TODAY, kb=mini_kb))
    assert a == {}  # perechea nu e deloc în DDInter (absent ≠ Unknown): nicio alertă


def test_unknown_without_sister_gives_no_alert_but_grey_edge(mini_kb):
    meds = [med("med_01", "Sintrom", "acenocoumarol", "B01AA07"), med("med_02", "Simvastatin", "simvastatin", "C10AA01")]
    r = analyze(PATIENT, meds, TODAY, kb=mini_kb)
    assert ddi_alerts(r) == {}
    grey = [e["data"] for e in r["graph"]["edges"] if e["data"]["type"] == "interacts"]
    assert grey and all(e["severity"] == "unknown" and e["alert_id"] is None for e in grey)


def test_curated_row_has_priority_over_analogy(mini_kb):
    """Warfarină + amlodipină = Major, dar rândul curated acenocumarol + amlodipină = Unknown → nicio alertă."""
    meds = [med("med_01", "Sintrom", "acenocoumarol", "B01AA07"), med("med_02", "Amlodipină", "amlodipine", "C08CA01")]
    assert ddi_alerts(analyze(PATIENT, meds, TODAY, kb=mini_kb)) == {}


def test_curated_direct_text_in_detail(mini_kb):
    meds = [med("med_01", "Simvastatin", "simvastatin", "C10AA01"), med("med_02", "Amlodipină", "amlodipine", "C08CA01")]
    a = ddi_alerts(analyze(PATIENT, meds, TODAY, kb=mini_kb))[("med_01", "med_02")]
    assert (a["severity"], a["basis"], a["source"]["db"]) == ("major", "direct", "curated")
    assert "amlodipina crește concentrația" in a["detail"]
    assert a["route_to"][-2:] == ["caregiver", "pharmacist"]


# --- T-B2-02 ---------------------------------------------------------------------------------


def test_same_substance_two_brands_is_major_duplicate(mini_kb):
    meds = [med("med_02", "Nurofen", "ibuprofen", "M01AE01"), med("med_10", "Ibuprofen Terapia", "ibuprofen", "M01AE01")]
    dup = [a for a in analyze(PATIENT, meds, TODAY, kb=mini_kb)["alerts"] if a["kind"] == "duplicate"]
    assert [(a["severity"], a["med_ids"], a["title"]) for a in dup] == [
        ("major", ["med_02", "med_10"], "Același medicament sub două nume")
    ]


def test_same_risky_class_is_duplicate(mini_kb):
    meds = [med("med_01", "Nurofen", "ibuprofen", "M01AE01"), med("med_02", "Naproxen", "naproxen", "M01AE02")]
    dup = [a for a in analyze(PATIENT, meds, TODAY, kb=mini_kb)["alerts"] if a["kind"] == "duplicate"]
    assert len(dup) == 1 and dup[0]["title"] == "Două medicamente din aceeași clasă"


def test_same_class_outside_whitelist_is_not_duplicate(mini_kb):
    meds = [med("med_01", "Sintrom", "acenocoumarol", "B01AA07"), med("med_02", "Omeprazol", "omeprazole", "A02BC01")]
    assert not [a for a in analyze(PATIENT, meds, TODAY, kb=mini_kb)["alerts"] if a["kind"] == "duplicate"]


# --- expirare, cure încheiate, what-if, vârstă ------------------------------------------------


def test_expired_box(mini_kb):
    meds = [med("med_01", "Omeprazol", "omeprazole", "A02BC01", expiry="2026-10-31")]
    a = analyze(PATIENT, meds, TODAY, kb=mini_kb)["alerts"]
    assert [(x["kind"], x["severity"], x["action"]) for x in a] == [("expired", "major", "replace_box")]


def test_ended_course_is_ignored(mini_kb):
    meds = [
        med("med_01", "Simvastatin", "simvastatin", "C10AA01"),
        med("med_02", "Amlodipină", "amlodipine", "C08CA01", end="2026-11-13"),
    ]
    assert analyze(PATIENT, meds, TODAY, kb=mini_kb)["alerts"] == []


def test_new_alerts_only(mini_kb):
    base = [med("med_01", "Simvastatin", "simvastatin", "C10AA01")]
    before = analyze(PATIENT, base, TODAY, kb=mini_kb)["alerts"]
    after = analyze(PATIENT, [*base, med("med_02", "Amlodipină", "amlodipine", "C08CA01")], TODAY, kb=mini_kb)["alerts"]
    assert [a["id"] for a in new_alerts(before, after)] == ["al_ddi_med_01_med_02"]


def test_unknown_substance_does_not_crash(mini_kb):
    meds = [med("med_01", "Ceva", "nonexistentium", "Z99ZZ99"), med("med_02", "Altceva", "nonexistentium", "Z99ZZ99")]
    r = analyze(PATIENT, meds, TODAY, kb=mini_kb)
    assert [a["kind"] for a in r["alerts"]] == ["duplicate"]


# --- texte -----------------------------------------------------------------------------------


def test_ro_names():
    assert ro_name("warfarin", "WARFARINUM") == "warfarină"
    assert ro_name("amitriptyline", "AMITRIPTYLINUM") == "amitriptilină"
    assert ro_name("omeprazole", "OMEPRAZOLUM") == "omeprazol"
    assert ro_name("clarithromycin", None) == "claritromicină"
    assert articulated("warfarină") == "warfarina" and articulated("naproxen") == "naproxenul"


def test_unsafe_recommendation_is_replaced():
    for bad in ("Opriți Sintromul.", "Nu mai luați ibuprofen.", "Scădeți la 20 mg pe zi.", "Luați 1 comprimat seara."):
        assert safe_recommendation(bad) == GENERIC_RECOMMENDATION
    ok = "Discutați cu medicul de familie."
    assert safe_recommendation(ok) == ok
