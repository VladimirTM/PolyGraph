"""B7: demo hardening. Istoricul pacientului demo la reset, doza ratată simulată, alertele noi în Noutăți, termenul
total pentru Gemini (scanare și check-in), DataMatrix greșit căutat în poză și scenariul `make demo-check` (R4).
Testele cu kb-ul real se sar dacă kb/kb.sqlite nu e construit (CI)."""

from __future__ import annotations

import json
import threading
import time
from io import BytesIO

import pytest
import validate as contracts
import zxingcpp
from engine_helpers import FIX, real_kb
from fastapi.testclient import TestClient
from PIL import Image

from polygraph.api import main
from polygraph.demo import check, seed
from polygraph.extract import gemini
from polygraph.store import Store
from polygraph.voice import understand as U

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
    main.configure()


def test_reset_seeds_seven_days_with_two_missed(client):
    doses = main.store().list_doses("pat_demo")
    days = {d["scheduled_at"][:10] for d in doses}
    assert days == {f"2026-11-{d:02d}" for d in range(7, 14)}  # azi (14) rămâne neatins
    assert all(d["status"] == "taken" and not contracts.schema_errors("dose", d) for d in doses)
    assert not any(d["scheduled_at"].startswith("2026-11-12") and d["med_id"] == "med_06" for d in doses)
    assert not any(d["scheduled_at"].startswith("2026-11-09") and d["med_id"] == "med_03" for d in doses)
    feed = client.get(f"{P}/feed", headers=H).json()
    assert [e["type"] for e in feed] == ["dose_missed", "dose_missed"]
    assert all(not contracts.schema_errors("feed_event", e) for e in feed)
    [old] = main.store().list_checkins("pat_demo")
    assert not contracts.schema_errors("checkin", old)
    assert old["symptoms"] == [] and old["escalate"] is False


def test_reset_is_repeatable_and_live_scan_drops_two_boxes(client):
    for _ in range(3):
        assert client.post("/demo/reset", params={"live_scan": 1}).status_code == 200
    meds = {m["id"] for m in client.get(f"{P}/meds", headers=H).json()}
    assert meds == {"med_03", "med_04", "med_05", "med_06", "med_07", "med_08"}
    assert {d["med_id"] for d in main.store().list_doses("pat_demo")} <= meds
    assert len(client.get(f"{P}/feed", headers=H).json()) == 2
    assert client.post("/demo/reset", params={"live_scan": 2}).status_code == 422


def test_portal_shows_adherence_from_history(client):
    client.post("/portal/login", data={"code": "medic-demo", "next": "/portal"})
    page = client.get("/portal/patients/pat_demo").text
    assert "aderență" in page and "încă nicio doză" not in page


def test_missed_dose(client, monkeypatch):
    event = client.post("/demo/missed-dose")
    assert event.status_code == 200
    body = event.json()
    assert not contracts.schema_errors("feed_event", body)
    assert body["type"] == "dose_missed" and body["med_ids"]
    assert body["id"] in {e["id"] for e in client.get(f"{P}/feed", headers=H).json()}
    monkeypatch.setenv("DEMO_MODE", "0")
    assert client.post("/demo/missed-dose").status_code == 404


def test_new_grave_alerts_reach_the_feed(client):
    assert client.post(f"{P}/meds", headers=H, json=MED_09).status_code == 201
    new = [e for e in client.get(f"{P}/feed", headers=H).json() if e["type"] == "alert_new"]
    assert all(not contracts.schema_errors("feed_event", e) for e in new)
    assert {e["alert_id"] for e in new} == {"al_ddi_med_03_med_09", "al_ddi_med_01_med_09"}
    critical = next(e for e in new if e["alert_id"] == "al_ddi_med_03_med_09")
    assert critical["severity"] == "critical" and "Fromilid" in critical["body"]
    assert not any(w in e["body"].lower() for e in new for w in ("opriți", "nu mai luați"))


def test_invalid_datamatrix_is_read_from_the_photo(client):
    barcode = zxingcpp.create_barcode("010594900000002117270930", zxingcpp.BarcodeFormat.DataMatrix)
    out = BytesIO()
    Image.fromarray(zxingcpp.write_barcode_to_image(barcode, scale=8)).save(out, "PNG")
    lines = json.dumps([{"text": "Nurofen", "height": 0.3}, {"text": "400 mg", "height": 0.2}])
    r = client.post(
        f"{P}/scan",
        headers=H,
        data={"kind": "box", "ocr_lines": lines, "datamatrix": "0105949"},
        files={"image": ("box.png", out.getvalue(), "image/png")},
    )
    [candidate] = r.json()["candidates"]
    assert candidate["product"]["gtin"] == "05949000000021"
    assert candidate["product"]["expiry"] == "2027-09-30"
    assert "Codul DataMatrix nu a putut fi citit." not in r.json()["warnings"]


def slow_urlopen(*_args, **_kwargs):
    time.sleep(3)
    raise TimeoutError


def test_scan_llm_has_a_total_deadline(tmp_path, monkeypatch):
    monkeypatch.setattr(gemini, "CACHE", tmp_path)
    monkeypatch.setattr(gemini, "SCAN_DEADLINE", 0.2)
    monkeypatch.setenv("GEMINI_API_KEY", "test")
    monkeypatch.setattr(gemini, "urlopen", slow_urlopen)
    started = time.perf_counter()
    assert gemini.extract_image(b"slow image", "box") == []
    assert time.perf_counter() - started < 1


def test_checkin_llm_has_a_total_deadline(monkeypatch):
    monkeypatch.setattr(U, "LLM_TIMEOUT", 0.2)
    monkeypatch.setenv("GEMINI_API_KEY", "test")
    monkeypatch.setattr(U, "urlopen", slow_urlopen)
    started = time.perf_counter()
    assert U.symptoms_from_llm("parcă nu sunt în apele mele de când m-am trezit azi") == []
    assert time.perf_counter() - started < 1


def test_checkin_llm_answer_is_cached(monkeypatch):
    text = "parcă nu sunt în apele mele de când m-am trezit azi"
    monkeypatch.setattr(U, "_gemini", lambda _t: '{"symptoms": ["nausea"]}')
    assert [s.code for s in U.symptoms_from_llm(text)] == ["nausea"]

    def offline(_t):
        raise AssertionError("răspunsul trebuia să vină din cache")

    monkeypatch.setattr(U, "_gemini", offline)
    assert [s.code for s in U.symptoms_from_llm(text.upper())] == ["nausea"]  # aceeași cheie după normalizare


def test_missed_event_names_the_moment():
    moment = {"time": "13:00", "label": "La prânz", "doses": [{"med_id": "med_06"}]}
    meds = [{"id": "med_06", "product": {"brand": "Calciu + D3"}}]
    event = seed.missed_event({"name": "Maria"}, meds, moment, main.today(), ["med_06"], "x")
    assert event["title"] == "Maria n-a confirmat dozele de la 13:00"
    assert event["body"] == "Calciu + D3, la prânz."
    assert not contracts.schema_errors("feed_event", event)


def test_demo_check_scenario_is_green(client):  # R4, în proces
    lines: list[str] = []
    assert check.run(client, "medic-demo", out=lines.append), "\n".join(lines)
    assert sum("✓" in line for line in lines) == len(check.STEPS)


def test_demo_check_reports_a_broken_step(client, monkeypatch):
    monkeypatch.setitem(check.CHECKIN, "transcript", "Mă simt bine.")
    lines: list[str] = []
    assert not check.run(client, "medic-demo", out=lines.append)
    assert any(line.lstrip().startswith("✗") and "Check-in" in line for line in lines)


def test_deadline_does_not_block_other_requests():
    # o cerere blocată în Gemini nu le ține pe celelalte: fiecare are propriul termen
    from polygraph.deadline import within

    gate = threading.Event()
    started = time.perf_counter()
    assert within(0.1, gate.wait, "test") is None
    assert within(0.5, lambda: 42, "test") == 42
    gate.set()
    assert time.perf_counter() - started < 1


def test_reset_removes_the_old_extra_patient(client):
    # app.sqlite-urile vechi au pacienta „Ana” (același nume ca fiica Mariei); resetul o scoate din lista medicului
    store = main.store()
    store.create_patient({"id": "pat_demo_ana", "name": "Ana", "birth_year": 1952, "caregiver_name": None})
    store.link_patient("doc_demo", "pat_demo_ana")
    main.reset_demo()
    assert store.get_patient("pat_demo_ana") is None
    names = [store.get_patient(pid)["name"] for pid in store.doctor_patient_ids("doc_demo")]
    assert sorted(names) == ["Ioana", "Ion", "Maria"]


def test_root_explains_where_the_address_goes(client):
    # pagina de prezentare păstrează adresa serverului pentru aplicație (ținta QR-ului din `make demo`)
    r = client.get("/")
    assert r.status_code == 200 and r.headers["content-type"].startswith("text/html")
    assert "Setări → adresa serverului" in r.text and "http://testserver" in r.text
    assert 'href="/portal"' in r.text and 'id="conectare"' in r.text
    assert "Nu pune diagnostice" in r.text and "<script>" not in r.text
    assert 'src="/static/share/logo.svg"' in r.text and 'rel="icon"' in r.text
    logo = client.get("/static/share/logo.svg")
    assert logo.status_code == 200 and logo.headers["content-type"].startswith("image/svg+xml")
