"""T-P0-02: fiecare rută din openapi.yaml răspunde pe mock, iar răspunsul validează după schemă."""

import json
from pathlib import Path

import pytest
import validate as contracts
import yaml
from fastapi.testclient import TestClient

from mock_server import app, state

ROOT = Path(__file__).resolve().parents[2]
SPEC = yaml.safe_load((ROOT / "contracts" / "api" / "openapi.yaml").read_text())
FIX = ROOT / "contracts" / "fixtures"
H = {"X-Patient-Token": "demo-token"}
P = "/v1/patients/pat_demo"


@pytest.fixture(autouse=True)
def fresh_state():
    state.reset_demo()
    yield


@pytest.fixture
def client():
    return TestClient(app)


def ok(schema: str, body) -> None:
    errors = contracts.schema_errors(schema, body)
    assert not errors, errors


def share_token(client) -> str:
    return client.post(f"{P}/share", headers=H).json()["share_token"]


def med_09():
    return json.loads((FIX / "med_09_fromilid.json").read_text())


# (metodă, rută din openapi) → funcție care face apelul și verifică răspunsul
def _health(c):
    r = c.get("/health")
    assert r.status_code == 200 and r.json()["ok"] is True


def _create_patient(c):
    r = c.post("/v1/patients", json={"name": "Maria", "birth_year": 1948})
    assert r.status_code == 201
    ok("patient_created", r.json())
    tok = r.json()["patient_token"]
    meds = c.get(f"/v1/patients/{r.json()['id']}/meds", headers={"X-Patient-Token": tok}).json()
    assert len(meds) == 8


def _get_patient(c):
    r = c.get(P, headers=H)
    assert r.status_code == 200
    ok("patient", r.json())


def _patch_patient(c):
    anchors = {"wake": "05:30", "breakfast": "07:00", "lunch": "12:00", "dinner": "18:00", "bed": "21:30"}
    r = c.patch(P, headers=H, json={"anchors": anchors})
    assert r.status_code == 200 and r.json()["anchors"]["wake"] == "05:30"
    ok("patient", r.json())


def _scan(c):
    gs1 = json.loads((FIX / "gs1_cases.json").read_text())
    raw = next(x["raw"] for x in gs1["cases"] if x["name"] == "sintrom_synthetic")
    c.delete(f"{P}/meds/med_01", headers=H)
    lines = json.dumps([{"text": "Sintrom", "height": 0.2}, {"text": "4 mg", "height": 0.1}])
    r = c.post(f"{P}/scan", headers=H, data={"kind": "box", "datamatrix": raw, "ocr_lines": lines})
    assert r.status_code == 200
    ok("extraction", r.json())
    cand = r.json()["candidates"][0]
    assert cand["id"] == "med_01" and cand["product"]["expiry"] == "2028-03-31"
    rx = c.post(f"{P}/scan", headers=H, data={"kind": "prescription"}, files={"image": ("rx.jpg", b"\xff\xd8", "image/jpeg")})
    ok("extraction", rx.json())
    assert rx.json()["candidates"][0]["id"] == "med_09"


def _list_meds(c):
    r = c.get(f"{P}/meds", headers=H)
    assert r.status_code == 200 and len(r.json()) == 8
    for m in r.json():
        ok("medication_item", m)


def _add_med(c):
    r = c.post(f"{P}/meds", headers=H, json=med_09())
    assert r.status_code == 201
    ok("medication_item", r.json())
    ids = {a["id"] for a in c.get(f"{P}/analysis", headers=H).json()["alerts"]}
    assert "al_ddi_med_03_med_09" in ids


def _update_med(c):
    r = c.patch(f"{P}/meds/med_02", headers=H, json={"end_date": "2026-11-30"})
    assert r.status_code == 200 and r.json()["end_date"] == "2026-11-30"
    ok("medication_item", r.json())


def _delete_med(c):
    assert c.delete(f"{P}/meds/med_02", headers=H).status_code == 204
    ids = {a["id"] for a in c.get(f"{P}/analysis", headers=H).json()["alerts"]}
    assert "al_ddi_med_01_med_02" not in ids


def _analysis(c):
    r = c.get(f"{P}/analysis", headers=H)
    assert r.status_code == 200
    body = r.json()
    ok("analysis", body)
    expected = json.loads((FIX / "expected_alerts.json").read_text())["without_med_09"]
    assert [a["id"] for a in body["alerts"]] == [a["id"] for a in expected]
    assert body["acb_total"] == 3
    node_ids = {n["data"]["id"] for n in body["graph"]["nodes"]}
    alert_ids = {a["id"] for a in body["alerts"]}
    for e in body["graph"]["edges"]:
        assert e["data"]["source"] in node_ids and e["data"]["target"] in node_ids
        if e["data"]["type"] == "interacts":
            assert e["data"]["alert_id"] in alert_ids


def _what_if(c):
    r = c.post(f"{P}/what-if", headers=H, json={"query": "Fromilid"})
    assert r.status_code == 200
    ok("what_if_result", r.json())
    assert any(a["severity"] == "critical" for a in r.json()["new_alerts"])
    r2 = c.post(f"{P}/what-if", headers=H, json={"query": "pot sa iau un algocalmin"})
    ok("what_if_result", r2.json())


def _schedule(c):
    r = c.get(f"{P}/schedule", headers=H, params={"date": "2026-11-14"})
    assert r.status_code == 200
    ok("schedule", r.json())
    assert r.json()["date"] == "2026-11-14"


def _doses(c):
    body = {"med_id": "med_05", "scheduled_at": "2026-11-14T07:00:00+02:00", "status": "taken"}
    r = c.post(f"{P}/doses", headers=H, json=body)
    assert r.status_code == 200
    ok("dose", r.json())
    c.post(f"{P}/doses", headers=H, json={**body, "status": "pending"})
    assert len(state.doses["pat_demo"]) == 1  # idempotent pe med_id + scheduled_at


def _checkins(c):
    r = c.post(f"{P}/checkins", headers=H, json={"text": "Mi se învârte capul și am vânătăi."})
    assert r.status_code == 201
    ok("checkin", r.json())
    feed = c.get(f"{P}/feed", headers=H).json()
    assert feed[0]["type"] == "checkin"


def _feed(c):
    c.post(f"{P}/meds", headers=H, json=med_09())
    r = c.get(f"{P}/feed", headers=H)
    assert r.status_code == 200 and r.json()
    for ev in r.json():
        ok("feed_event", ev)
    later = c.get(f"{P}/feed", headers=H, params={"since": "2999-01-01T00:00:00Z"}).json()
    assert later == []


def _share(c):
    r = c.post(f"{P}/share", headers=H)
    assert r.status_code == 201
    ok("share_link", r.json())


def _share_page(c):
    r = c.get(f"/share/{share_token(c)}")
    assert r.status_code == 200 and "portal" in r.text.lower()
    assert c.get("/share/nu-exista").status_code == 404


def _graph_page(c):
    assert c.get(f"/share/{share_token(c)}/graph", params={"embed": 1}).status_code == 200


def _kb_search(c):
    r = c.get("/v1/kb/search", headers=H, params={"q": "sint"})
    assert r.status_code == 200
    ok("kb_search_result", r.json())
    assert r.json()["results"][0]["brand"] == "Sintrom"


def _media(c):
    r = c.get("/media/med_01.jpg")
    assert r.status_code == 200 and r.content.startswith(b"\x89PNG")


def _demo_reset(c):
    r = c.post("/demo/reset", params={"live_scan": 1})
    ok("patient_created", r.json())
    assert len(c.get(f"{P}/meds", headers=H).json()) == 6


def _missed(c):
    r = c.post("/demo/missed-dose")
    ok("feed_event", r.json())


CASES = {
    ("get", "/health"): _health,
    ("post", "/v1/patients"): _create_patient,
    ("get", "/v1/patients/{id}"): _get_patient,
    ("patch", "/v1/patients/{id}"): _patch_patient,
    ("post", "/v1/patients/{id}/scan"): _scan,
    ("get", "/v1/patients/{id}/meds"): _list_meds,
    ("post", "/v1/patients/{id}/meds"): _add_med,
    ("patch", "/v1/patients/{id}/meds/{mid}"): _update_med,
    ("delete", "/v1/patients/{id}/meds/{mid}"): _delete_med,
    ("get", "/v1/patients/{id}/analysis"): _analysis,
    ("post", "/v1/patients/{id}/what-if"): _what_if,
    ("get", "/v1/patients/{id}/schedule"): _schedule,
    ("post", "/v1/patients/{id}/doses"): _doses,
    ("post", "/v1/patients/{id}/checkins"): _checkins,
    ("get", "/v1/patients/{id}/feed"): _feed,
    ("post", "/v1/patients/{id}/share"): _share,
    ("get", "/share/{token}"): _share_page,
    ("get", "/share/{token}/graph"): _graph_page,
    ("get", "/v1/kb/search"): _kb_search,
    ("get", "/media/{name}"): _media,
    ("post", "/demo/reset"): _demo_reset,
    ("post", "/demo/missed-dose"): _missed,
}


def test_every_openapi_operation_has_a_case():
    ops = {(m, path) for path, item in SPEC["paths"].items() for m in item if m in ("get", "post", "patch", "delete", "put")}
    assert ops == set(CASES), f"lipsesc: {ops - set(CASES)}; în plus: {set(CASES) - ops}"


@pytest.mark.parametrize("op", sorted(CASES), ids=lambda op: f"{op[0].upper()} {op[1]}")
def test_route(client, op):
    CASES[op](client)


def test_token_required(client):
    assert client.get(f"{P}/meds").status_code == 401
    assert client.get(f"{P}/meds", headers={"X-Patient-Token": "gresit"}).status_code == 401


def test_analysis_with_med_09_matches_fixture(client):
    client.post(f"{P}/meds", headers=H, json=med_09())
    exp = json.loads((FIX / "expected_alerts.json").read_text())
    got = {a["id"] for a in client.get(f"{P}/analysis", headers=H).json()["alerts"]}
    assert got == {a["id"] for a in exp["without_med_09"] + exp["added_with_med_09"]}
