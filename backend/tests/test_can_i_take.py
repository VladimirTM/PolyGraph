"""X1, „Pot să iau…?”: what-if pe regimul pacientului, cu răspunsul prudent decis pe 14.11.2026 (docs/PLAN.md, 1.3).
Niciun răspuns nu spune „puteți lua”. Testele cu kb-ul real se sar dacă kb/kb.sqlite nu e construit (CI)."""

from __future__ import annotations

import json

import pytest
import validate as contracts
from engine_helpers import FIX, real_kb
from fastapi.testclient import TestClient

from polygraph.api import main
from polygraph.store import Store
from polygraph.voice import can_i_take
from polygraph.voice import understand as U

H = {"X-Patient-Token": "demo-token"}
P = "/v1/patients/pat_demo"
MEDS = json.loads((FIX / "demo_patient.json").read_text(encoding="utf-8"))["meds"]
PERMISSIVE = ("puteți lua", "puteti lua", "e sigur", "nu e nicio problemă")


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
    r = client.post(f"{P}/checkins", json={"text": text}, headers=H)
    assert r.status_code == 201, r.text
    ci = r.json()
    assert not contracts.schema_errors("checkin", ci)
    assert ci["intent"] == "can_i_take" and ci["escalate"] is False
    assert not any(p in ci["reply_text"].lower() for p in PERMISSIVE), ci["reply_text"]
    return ci["reply_text"]


def test_aspirin_with_sintrom_asks_the_doctor(client):  # exemplul de la pitch
    reply = ask(client, "Pot să iau o aspirină?")
    assert "Înainte să luați Aspirin, întrebați medicul de familie." in reply
    assert "Sintrom și Aspirin" in reply


def test_same_class_as_a_current_drug(client):
    reply = ask(client, "Pot să iau un Ketonal?")
    assert "întrebați medicul de familie" in reply and "aceeași clasă" in reply


def test_no_interaction_data_is_said_plainly(client):  # metamizolul nu e în DDInter
    reply = ask(client, "Pot să iau un Algocalmin dacă am deja Sintrom?")
    assert "Nu am date despre Algocalmin" in reply


def test_drug_already_on_the_list_keeps_its_answer(client):
    reply = ask(client, "Pot să iau Nurofen?")
    assert "Nurofen e pe lista dumneavoastră" in reply


def test_unknown_drug_falls_back_to_the_doctor(client):
    reply = ask(client, "Pot să iau un Zezouxan?")
    assert "întrebați medicul de familie" in reply


def test_nothing_found_still_sends_to_the_pharmacist():
    kb = real_kb()
    dq = {"text": "aspirin", "source": "catalog", "brand": "Aspirin", "med_id": None}
    a = can_i_take.answer(dq, MEDS, kb, lambda _regimen: [], "2026-11-14")
    assert a.case == "none_found"
    assert "Nu am găsit o interacțiune cunoscută" in a.text and "întrebați farmacistul" in a.text


def test_oral_single_product_is_preferred():
    hit = can_i_take.pick_product(real_kb(), "paracetamol")
    assert [s["inn"] for s in hit["substances"]] == ["acetaminophen"]


def test_dictated_article_is_stripped():
    assert (U.match_drug("pot să iau o aspirină", MEDS, real_kb()) or {}).get("brand") == "Aspirin"
