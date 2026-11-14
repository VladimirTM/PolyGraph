"""X1, „Pot să iau…?”: what-if pe regimul pacientului, cu răspunsul pe severități decis pe 14.11.2026 (docs/PLAN.md,
1.3). Grav și „fără date” ajung în Noutăți; moderat și „nimic găsit” rămân doar în răspuns și în check-in.
Niciun răspuns nu spune „puteți lua” și nu trimite la farmacist. Testele cu kb-ul real se sar dacă kb/kb.sqlite nu e
construit (CI)."""

from __future__ import annotations

import json

import pytest
import validate as contracts
from engine_helpers import FIX, real_kb
from fastapi.testclient import TestClient

from polygraph.api import main
from polygraph.engine.texts_ro import FORBIDDEN
from polygraph.store import Store
from polygraph.voice import can_i_take
from polygraph.voice import understand as U

H = {"X-Patient-Token": "demo-token"}
P = "/v1/patients/pat_demo"
MEDS = json.loads((FIX / "demo_patient.json").read_text(encoding="utf-8"))["meds"]
PERMISSIVE = ("puteți lua", "puteti lua", "e sigur", "nu e nicio problemă", "farmacist", "opriți", "nu mai luați")


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
    main.configure()


def ask(client, text):
    """→ (reply_text, evenimentul din Noutăți pentru check-in sau None)."""
    r = client.post(f"{P}/checkins", json={"text": text}, headers=H)
    assert r.status_code == 201, r.text
    ci = r.json()
    assert not contracts.schema_errors("checkin", ci)
    assert ci["intent"] == "can_i_take" and ci["escalate"] is False
    reply = ci["reply_text"]
    assert not any(p in reply.lower() for p in PERMISSIVE), reply
    assert not FORBIDDEN.search(reply), reply
    feed = client.get(f"{P}/feed", headers=H).json()
    event = next((e for e in feed if e["checkin_id"] == ci["id"]), None)
    if event:
        assert not contracts.schema_errors("feed_event", event), event
        assert event["type"] == "checkin" and ": " not in event["title"]
        assert not any(p in event["body"].lower() for p in PERMISSIVE), event["body"]
    return reply, event


def test_aspirin_with_sintrom_is_serious_and_reaches_the_feed(client):  # exemplul de la pitch
    reply, event = ask(client, "Pot să iau o aspirină?")
    assert "Aspirin și Sintrom împreună cresc riscul de sângerare." in reply
    assert "Nu luați Aspirin până nu vă răspunde medicul de familie." in reply
    assert "I-am trimis întrebarea lui și Anei." in reply
    assert event is not None
    assert event["title"] == "Maria a întrebat dacă poate lua Aspirin"
    assert event["severity"] == "major" and event["med_ids"] == ["med_01"]
    assert "Sintrom și Aspirin" in event["body"] and "Sursa: DDInter" in event["body"]


def test_paracetamol_is_moderate_and_stays_out_of_the_feed(client):
    reply, event = ask(client, "Pot să iau un paracetamol?")
    assert "are o interacțiune moderată cu Sintrom." in reply
    assert "Am notat întrebarea; Ana și medicul de familie o văd în fișa dumneavoastră." in reply
    assert event is None


def test_ketonal_names_the_anticoagulant(client):
    reply, event = ask(client, "Pot să iau un Ketonal?")
    assert "Sintrom împreună cresc riscul de sângerare" in reply and "până nu vă răspunde medicul" in reply
    assert event is not None and event["severity"] == "major"


def test_no_interaction_data_reaches_the_feed(client):  # metamizolul nu e în DDInter
    reply, event = ask(client, "Pot să iau un Algocalmin dacă am deja Sintrom?")
    assert "Nu am date despre Algocalmin. I-am trimis întrebarea medicului de familie." in reply
    assert event is not None and event["severity"] is None and event["med_ids"] == []
    assert event["title"] == "Maria a întrebat dacă poate lua Algocalmin"


def test_drug_already_on_the_list_keeps_its_answer(client):
    reply, event = ask(client, "Pot să iau Nurofen?")
    assert "Nurofen e pe lista dumneavoastră" in reply
    assert event is None


def test_unknown_drug_falls_back_to_the_doctor(client):
    reply, event = ask(client, "Pot să iau un Zezouxan?")
    assert "întrebați medicul de familie" in reply
    assert event is None


def test_nothing_found_says_so_without_the_feed():
    kb = real_kb()
    dq = {"text": "aspirin", "source": "catalog", "brand": "Aspirin", "med_id": None}
    a = can_i_take.answer(dq, MEDS, kb, lambda _regimen: [], "2026-11-14", "Ana")
    assert a.case == "none_found" and not a.to_feed
    assert a.text == "Nu am găsit o interacțiune cunoscută cu medicamentele dumneavoastră."


def test_oral_single_product_is_preferred():
    hit = can_i_take.pick_product(real_kb(), "paracetamol")
    assert [s["inn"] for s in hit["substances"]] == ["acetaminophen"]


def test_dictated_article_is_stripped():
    assert (U.match_drug("pot să iau o aspirină", MEDS, real_kb()) or {}).get("brand") == "Aspirin"
