"""B2: rutele reale (polygraph/api/main.py) pe kb-ul real și un app.sqlite în memorie; răspunsurile validează după
contracte. Se sar dacă kb/kb.sqlite nu e construit (CI)."""

from __future__ import annotations

import copy

import pytest
import validate as contracts
from engine_helpers import EXPECTED, MED_09, key, real_kb
from fastapi.testclient import TestClient

from polygraph.api import main
from polygraph.store import Store

H = {"X-Patient-Token": "demo-token"}
P = "/v1/patients/pat_demo"


@pytest.fixture(scope="module")
def kb():
    return real_kb()


@pytest.fixture
def client(kb, monkeypatch):
    monkeypatch.setenv("PG_TODAY", "2026-11-14")
    monkeypatch.setenv("DEMO_MODE", "1")
    main.configure(store=Store(":memory:"), kb=kb)
    main.reset_demo()
    with TestClient(main.app) as c:
        yield c
    main.configure(None, None)


def ok(schema: str, body) -> None:
    errors = contracts.schema_errors(schema, body)
    assert not errors, errors


def test_health(client):
    assert client.get("/health").json() == {"ok": True, "mode": "backend"}


def test_analysis_matches_golden(client):
    r = client.get(f"{P}/analysis", headers=H)
    assert r.status_code == 200
    body = r.json()
    ok("analysis", body)
    assert sorted(key(a) for a in body["alerts"]) == sorted(key(a) for a in EXPECTED["without_med_09"])
    assert body["acb_total"] == 3


def test_auth(client):
    assert client.get(f"{P}/analysis").status_code == 401
    assert client.get(f"{P}/analysis", headers={"X-Patient-Token": "nope"}).status_code == 401
    assert client.get("/v1/patients/pat_nope/analysis", headers=H).status_code == 404


def test_add_med_09_then_delete(client):
    r = client.post(f"{P}/meds", headers=H, json=copy.deepcopy(MED_09))
    assert r.status_code == 201
    ok("medication_item", r.json())
    alerts = client.get(f"{P}/analysis", headers=H).json()["alerts"]
    want = EXPECTED["without_med_09"] + EXPECTED["added_with_med_09"]
    assert sorted(key(a) for a in alerts) == sorted(key(a) for a in want)
    assert client.delete(f"{P}/meds/med_09", headers=H).status_code == 204
    assert client.delete(f"{P}/meds/med_09", headers=H).status_code == 404
    assert len(client.get(f"{P}/analysis", headers=H).json()["alerts"]) == 27


def test_add_med_with_taken_id_gets_new_id(client):
    m = copy.deepcopy(MED_09) | {"id": "med_01"}
    r = client.post(f"{P}/meds", headers=H, json=m)
    assert r.status_code == 201 and r.json()["id"] not in {f"med_0{i}" for i in range(1, 9)}


def test_add_invalid_med_is_422(client):
    bad = copy.deepcopy(MED_09)
    bad.pop("dosage")
    assert client.post(f"{P}/meds", headers=H, json=bad).status_code == 422


def test_patch_med_end_date_removes_it_from_analysis(client):
    r = client.patch(f"{P}/meds/med_02", headers=H, json={"end_date": "2026-11-13"})
    assert r.status_code == 200
    ok("medication_item", r.json())
    alerts = client.get(f"{P}/analysis", headers=H).json()["alerts"]
    assert not any("med_02" in a["med_ids"] for a in alerts)
    assert client.patch(f"{P}/meds/med_02", headers=H, json={"id": "x"}).status_code == 422
    assert client.patch(f"{P}/meds/med_99", headers=H, json={"end_date": None}).status_code == 404


def test_alert_state_is_merged(client):
    main.store().set_alert_state(
        "pat_demo",
        "al_ddi_med_01_med_02",
        "verified_by_pharmacist",
        {"by": "pharmacist", "note": "ok", "at": "2026-11-14T10:00:00Z"},
    )
    alerts = client.get(f"{P}/analysis", headers=H).json()["alerts"]
    a = next(x for x in alerts if x["id"] == "al_ddi_med_01_med_02")
    assert a["status"] == "verified_by_pharmacist" and a["resolution"]["by"] == "pharmacist"


def test_what_if_with_med(client):
    r = client.post(f"{P}/what-if", headers=H, json={"med": copy.deepcopy(MED_09)})
    assert r.status_code == 200
    body = r.json()
    ok("what_if_result", body)
    assert sorted(key(a) for a in body["new_alerts"]) == sorted(key(a) for a in EXPECTED["added_with_med_09"])
    assert len(client.get(f"{P}/meds", headers=H).json()) == 8  # nu salvează


def test_what_if_with_query(client):
    body = client.post(f"{P}/what-if", headers=H, json={"query": "fromilid"}).json()
    ok("what_if_result", body)
    assert body["matched"]["product"]["brand"].lower().startswith("fromilid")
    assert any(a["severity"] == "critical" for a in body["new_alerts"])
    none = client.post(f"{P}/what-if", headers=H, json={"query": "xyzxyz"}).json()
    assert none == {"matched": None, "new_alerts": []}


def test_kb_search(client):
    r = client.get("/v1/kb/search", params={"q": "sint"}, headers=H)
    assert r.status_code == 200
    body = r.json()
    ok("kb_search_result", body)
    assert any(x["brand"].lower().startswith("sintrom") for x in body["results"])
    assert client.get("/v1/kb/search", params={"q": "sint"}).status_code == 401


def test_create_patient_and_patch(client):
    r = client.post("/v1/patients", json={"name": "Ion", "birth_year": 1950})
    assert r.status_code == 201
    body = r.json()
    ok("patient_created", body)
    h = {"X-Patient-Token": body["patient_token"]}
    pid = body["id"]
    assert client.get(f"/v1/patients/{pid}/meds", headers=h).json() == []
    r = client.patch(f"/v1/patients/{pid}", headers=h, json={"caregiver_name": "Ioana"})
    assert r.status_code == 200 and r.json()["caregiver_name"] == "Ioana"
    assert client.get(f"{P}/meds", headers=h).status_code == 401  # alt pacient
    assert client.post("/v1/patients", json={"name": ""}).status_code == 422


def test_demo_reset_live_scan(client):
    r = client.post("/demo/reset", params={"live_scan": 1})
    assert r.status_code == 200
    ids = [m["id"] for m in client.get(f"{P}/meds", headers=H).json()]
    assert "med_01" not in ids and "med_02" not in ids and len(ids) == 6
