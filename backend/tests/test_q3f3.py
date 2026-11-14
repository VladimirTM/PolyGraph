"""Q3F3 (docs/PLAN.md, „Q3 · Turul agresiv pe aplicație”): robustețea API, lângă QA1.

T-Q3F3-01 `/feed?since=` inclusiv; T-Q3F3-02 `POST /meds` în paralel (Q3-11) și cererea reluată (QA-10, T-QA1-05);
T-Q3F3-03 `/demo/missed-dose` o dată pe moment; T-Q3F3-04 erorile 422 cu `detail` string, valid după `Error` (A-3).
Testele cu kb-ul real se sar dacă kb/kb.sqlite nu e construit (CI).
"""

from __future__ import annotations

import copy
import json
import time
from concurrent.futures import ThreadPoolExecutor

import pytest
from engine_helpers import FIX, real_kb
from fastapi.testclient import TestClient

from polygraph.api import main
from polygraph.store import Store

P = "/v1/patients/pat_demo"
H = {"X-Patient-Token": "demo-token"}
MED_09 = json.loads((FIX / "med_09_fromilid.json").read_text(encoding="utf-8"))


@pytest.fixture
def client(tmp_path, monkeypatch):
    kb = real_kb()
    monkeypatch.setenv("PG_TODAY", "2026-11-14")
    monkeypatch.setenv("DEMO_MODE", "1")
    monkeypatch.setenv("GEMINI_API_KEY", "")
    monkeypatch.setenv("PG_MEDIA_DIR", str(tmp_path / "media"))
    main.configure(store=Store(":memory:"), kb=kb)
    main.reset_demo()
    with TestClient(main.app, follow_redirects=False) as c:
        yield c


def _event(eid: str, at: str) -> dict:
    return {
        "id": eid,
        "at": at,
        "type": "checkin",
        "severity": "major",
        "title": "Check-in",
        "body": "…",
        "med_ids": [],
        "alert_id": None,
        "checkin_id": None,
    }


def _is_error(response) -> bool:
    body = response.json()
    return set(body) == {"detail"} and isinstance(body["detail"], str) and body["detail"].strip() != ""


# ---------------------------------------------------------------- T-Q3F3-01 · Q3-10


def test_feed_since_is_inclusive(client):
    at = "2026-11-14T15:00:00+02:00"
    main.store().add_event("pat_demo", _event("ev_a", at))
    main.store().add_event("pat_demo", _event("ev_b", at))
    main.store().add_event("pat_demo", _event("ev_old", "2026-11-14T14:59:59+02:00"))
    ids = [e["id"] for e in client.get(f"{P}/feed", headers=H, params={"since": at}).json()]
    assert {"ev_a", "ev_b"} <= set(ids) and "ev_old" not in ids
    # aceeași clipă scrisă în UTC
    ids = {e["id"] for e in client.get(f"{P}/feed", headers=H, params={"since": "2026-11-14T13:00:00Z"}).json()}
    assert {"ev_a", "ev_b"} <= ids


# ---------------------------------------------------------------- T-Q3F3-02 · Q3-11 și QA-10


def test_parallel_identical_meds_make_one(client, monkeypatch):
    real = main.alerts_or_none

    def slow(pid, patient):  # lărgește fereastra dintre verificarea id-ului și inserare
        time.sleep(0.05)
        return real(pid, patient)

    monkeypatch.setattr(main, "alerts_or_none", slow)
    with ThreadPoolExecutor(5) as pool:
        codes = list(pool.map(lambda _: client.post(f"{P}/meds", headers=H, json=MED_09).status_code, range(5)))
    assert all(c < 500 for c in codes), codes
    assert sorted(codes) == [200, 200, 200, 200, 201]
    meds = client.get(f"{P}/meds", headers=H).json()
    assert [m["id"] for m in meds].count("med_09") == 1
    assert sum(m["product"]["brand"] == "Fromilid" for m in meds) == 1
    alerts = [e for e in client.get(f"{P}/feed", headers=H).json() if e["type"] == "alert_new"]
    assert len(alerts) == len({e["alert_id"] for e in alerts}) == 2


def test_replayed_med_is_200_and_other_body_is_409(client):
    first = client.post(f"{P}/meds", headers=H, json=MED_09)
    assert first.status_code == 201
    again = client.post(f"{P}/meds", headers=H, json=MED_09)
    assert again.status_code == 200 and again.json() == first.json()
    feed = client.get(f"{P}/feed", headers=H).json()
    assert sum(e["type"] == "alert_new" for e in feed) == 2

    other = copy.deepcopy(MED_09)
    other["dosage"]["raw"] = "1-0-0"
    other["dosage"]["pattern"]["evening"] = 0
    conflict = client.post(f"{P}/meds", headers=H, json=other)
    assert conflict.status_code == 409 and _is_error(conflict)
    assert conflict.json()["detail"] == "Există deja un medicament cu acest id."
    assert [m["id"] for m in client.get(f"{P}/meds", headers=H).json()].count("med_09") == 1


def test_existing_demo_id_is_a_conflict_not_a_rename(client):
    med = {**copy.deepcopy(MED_09), "id": "med_03"}
    r = client.post(f"{P}/meds", headers=H, json=med)
    assert r.status_code == 409
    assert "med_10" not in {m["id"] for m in client.get(f"{P}/meds", headers=H).json()}


# ---------------------------------------------------------------- T-Q3F3-03 · Q3-20 (backend)


def test_missed_dose_once_per_moment(client):
    first = client.post("/demo/missed-dose").json()
    again = [client.post("/demo/missed-dose") for _ in range(2)]
    assert all(r.status_code == 200 and r.json() == first for r in again)
    missed_today = [e for e in client.get(f"{P}/feed", headers=H).json() if e["id"].endswith("_sim")]
    assert [e["id"] for e in missed_today] == [first["id"]]


def test_missed_dose_after_reset_is_new(client):
    first = client.post("/demo/missed-dose").json()
    client.post("/demo/reset")
    second = client.post("/demo/missed-dose")
    assert second.status_code == 200 and second.json()["id"] == first["id"]
    assert sum(e["id"].endswith("_sim") for e in client.get(f"{P}/feed", headers=H).json()) == 1


# ---------------------------------------------------------------- T-Q3F3-04 · A-3


@pytest.mark.parametrize(
    ("kwargs", "detail"),
    [
        ({"content": b"{nu e json", "headers": {"Content-Type": "application/json"}}, "Corpul cererii nu e JSON valid."),
        ({"json": {k: v for k, v in MED_09.items() if k != "product"}}, "Câmpul «product» lipsește."),
        ({"json": {**MED_09, "source": "fax"}}, "Câmpul «source» are o valoare nepermisă."),
        ({"json": {**MED_09, "culoare": "roșu"}}, "Corpul cererii conține un câmp necunoscut."),
        ({"json": [MED_09]}, "Corpul cererii are tipul greșit."),
    ],
)
def test_validation_errors_have_a_romanian_detail(client, kwargs, detail):
    extra = kwargs.pop("headers", {})
    r = client.post(f"{P}/meds", headers={**H, **extra}, **kwargs)
    assert r.status_code == 422 and _is_error(r)
    assert r.json()["detail"] == detail


def test_query_validation_error_is_a_string(client):
    r = client.post("/demo/reset", params={"live_scan": 2})
    assert r.status_code == 422 and _is_error(r)
    assert r.json()["detail"] == "Câmpul «live_scan» e în afara intervalului permis."
