"""B2, pe kb-ul real: golden-ul pacientului demo (T-B2-01), id-uri stabile (T-B2-04), recomandări sigure (T-B2-03),
graful (T-B2-05) și timpul de analiză. Se sar dacă kb/kb.sqlite nu e construit (CI)."""

from __future__ import annotations

import copy
import random
import time

import pytest
import validate as contracts
from engine_helpers import EXPECTED, MED_09, TODAY, demo, key, med, real_kb

from polygraph.engine import analyze
from polygraph.engine.texts_ro import FORBIDDEN


@pytest.fixture(scope="module")
def kb():
    return real_kb()


@pytest.fixture(scope="module")
def base(kb):
    patient, meds = demo()
    return analyze(patient, meds, TODAY, kb=kb)


@pytest.fixture(scope="module")
def with_09(kb):
    patient, meds = demo()
    return analyze(patient, [*meds, copy.deepcopy(MED_09)], TODAY, kb=kb)


# --- T-B2-01 ---------------------------------------------------------------------------------


def test_golden_without_med_09(base):
    got = sorted(key(a) for a in base["alerts"])
    want = sorted(key(a) for a in EXPECTED["without_med_09"])
    assert got == want
    assert base["acb_total"] == 3


def test_golden_with_med_09(with_09):
    got = sorted(key(a) for a in with_09["alerts"])
    want = sorted(key(a) for a in EXPECTED["without_med_09"] + EXPECTED["added_with_med_09"])
    assert got == want
    critical = [a for a in with_09["alerts"] if a["severity"] == "critical"]
    assert [(a["kind"], a["med_ids"]) for a in critical] == [("ddi", ["med_03", "med_09"])]


def test_golden_ids_and_analogy(base, with_09):
    want = {a["id"]: a for a in EXPECTED["without_med_09"] + EXPECTED["added_with_med_09"]}
    for a in with_09["alerts"]:
        assert a["id"] in want, a["id"]
        assert a["analogy"] == want[a["id"]]["analogy"], a["id"]
    assert [a["id"] for a in base["alerts"]] == [a["id"] for a in EXPECTED["without_med_09"]]  # aceeași ordine


def test_alerts_validate_against_schema(base, with_09):
    for a in with_09["alerts"]:
        assert not contracts.schema_errors("alert", a), a["id"]


def test_ana_screen_has_four_serious_cards(base):
    """Plan 5.8: 4 carduri grave (food și moderate nu intră), Beers AINS + anticoagulant doar în detail."""
    serious = [a for a in base["alerts"] if a["severity"] in ("critical", "major") and a["kind"] != "food"]
    assert len(serious) == 4
    sintrom_nurofen = next(a for a in base["alerts"] if a["id"] == "al_ddi_med_01_med_02")
    assert "Beers" in sintrom_nurofen["detail"]
    assert not any("beers-nsaid-with-anticoagulant" in a["id"] for a in base["alerts"])


def test_finished_course_leaves_analysis(kb):
    patient, meds = demo()
    old = copy.deepcopy(MED_09) | {"start_date": "2026-10-01", "end_date": "2026-10-07"}
    r = analyze(patient, [*meds, old], TODAY, kb=kb)
    assert sorted(key(a) for a in r["alerts"]) == sorted(key(a) for a in EXPECTED["without_med_09"])


# --- T-B2-02 (pe kb-ul real) -----------------------------------------------------------------


def test_nurofen_plus_generic_ibuprofen_is_duplicate(kb):
    patient, meds = demo()
    generic = med("med_10", "Ibuprofen Terapia", "ibuprofen", "M01AE01")
    r = analyze(patient, [*meds, generic], TODAY, kb=kb)
    dup = [a for a in r["alerts"] if a["kind"] == "duplicate"]
    assert [(a["severity"], a["med_ids"]) for a in dup] == [("major", ["med_02", "med_10"])]


# --- T-B2-03 ---------------------------------------------------------------------------------


def test_recommendations_are_safe(kb, with_09):
    alerts = list(with_09["alerts"])
    rows = kb._q("SELECT a_id, b_id FROM ddi WHERE level != 'Unknown' ORDER BY a_id, b_id")
    rng = random.Random(14)
    patient, _ = demo()
    for a_id, b_id in rng.sample(rows, 20):
        meds = []
        for i, sid in enumerate((a_id, b_id), 1):
            s = kb.substance(sid)
            meds.append(med(f"med_r{i}", s.inn.title(), s.inn, s.atc if s.atc and len(s.atc) == 7 else "Z99ZZ99"))
        r = analyze(patient, meds, TODAY, kb=kb)
        assert any(a["kind"] == "ddi" for a in r["alerts"]), (a_id, b_id)
        alerts += r["alerts"]
    for a in alerts:
        rec = a["recommendation"]
        assert not FORBIDDEN.search(rec), (a["id"], rec)
        for word in ("opri", "nu mai luați", "mg"):
            assert word not in rec.lower(), (a["id"], rec)


# --- T-B2-04 ---------------------------------------------------------------------------------


def test_ids_stable_between_runs(kb, with_09):
    patient, meds = demo()
    again = analyze(patient, [*list(reversed(meds)), copy.deepcopy(MED_09)], TODAY, kb=kb)
    assert [a["id"] for a in again["alerts"]] == [a["id"] for a in with_09["alerts"]]
    assert again["alerts"] == with_09["alerts"]


# --- T-B2-05 ---------------------------------------------------------------------------------


def test_graph_validates_and_edges_point_to_alerts(base, with_09):
    for r in (base, with_09):
        g = r["graph"]
        assert not contracts.schema_errors("graph", g)
        ids = {a["id"] for a in r["alerts"]}
        nodes = {n["data"]["id"] for n in g["nodes"]}
        for e in g["edges"]:
            d = e["data"]
            assert d["source"] in nodes and d["target"] in nodes, d
            if d["type"] in ("interacts", "food_interaction"):
                if d["severity"] == "unknown":
                    assert d["alert_id"] is None
                else:
                    assert d["alert_id"] in ids, d
    interacts = [e["data"] for e in base["graph"]["edges"] if e["data"]["type"] == "interacts" and e["data"]["alert_id"]]
    assert len(interacts) == sum(a["kind"] == "ddi" for a in base["alerts"])
    assert {"s:B01AA07", "c:B01AA", "f:grapefruit", "p", "med_01"} <= {n["data"]["id"] for n in base["graph"]["nodes"]}


def test_graph_links_recent_symptoms(kb):
    patient, meds = demo()
    checkin = {"id": "ci_01", "at": "2026-11-14T09:12:00+02:00", "symptoms": [{"code": "bruising", "label": "vânătăi"}]}
    stale = {"id": "ci_00", "at": "2026-10-01T09:00:00+02:00", "symptoms": [{"code": "nausea", "label": "greață"}]}
    g = analyze(patient, meds, TODAY, kb=kb, checkins=[checkin, stale])["graph"]
    nodes = {n["data"]["id"] for n in g["nodes"]}
    assert "y:bruising" in nodes and "y:nausea" not in nodes
    related = {e["data"]["target"] for e in g["edges"] if e["data"]["type"] == "possibly_related"}
    assert "s:B01AA07" in related


# --- performanță -----------------------------------------------------------------------------


def test_fifteen_meds_under_200_ms(kb):
    patient, meds = demo()
    extra = [
        ("metformin", "A10BA02"),
        ("furosemide", "C03CA01"),
        ("metoprolol", "C07AB02"),
        ("ramipril", "C09AA05"),
        ("paroxetine", "N06AB05"),
        ("alprazolam", "N05BA12"),
        ("tramadol", "N02AX02"),
    ]
    all_meds = [*meds, *(med(f"med_{20 + i}", inn.title(), inn, atc) for i, (inn, atc) in enumerate(extra))]
    assert len(all_meds) == 15
    analyze(patient, all_meds, TODAY, kb=kb)  # încălzire (cache-uri)
    t0 = time.perf_counter()
    analyze(patient, all_meds, TODAY, kb=kb)
    assert (time.perf_counter() - t0) < 0.2
