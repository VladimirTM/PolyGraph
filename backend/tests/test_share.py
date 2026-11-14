"""B6: portalul medicului de familie (polygraph/share + rutele /portal și /share), pe kb-ul real și un app.sqlite în memorie."""

from __future__ import annotations

import time
from datetime import UTC, date, datetime, timedelta

import pytest
import validate as contracts
from engine_helpers import real_kb
from fastapi.testclient import TestClient
from markupsafe import escape

from polygraph.api import main
from polygraph.share.view import adherence, plural
from polygraph.store import Store

H = {"X-Patient-Token": "demo-token"}
P = "/v1/patients/pat_demo"
PORTAL = "/portal/patients/pat_demo"
CODE = "medic-demo"


@pytest.fixture(scope="module")
def kb():
    return real_kb()


@pytest.fixture
def client(kb, monkeypatch):
    monkeypatch.setenv("PG_TODAY", "2026-11-14")
    monkeypatch.setenv("DEMO_MODE", "1")
    monkeypatch.delenv("PG_DOCTOR_CODE", raising=False)
    main.configure(store=Store(":memory:"), kb=kb)
    main.reset_demo()
    with TestClient(main.app) as c:
        yield c
    main.configure(None, None)


@pytest.fixture
def doctor(client):
    r = client.post("/portal/login", data={"code": CODE, "next": "/portal"}, follow_redirects=False)
    assert r.status_code == 303 and r.headers["location"] == "/portal"
    return client


def ok(schema: str, body) -> None:
    errors = contracts.schema_errors(schema, body)
    assert not errors, errors


def new_share(client, pid: str = "pat_demo", token: str = "demo-token") -> str:
    r = client.post(f"/v1/patients/{pid}/share", headers={"X-Patient-Token": token})
    assert r.status_code == 201
    body = r.json()
    ok("share_link", body)
    assert body["url"].endswith(f"/share/{body['share_token']}")
    return body["share_token"]


def alerts(client) -> list[dict]:
    return client.get(f"{P}/analysis", headers=H).json()["alerts"]


# ---------------------------------------------------------------- autentificarea și lista


def test_share_needs_patient_token(client):
    assert client.post(f"{P}/share").status_code == 401


def test_share_expires_in_72_hours(client):
    body = client.post(f"{P}/share", headers=H).json()
    left = datetime.fromisoformat(body["expires_at"].replace("Z", "+00:00")) - datetime.now(UTC)
    assert timedelta(hours=71, minutes=59) < left <= timedelta(hours=72)


def test_portal_asks_for_the_access_code(client):
    r = client.get("/portal")
    assert r.status_code == 200 and "Codul de acces" in r.text and "Maria" not in r.text
    r = client.post("/portal/login", data={"code": "gresit"})
    assert r.status_code == 401 and "nu e corect" in r.text
    assert client.get(PORTAL).status_code == 200 and "Maria" not in client.get(PORTAL).text


def test_login_sets_a_private_session_cookie(client):
    r = client.post("/portal/login", data={"code": CODE}, follow_redirects=False)
    cookie = r.headers["set-cookie"].lower()
    assert "httponly" in cookie and "samesite=lax" in cookie


def test_login_only_redirects_to_local_pages(client):
    r = client.post("/portal/login", data={"code": CODE, "next": "https://rau.example/"}, follow_redirects=False)
    assert r.headers["location"] == "/portal"
    r = client.post("/portal/login", data={"code": CODE, "next": "//rau.example/portal"}, follow_redirects=False)
    assert r.headers["location"] == "/portal"


def test_patient_list_puts_pending_alerts_first(doctor):
    r = doctor.get("/portal")
    assert r.status_code == 200
    html = r.text
    assert "dr. Elena Popa" in html
    for name in ("Maria", "Ion", "Ioana"):
        assert name in html
    assert html.index("Maria, 78 de ani") < html.index("Ioana, 74 de ani")
    assert "5 de revizuit" in html


def test_logout_ends_the_session(doctor):
    doctor.post("/portal/logout")
    assert "Codul de acces" in doctor.get("/portal").text


# ---------------------------------------------------------------- linkul din QR


def test_qr_link_adds_a_new_patient_to_the_doctors_list(doctor):
    r = doctor.post("/v1/patients", json={"name": "Gheorghe", "birth_year": 1940})
    pid, token = r.json()["id"], r.json()["patient_token"]
    assert doctor.get(f"/portal/patients/{pid}").status_code == 404
    share = new_share(doctor, pid, token)
    r = doctor.get(f"/share/{share}", follow_redirects=False)
    assert r.status_code == 303 and r.headers["location"] == f"/portal/patients/{pid}"
    assert doctor.get(f"/portal/patients/{pid}").status_code == 200
    assert "Gheorghe" in doctor.get("/portal").text


def test_qr_link_without_session_shows_login_that_returns_to_it(client):
    share = new_share(client)
    r = client.get(f"/share/{share}")
    assert r.status_code == 200 and "adăugați pacientul" in r.text and f'value="/share/{share}"' in r.text
    r = client.post("/portal/login", data={"code": CODE, "next": f"/share/{share}"}, follow_redirects=False)
    assert r.headers["location"] == f"/share/{share}"


def test_t_b6_01_unknown_or_expired_token_is_friendly_404(doctor):
    r = doctor.get("/share/nu-exista-acest-token")
    assert r.status_code == 404 and "Linkul a expirat" in r.text and "Maria" not in r.text
    main.store().create_share("token-expirat-de-test", "pat_demo", "2026-01-01T00:00:00Z")
    for path in ("", "/graph", "/graph?embed=1"):
        r = doctor.get(f"/share/token-expirat-de-test{path}")
        assert r.status_code == 404, path
        assert "Maria" not in r.text and "Sintrom" not in r.text


def test_doctor_sees_only_own_patients(doctor):
    r = doctor.post("/v1/patients", json={"name": "Străin", "birth_year": 1950})
    pid = r.json()["id"]
    assert doctor.get(f"/portal/patients/{pid}").status_code == 404
    aid = alerts(doctor)[0]["id"]
    r = doctor.post(f"/portal/patients/{pid}/alerts/{aid}/review", json={"decision": "keep"})
    assert r.status_code == 404


# ---------------------------------------------------------------- fișa pacientului


def test_patient_page_has_summary_alerts_and_sections(doctor):
    start = time.perf_counter()
    r = doctor.get(PORTAL)
    assert time.perf_counter() - start < 2
    assert r.status_code == 200 and r.headers["content-type"].startswith("text/html")
    html = r.text
    assert "Maria, 78 de ani" in html and "Pacienții mei" in html
    assert "8 medicamente de la 5 medici" in html and "5 alerte grave" in html and "ACB 3" in html
    for a in alerts(doctor):
        assert f'id="alert-{a["id"]}"' in html
    assert html.index("h-summary") < html.index("h-grave") < html.index("h-meds") < html.index("h-other")
    for section in ("h-graph", "h-checkins", "h-schedule"):
        assert section in html
    assert "Sintrom 4 mg" in html and "acenocumarol" in html and "B01AA07" in html
    assert "Menține" in html and "Modific la consultație" in html and "Trimit la specialist" in html


def test_pages_keep_medical_data_private(doctor):
    r = doctor.get(PORTAL)
    assert r.headers["referrer-policy"] == "no-referrer"
    assert r.headers["cache-control"] == "no-store"
    assert "script-src 'self'" in r.headers["content-security-policy"]


def test_t_b6_02_print_has_every_major_and_critical_alert(doctor):
    r = doctor.get(f"{PORTAL}/print")
    assert r.status_code == 200
    html = r.text
    grave = [a for a in alerts(doctor) if a["severity"] in ("major", "critical")]
    assert grave
    for a in grave:
        assert str(escape(a["title"])) in html
    assert "Reconcilierea medicației" in html and "Semnătura și parafa" in html
    assert "Întrebări propuse pentru consultație" in html
    assert "cytoscape" not in html and "review-form" not in html


def test_t_b6_03_doctor_note_is_escaped(doctor):
    aid = alerts(doctor)[0]["id"]
    note = "<script>alert(1)</script> & <b>gata</b>"
    r = doctor.post(f"{PORTAL}/alerts/{aid}/review", json={"decision": "keep", "note": note})
    assert r.status_code == 200
    for path in ("", "/print"):
        html = doctor.get(f"{PORTAL}{path}").text
        assert "<script>alert(1)</script>" not in html and "<b>gata</b>" not in html
        assert "&lt;script&gt;alert(1)&lt;/script&gt; &amp; &lt;b&gt;gata&lt;/b&gt;" in html


def test_review_reaches_app_alert_and_feed(doctor):
    aid = next(a["id"] for a in alerts(doctor) if a["severity"] == "major")
    r = doctor.post(f"{PORTAL}/alerts/{aid}/review", json={"decision": "change_at_visit", "note": "Schimb AINS-ul joi."})
    assert r.status_code == 200
    body = r.json()
    ok("alert", body)
    assert body["status"] == "reviewed_by_doctor" and body["resolution"]["decision"] == "change_at_visit"
    after = next(a for a in alerts(doctor) if a["id"] == aid)
    assert after["status"] == "reviewed_by_doctor" and after["resolution"]["note"] == "Schimb AINS-ul joi."
    ev = next(e for e in doctor.get(f"{P}/feed", headers=H).json() if e["type"] == "doctor_reviewed")
    ok("feed_event", ev)
    assert ev["alert_id"] == aid and ev["body"] == "Decizie: Modific la consultație. Schimb AINS-ul joi."
    assert "Modific la consultație ·" in doctor.get(PORTAL).text
    assert "4 de revizuit" in doctor.get("/portal").text


def test_review_needs_session_and_valid_body(client, doctor):
    aid = alerts(doctor)[0]["id"]
    assert doctor.post(f"{PORTAL}/alerts/al_nu_exista/review", json={"decision": "keep"}).status_code == 404
    assert doctor.post(f"{PORTAL}/alerts/{aid}/review", json={"decision": "opriti"}).status_code == 422
    assert doctor.post(f"{PORTAL}/alerts/{aid}/review", json={"decision": "keep", "by": "x"}).status_code == 422
    assert doctor.post(f"{PORTAL}/alerts/{aid}/review", json={"decision": "keep", "note": "x" * 1001}).status_code == 422
    doctor.post("/portal/logout")
    assert client.post(f"{PORTAL}/alerts/{aid}/review", json={"decision": "keep"}).status_code == 401


def test_graph_pages(doctor):
    token = new_share(doctor)
    r = doctor.get(f"/share/{token}/graph?embed=1")
    assert r.status_code == 200
    assert 'class="graph-page embed"' in r.text and 'id="graph-data"' in r.text and "graph-bar" not in r.text
    r = doctor.get(f"{PORTAL}/graph")
    assert r.status_code == 200 and "graph-bar" in r.text and f'href="{PORTAL}"' in r.text
    js = doctor.get("/static/share/graph.js")
    assert js.status_code == 200 and "messageHandlers.alert" in js.text
    assert doctor.get("/static/share/cytoscape.min.js").status_code == 200
    css = doctor.get("/static/share/share.css").text
    for query in ("prefers-reduced-motion", "prefers-reduced-transparency", "prefers-contrast: more", "@media print"):
        assert query in css


def test_page_shows_checkins_and_adherence(doctor):
    doctor.post(f"{P}/checkins", headers=H, json={"text": "Mă simt amețită de dimineață."})
    for slot in ("2026-11-13T07:00:00+02:00", "2026-11-13T07:30:00+02:00"):
        doctor.post(f"{P}/doses", headers=H, json={"med_id": "med_05", "scheduled_at": slot, "status": "taken"})
    html = doctor.get(PORTAL).text
    assert "Mă simt amețită de dimineață." in html
    assert "aderență" in html and "% în ultimele 7 zile" in html


# ---------------------------------------------------------------- funcții pure


def test_plural_ro():
    assert plural(1, "medicament", "medicamente") == "1 medicament"
    assert plural(9, "medicament", "medicamente") == "9 medicamente"
    assert plural(0, "alertă gravă", "alerte grave") == "0 alerte grave"
    assert plural(20, "medicament", "medicamente") == "20 de medicamente"
    assert plural(112, "medicament", "medicamente") == "112 medicamente"


def test_adherence_counts_only_past_doses():
    from zoneinfo import ZoneInfo

    tz = ZoneInfo("Europe/Bucharest")
    day = date(2026, 11, 14)

    def schedule(d):
        return {"moments": [{"time": "08:00", "doses": [{"med_id": "m1"}]}, {"time": "20:00", "doses": [{"med_id": "m1"}]}]}

    now = datetime(2026, 11, 14, 12, 0, tzinfo=tz)
    assert adherence([], [], schedule, day, now) is None
    doses = [{"med_id": "m1", "scheduled_at": f"2026-11-{d:02d}T08:00:00+02:00", "status": "taken"} for d in range(8, 15)]
    # 7 zile × dimineața; seara niciodată; azi seara e încă în viitor
    assert adherence([], doses, schedule, day, now) == round(100 * 7 / 13)
