"""B5: check-in-ul (text transcris pe telefon) → simptome, corelări, escaladare, Noutăți, graf.

T-B5-01 calea deterministă pe 10 propoziții (și fără diacritice), fără Gemini; T-B5-02 LLM-ul nu poate întoarce un cod
din afara enum-ului; T-B5-03 POST /checkins < 4 s. Testele de API se sar dacă kb/kb.sqlite nu e construit (CI).
"""

from __future__ import annotations

import json
import time
import unicodedata
from pathlib import Path

import pytest
import validate as contracts
from engine_helpers import FIX, real_kb
from fastapi.testclient import TestClient

from polygraph.api import main
from polygraph.store import Store
from polygraph.voice import understand as U

ROOT = Path(__file__).resolve().parents[2]
CHECKIN = json.loads((FIX / "checkin_demo.json").read_text(encoding="utf-8"))
H = {"X-Patient-Token": "demo-token"}
P = "/v1/patients/pat_demo"


def plain(text: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFKD", text) if not unicodedata.combining(c))


@pytest.fixture
def no_llm(monkeypatch):
    def boom(_text):
        raise AssertionError("calea deterministă nu trebuie să cheme Gemini")

    monkeypatch.setattr(U, "_gemini", boom)


SENTENCES = [
    (CHECKIN["transcript"], ["dizziness_orthostatic", "bruising"]),
    ("Mă doare stomacul și am avut scaun negru.", ["stomach_pain", "black_stool"]),
    ("Nu mă doare capul, dar îmi sângerează gingiile.", ["bleeding_gums"]),
    ("Am vomitat sânge azi-noapte.", ["vomiting_blood"]),
    ("Mă doare capul foarte tare.", ["headache"]),
    ("Nu pot dormi noaptea și sunt obosită.", ["insomnia", "fatigue"]),
    ("Ieri am căzut în baie.", ["fall"]),
    ("Mă dor mușchii și urina e foarte închisă.", ["muscle_pain", "dark_urine"]),
    ("Îmi bate inima tare și respir greu.", ["palpitations", "shortness_of_breath"]),
    ("Am gura uscată și îmi e somn toată ziua.", ["dry_mouth", "drowsiness"]),
]


@pytest.mark.parametrize("text,codes", SENTENCES)
@pytest.mark.parametrize("diacritics", [True, False])
def test_deterministic_symptoms(text, codes, diacritics, no_llm):  # T-B5-01
    u = U.understand(text if diacritics else plain(text))
    assert [s.code for s in u.symptoms] == codes
    assert not u.used_llm


@pytest.mark.parametrize("text", ["Pot dormi bine, mulțumesc.", "Nu am diaree.", "Nu am amețeli deloc."])
def test_no_false_positives(text, no_llm):
    assert U.find_symptoms(text) == []


def test_severity_from_words():
    [s] = U.find_symptoms("mă doare capul foarte tare")
    assert s.severity == "severe"
    [s] = U.find_symptoms("am puțin amețeală")
    assert s.severity == "mild"
    assert [s.severity for s in U.find_symptoms(CHECKIN["transcript"])] == ["moderate", "moderate"]


def test_intent():
    assert U.understand("Pot să iau un Nurofen pentru durere?").intent == "can_i_take"
    assert U.understand("Ce pastilă iau acum?").intent == "which_pill_now"
    assert U.understand(CHECKIN["transcript"]).intent == "symptom_report"
    assert U.understand("Bună dimineața").intent == "other"


def test_drug_query_phonetic_on_patient_list():
    meds = json.loads((FIX / "demo_patient.json").read_text(encoding="utf-8"))["meds"]
    dq = U.match_drug("pot să iau sindrom cu ceai", meds)
    assert dq and dq["med_id"] == "med_01" and dq["source"] == "patient"


def test_llm_rejects_unknown_code(monkeypatch):  # T-B5-02
    monkeypatch.setattr(U, "_gemini", lambda _t: json.dumps({"symptoms": ["headache", "cancer"]}))
    assert U.symptoms_from_llm("ceva lung care nu conține niciun sinonim cunoscut deloc") == []
    assert U.parse_llm('{"symptoms": ["headache", "nausea"]}') == ["headache", "nausea"]
    assert U.parse_llm('{"symptoms": "headache"}') == []
    assert U.parse_llm("nu e json") == []
    assert set(U.llm_schema()["properties"]["symptoms"]["items"]["enum"]) == set(U.vocabulary())


def test_llm_only_as_fallback(monkeypatch):
    calls = []
    monkeypatch.setattr(U, "_gemini", lambda t: calls.append(t) or '{"symptoms": ["nausea"]}')
    assert U.understand("Bună dimineața").symptoms == []  # prea scurt: nu se cheamă
    u = U.understand("parcă nu sunt în apele mele de când m-am trezit azi")
    assert [s.code for s in u.symptoms] == ["nausea"] and u.used_llm and len(calls) == 1


TRANSCRIPTS = sorted((ROOT / "demo" / "transcripts").glob("*.txt"))
# Ce trebuie să iasă din fiecare transcriere reală (demo/transcripts/README.md spune ce s-a rostit).
TRANSCRIPT_EXPECTED = {
    "dictare_01_pot_sa_iau.txt": {"intent": "can_i_take", "symptoms": [], "drug": "Algocalmin"},
    "dictare_02_ma_simt_bine.txt": {"intent": "other", "symptoms": [], "drug": None},
}


@pytest.mark.parametrize("path", TRANSCRIPTS, ids=lambda p: p.name)
def test_real_iphone_transcripts(path, no_llm):
    expected = TRANSCRIPT_EXPECTED.get(path.name)
    assert expected, f"adaugă în TRANSCRIPT_EXPECTED ce trebuie să iasă din {path.name}"
    meds = json.loads((FIX / "demo_patient.json").read_text(encoding="utf-8"))["meds"]
    u = U.understand(path.read_text(encoding="utf-8"), meds, real_kb())
    assert u.intent == expected["intent"]
    assert [s.code for s in u.symptoms] == expected["symptoms"]
    assert (u.drug_query or {}).get("brand") == expected["drug"]


def test_dictated_sintrom_is_not_a_catalog_drug():
    # „sindrom” e cuvânt românesc: pe lista pacientului e Sintrom, singur pe catalog nu se potrivește
    assert U.match_drug("pot să iau sindrom", [], real_kb()) is None


# ---------------------------------------------------------------- API (kb real)


@pytest.fixture
def client(monkeypatch):
    kb = real_kb()
    monkeypatch.setenv("PG_TODAY", "2026-11-14")
    monkeypatch.setenv("DEMO_MODE", "1")
    monkeypatch.setattr(U, "_gemini", lambda _t: None)
    main.configure(store=Store(":memory:"), kb=kb)
    main.reset_demo()
    with TestClient(main.app) as c:
        yield c
    main.configure(None, None)


def ok(schema: str, body) -> None:
    errors = contracts.schema_errors(schema, body)
    assert not errors, errors


def test_checkin_demo_matches_fixture(client):
    t0 = time.perf_counter()
    r = client.post(f"{P}/checkins", json={"text": CHECKIN["transcript"]}, headers=H)
    assert time.perf_counter() - t0 < 4  # T-B5-03
    assert r.status_code == 201
    ci = r.json()
    ok("checkin", ci)
    assert ci["intent"] == CHECKIN["intent"]
    assert ci["symptoms"] == CHECKIN["symptoms"]
    assert ci["correlations"] == CHECKIN["correlations"]
    assert ci["escalate"] is True
    assert ci["reply_text"].startswith("Mulțumesc. I-am trimis Anei ce mi-ați spus.")
    assert "Ridicați-vă încet din pat" in ci["reply_text"]


def new_events(client, **params):
    """Noutățile fără cele 2 doze ratate din istoricul pacientului demo (B7, recreat la reset)."""
    events = client.get(f"{P}/feed", params=params, headers=H).json()
    return [e for e in events if not e["id"].startswith("ev_missed_")]


def test_checkin_feed_and_graph(client):
    before = new_events(client)
    assert before == []
    ci = client.post(f"{P}/checkins", json={"text": CHECKIN["transcript"]}, headers=H).json()
    events = new_events(client)
    assert len(events) == 1
    ev = events[0]
    ok("feed_event", ev)
    assert ev["type"] == "checkin" and ev["checkin_id"] == ci["id"] and ev["severity"] == "major"
    assert "Sintrom + Nurofen" in ev["body"]
    assert client.get(f"{P}/feed", params={"since": ev["at"]}, headers=H).json() == []
    graph = client.get(f"{P}/analysis", headers=H).json()["graph"]
    nodes = {n["data"]["id"] for n in graph["nodes"]}
    assert {"y:bruising", "y:dizziness_orthostatic"} <= nodes
    related = {(e["data"]["source"], e["data"]["target"]) for e in graph["edges"] if e["data"]["type"] == "possibly_related"}
    assert ("y:bruising", "s:B01AA07") in related


def test_red_flag_escalates_without_alert(client):
    ci = client.post(f"{P}/checkins", json={"text": "Am căzut aseară în bucătărie."}, headers=H).json()
    ok("checkin", ci)
    assert ci["escalate"] is True and ci["symptoms"][0]["code"] == "fall"
    [ev] = new_events(client)
    assert ev["severity"] == "critical" and ev["body"].startswith("Semn de alarmă")


def test_mild_checkin_not_escalated(client):
    ci = client.post(f"{P}/checkins", json={"text": "Am gura uscată."}, headers=H).json()
    ok("checkin", ci)
    assert ci["escalate"] is False
    assert ci["correlations"] == [{"symptom": "dry_mouth", "med_ids": ["med_08"], "basis": "alert:al_anticholinergic_med_08"}]
    assert "I-am trimis" not in ci["reply_text"]
    assert new_events(client) == []


def test_checkin_errors(client):
    assert client.post(f"{P}/checkins", json={"text": "x"}).status_code == 401
    assert client.post(f"{P}/checkins", json={"text": "  "}, headers=H).status_code == 422
    assert client.post(f"{P}/checkins", files={"audio": ("a.m4a", b"0")}, headers=H).status_code == 415
    assert client.get(f"{P}/feed", params={"since": "ieri"}, headers=H).status_code == 422


def test_reply_never_says_stop(client):
    for text, _ in SENTENCES:
        reply = client.post(f"{P}/checkins", json={"text": text}, headers=H).json()["reply_text"].lower()
        assert "opriți" not in reply and "nu mai luați" not in reply
