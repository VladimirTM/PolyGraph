"""Q3F2 (docs/PLAN.md, „Q3 · Turul agresiv pe aplicație”): vocea și scanarea pe backend.

T-Q3F2-01 simptomele în cuvinte obișnuite, fără potriviri pe prefix; T-Q3F2-02 rețeta scrisă pe DCI; T-Q3F2-03
textele răspunsului; T-Q3F2-04 /what-if și check-in-ul aleg același produs; T-Q3F2-05 aceeași întrebare X1 o singură
dată în Noutăți. Plus A-5 (posologia necitită). Testele cu kb-ul real se sar dacă kb/kb.sqlite nu e construit (CI).
"""

from __future__ import annotations

import json

import pytest
import validate as contracts
from engine_helpers import FIX, real_kb
from fastapi.testclient import TestClient

from polygraph.api import main
from polygraph.extract.posology import parse_posology
from polygraph.store import Store
from polygraph.voice import understand as U
from polygraph.voice.correlate import reply_text

H = {"X-Patient-Token": "demo-token"}
P = "/v1/patients/pat_demo"
MEDS = json.loads((FIX / "demo_patient.json").read_text(encoding="utf-8"))["meds"]


@pytest.fixture
def no_llm(monkeypatch):
    monkeypatch.setattr(U, "_gemini", lambda _t: None)


@pytest.fixture
def client(monkeypatch, tmp_path, no_llm):
    kb = real_kb()
    monkeypatch.setenv("PG_TODAY", "2026-11-14")
    monkeypatch.setenv("DEMO_MODE", "1")
    monkeypatch.setenv("PG_MEDIA_DIR", str(tmp_path / "media"))
    main.configure(store=Store(":memory:"), kb=kb)
    main.reset_demo()
    with TestClient(main.app) as c:
        yield c
    main.configure()


def codes(text: str) -> list[str]:
    return [s.code for s in U.find_symptoms(text)]


# ---------------------------------------------------------------- T-Q3F2-01 (Q3-08, Q3-19)


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("Am amețeli.", ["dizziness"]),
        ("Am greață.", ["nausea"]),
        ("Amețesc.", ["dizziness"]),
        ("Am greţuri de dimineață.", ["nausea"]),
        ("Amețesc când mă ridic din pat.", ["dizziness_orthostatic"]),
        (
            "Am amețeli, greață, mă dor mușchii și am vânătăi pe mâini și scaun negru.",
            ["dizziness", "nausea", "muscle_pain", "bruising", "black_stool"],
        ),
        ("Mă mănâncă pielea.", ["rash"]),
        ("Am vânătăile pe mâini.", ["bruising"]),
    ],
)
def test_everyday_symptom_words(text, expected, no_llm):
    assert codes(text) == expected


@pytest.mark.parametrize("text", ["Pot să iau sindromul seara cu mâncare?", "Mănânc după mâncare.", "Nu am amețeli."])
def test_whole_words_only(text, no_llm):
    assert codes(text) == []  # „mâncare” nu e „mâncărime”


def test_articled_brand_matches_patient_list(no_llm):
    u = U.understand("Pot să iau sindromul seara cu mâncare?", MEDS)
    assert u.intent == "can_i_take" and u.symptoms == []
    assert u.drug_query and u.drug_query["brand"].startswith("Sintrom") and u.drug_query["source"] == "patient"


# ---------------------------------------------------------------- T-Q3F2-03 (Q3-18, Q3-21, „Mulțumesc.”)


def test_reply_uses_dative_for_the_caregiver(no_llm):
    text = reply_text(U.understand("bine"), [], False, "Ana")
    assert "spuneți-i Anei sau medicului" in text and "spuneți-i Ana " not in text
    assert "spuneți-i cuiva apropiat" in reply_text(U.understand("bine"), [], False, None)


def test_black_stool_advice_is_gender_neutral(no_llm):
    text = reply_text(U.understand("Am avut scaun negru."), [], True, "Ana")
    assert "slăbită" not in text and "fără putere" in text


def test_question_does_not_start_with_thanks(client):
    for question in ("Pot să iau o aspirină?", "Pot să iau Sintrom?", "Ce pastilă iau acum?"):
        ci = client.post(f"{P}/checkins", json={"text": question}, headers=H).json()
        assert not ci["reply_text"].startswith("Mulțumesc"), ci["reply_text"]
    ci = client.post(f"{P}/checkins", json={"text": "Am amețeli."}, headers=H).json()
    assert ci["reply_text"].startswith("Mulțumesc.")


def test_seeded_checkin_uses_dative(client):
    replies = [c["reply_text"] for c in main.store().list_checkins("pat_demo")]
    assert any("spuneți-i Anei" in r for r in replies) and not any("spuneți-i Ana " in r for r in replies)


# ---------------------------------------------------------------- T-Q3F2-02 (Q3-09) și A-5


def scan_rx(client, *lines):
    data = {"kind": "prescription", "ocr_lines": json.dumps([{"text": line, "height": 0.2} for line in lines])}
    r = client.post(f"{P}/scan", headers=H, data=data)
    assert r.status_code == 200, r.text
    body = r.json()
    assert not contracts.schema_errors("extraction", body), body
    return body


def test_prescription_with_three_rows_gives_three_candidates(client):
    body = scan_rx(client, "Aspirin 500 mg", "Paracetamol 500 mg", "Algocalmin 500 mg")
    assert len(body["candidates"]) == 3
    assert not any("manual" in w for w in body["warnings"])


def test_dci_only_row_is_an_oral_candidate_to_review(client):
    (c,) = scan_rx(client, "Paracetamol 500 mg")["candidates"]
    assert c["match"]["method"] == "exact_dci" and c["match"]["needs_review"] is True
    assert c["product"]["brand"] == "Paracetamol" and c["product"]["strength_text"].replace(" ", "") == "500mg"
    assert [s["atc"] for s in c["substances"]] == ["N02BE01"] and c["substances"][0]["strength_mg"] == 500


def test_unmatched_row_is_named_in_the_warning(client):
    body = scan_rx(client, "1. Aspirin 500 mg", "2. Zzqxyl 20 mg")
    assert len(body["candidates"]) == 1
    assert "Nu am găsit «Zzqxyl 20 mg». Adăugați-l manual." in body["warnings"]


@pytest.mark.parametrize("raw", ["1-0-1-1-1", "9999-0-0", "abc", "12-0-0"])
def test_unreadable_posology_is_left_empty(raw):
    dosage, review = parse_posology(raw)
    assert review and not any(dosage["pattern"].values())


def test_unreadable_posology_is_warned(client):
    body = scan_rx(client, "Aspirin 500 mg", "D.S. 9999-0-0")
    (c,) = body["candidates"]
    assert not any(c["dosage"]["pattern"].values()) and c["match"]["needs_review"]
    assert any(w.startswith("Nu am înțeles posologia «D.S. 9999-0-0»") for w in body["warnings"]), body["warnings"]


# ---------------------------------------------------------------- T-Q3F2-04 (A-6) și T-Q3F2-05 (A-7)


def test_what_if_query_picks_the_same_product_as_the_checkin(client):
    r = client.post(f"{P}/what-if", json={"query": "algocalmin"}, headers=H)
    assert r.status_code == 200
    matched = r.json()["matched"]
    expected = main.can_i_take.pick_product(main.kb(), "algocalmin")
    assert matched["product"]["brand"] == expected["brand"] == "Algocalmin"
    assert matched["product"]["form"] == expected["form"] and "inj" not in (matched["product"]["form"] or "").lower()


def test_same_question_twice_is_one_feed_event(client):
    for _ in range(2):
        r = client.post(f"{P}/checkins", json={"text": "Pot să iau o aspirină?"}, headers=H)
        assert r.status_code == 201
    feed = client.get(f"{P}/feed", headers=H).json()
    asked = [e for e in feed if e["title"].endswith("dacă poate lua Aspirin")]
    assert len(asked) == 1, [e["title"] for e in feed]
