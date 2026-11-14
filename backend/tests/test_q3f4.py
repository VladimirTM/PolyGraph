"""Q3F4: datele din portal spuse ca în aplicație („Azi, 14:00” / „joi, 12 nov., 14:00”); tipărirea păstrează data completă."""

from __future__ import annotations

import json
from datetime import date, datetime
from pathlib import Path

import pytest

from polygraph.share.view import TZ, recent_checkins, relative_day

FIXTURE = json.loads((Path(__file__).parents[2] / "contracts" / "fixtures" / "date_words.json").read_text())
TODAY = datetime.fromisoformat(FIXTURE["now"]).astimezone(TZ).date()


def test_fixture_is_in_the_portal_timezone():
    assert FIXTURE["timezone"] == TZ.key
    assert TODAY == date(2026, 11, 14)


@pytest.mark.parametrize("case", FIXTURE["cases"], ids=lambda c: c["text"])
def test_date_words(case):
    """T-Q3F4-01: aceleași perechi le verifică și XCTest pe `PgFormat.relativeDay`."""
    assert relative_day(case["at"], TODAY) == case["text"]


def test_unreadable_moment_is_left_as_is():
    assert relative_day("ieri seara", TODAY) == "ieri seara"


def test_checkin_when_uses_relative_day():
    checkins = [
        {"id": "ci_1", "at": "2026-11-12T12:00:00Z", "text": "amețesc", "reply_text": "", "escalate": True},
        {"id": "ci_2", "at": "2026-11-14T11:25:00Z", "text": "bine", "reply_text": "", "escalate": False},
    ]
    out = recent_checkins(checkins, TODAY)
    assert [c["when"] for c in out] == ["Azi, 13:25", "joi, 12 nov., 14:00"]


@pytest.fixture
def portal(monkeypatch):
    from engine_helpers import real_kb
    from fastapi.testclient import TestClient

    from polygraph.api import main
    from polygraph.store import Store

    monkeypatch.setenv("PG_TODAY", "2026-11-14")
    monkeypatch.setenv("DEMO_MODE", "1")
    monkeypatch.delenv("PG_DOCTOR_CODE", raising=False)
    main.configure(store=Store(":memory:"), kb=real_kb())
    main.reset_demo()
    with TestClient(main.app) as c:
        assert c.post("/portal/login", data={"code": "medic-demo"}, follow_redirects=False).status_code in (302, 303)
        yield c
    main.configure(None, None)


def test_screen_is_relative_print_keeps_full_date(portal):
    page = portal.get("/portal/patients/pat_demo").text
    updated = page.split("Actualizată ", 1)[1][:40]
    assert ".2026" not in updated.split(".", 1)[0] and not updated[0].isdigit()
    printed = portal.get("/portal/patients/pat_demo/print").text
    assert "generată la " in printed
    assert ".2026, " in printed.split("generată la ", 1)[1][:30]
