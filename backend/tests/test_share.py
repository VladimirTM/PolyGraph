"""B6: pagina farmacistului, fișa de tipărit și graful (polygraph/share), pe kb-ul real și un app.sqlite în memorie."""

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


def new_share(client) -> str:
    r = client.post(f"{P}/share", headers=H)
    assert r.status_code == 201
    body = r.json()
    ok("share_link", body)
    assert body["url"].endswith(f"/share/{body['share_token']}")
    return body["share_token"]


def alerts(client) -> list[dict]:
    return client.get(f"{P}/analysis", headers=H).json()["alerts"]


def test_share_needs_patient_token(client):
    assert client.post(f"{P}/share").status_code == 401


def test_share_expires_in_72_hours(client):
    body = client.post(f"{P}/share", headers=H).json()
    left = datetime.fromisoformat(body["expires_at"].replace("Z", "+00:00")) - datetime.now(UTC)
    assert timedelta(hours=71, minutes=59) < left <= timedelta(hours=72)


def test_page_has_summary_alerts_and_sections(client):
    token = new_share(client)
    start = time.perf_counter()
    r = client.get(f"/share/{token}")
    assert time.perf_counter() - start < 2
    assert r.status_code == 200 and r.headers["content-type"].startswith("text/html")
    html = r.text
    assert "Maria, 78 de ani" in html
    assert "Fișă generată de PolyGraph, nu înlocuiește evaluarea profesională" in html
    assert "8 medicamente de la 5 medici" in html and "5 alerte grave" in html and "ACB 3" in html
    for a in alerts(client):
        assert f'id="alert-{a["id"]}"' in html
    # ordinea importanței: rezumatul, alertele grave, medicamentele, restul
    assert html.index("h-summary") < html.index("h-grave") < html.index("h-meds") < html.index("h-other")
    for section in ("h-graph", "h-checkins", "h-schedule"):
        assert section in html
    assert "Sintrom 4 mg" in html and "acenocumarol" in html and "B01AA07" in html


def test_page_headers_keep_the_token_private(client):
    r = client.get(f"/share/{new_share(client)}")
    assert r.headers["referrer-policy"] == "no-referrer"
    assert r.headers["cache-control"] == "no-store"
    assert "script-src 'self'" in r.headers["content-security-policy"]


def test_t_b6_01_unknown_or_expired_token_is_friendly_404(client):
    r = client.get("/share/nu-exista-acest-token")
    assert r.status_code == 404 and "Linkul a expirat" in r.text and "Maria" not in r.text
    main.store().create_share("token-expirat-de-test", "pat_demo", "2026-01-01T00:00:00Z")
    for path in ("", "/print", "/graph", "/graph?embed=1"):
        r = client.get(f"/share/token-expirat-de-test{path}")
        assert r.status_code == 404, path
        assert "Maria" not in r.text and "Sintrom" not in r.text
    aid = alerts(client)[0]["id"]
    assert client.post(f"/share/token-expirat-de-test/alerts/{aid}/verify", json={"note": "x"}).status_code == 404


def test_t_b6_02_print_has_every_major_and_critical_alert(client):
    r = client.get(f"/share/{new_share(client)}/print")
    assert r.status_code == 200
    html = r.text
    grave = [a for a in alerts(client) if a["severity"] in ("major", "critical")]
    assert grave
    for a in grave:
        assert str(escape(a["title"])) in html
    assert "Reconcilierea medicației" in html and "Semnătura și parafa" in html
    assert "Întrebări propuse pentru consultație" in html
    assert "cytoscape" not in html and "verify-form" not in html


def test_t_b6_03_pharmacist_note_is_escaped(client):
    token = new_share(client)
    aid = alerts(client)[0]["id"]
    note = "<script>alert(1)</script> & <b>gata</b>"
    r = client.post(f"/share/{token}/alerts/{aid}/verify", json={"note": note})
    assert r.status_code == 200
    for path in ("", "/print"):
        html = client.get(f"/share/{token}{path}").text
        assert "<script>alert(1)</script>" not in html and "<b>gata</b>" not in html
        assert "&lt;script&gt;alert(1)&lt;/script&gt; &amp; &lt;b&gt;gata&lt;/b&gt;" in html


def test_verify_reaches_app_alert_and_feed(client):
    token = new_share(client)
    aid = next(a["id"] for a in alerts(client) if a["severity"] == "major")
    r = client.post(f"/share/{token}/alerts/{aid}/verify", json={"note": "INR verificat ieri, 2,4."})
    assert r.status_code == 200
    body = r.json()
    ok("alert", body)
    assert body["status"] == "verified_by_pharmacist" and body["resolution"]["by"] == "pharmacist"
    # aplicația vede verificarea la următorul polling (A3) și în Noutăți (A5)
    after = next(a for a in alerts(client) if a["id"] == aid)
    assert after["status"] == "verified_by_pharmacist" and after["resolution"]["note"] == "INR verificat ieri, 2,4."
    events = client.get(f"{P}/feed", headers=H).json()
    ev = next(e for e in events if e["type"] == "pharmacist_verified")
    ok("feed_event", ev)
    assert ev["alert_id"] == aid and ev["body"] == "INR verificat ieri, 2,4."
    assert "Verificat de farmacist" in client.get(f"/share/{token}").text


def test_verify_rejects_unknown_alert_and_extra_fields(client):
    token = new_share(client)
    assert client.post(f"/share/{token}/alerts/al_nu_exista/verify", json={}).status_code == 404
    aid = alerts(client)[0]["id"]
    assert client.post(f"/share/{token}/alerts/{aid}/verify", json={"note": "x", "by": "doctor"}).status_code == 422
    assert client.post(f"/share/{token}/alerts/{aid}/verify", json={"note": "x" * 1001}).status_code == 422


def test_graph_embed_for_the_app(client):
    token = new_share(client)
    r = client.get(f"/share/{token}/graph?embed=1")
    assert r.status_code == 200
    assert 'class="graph-page embed"' in r.text and 'id="graph-data"' in r.text
    assert "graph-bar" not in r.text
    assert "graph-bar" in client.get(f"/share/{token}/graph").text
    js = client.get("/static/share/graph.js")
    assert js.status_code == 200 and "messageHandlers.alert" in js.text
    assert client.get("/static/share/cytoscape.min.js").status_code == 200
    css = client.get("/static/share/share.css").text
    for query in ("prefers-reduced-motion", "prefers-reduced-transparency", "prefers-contrast: more", "@media print"):
        assert query in css


def test_page_shows_checkins_and_adherence(client):
    client.post(f"{P}/checkins", headers=H, json={"text": "Mă simt amețită de dimineață."})
    for slot in ("2026-11-13T07:00:00+02:00", "2026-11-13T07:30:00+02:00"):
        client.post(f"{P}/doses", headers=H, json={"med_id": "med_05", "scheduled_at": slot, "status": "taken"})
    html = client.get(f"/share/{new_share(client)}").text
    assert "Mă simt amețită de dimineață." in html
    assert "aderență" in html and "% în ultimele 7 zile" in html


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
    doses = [
        {"med_id": "m1", "scheduled_at": f"2026-11-{d:02d}T08:00:00+02:00", "status": "taken"} for d in range(8, 15)
    ]  # 7 zile × dimineața; seara niciodată; azi seara e încă în viitor
    assert adherence([], doses, schedule, day, now) == round(100 * 7 / 13)
