"""B4: solverul de program. Rulează și în CI, pe o kb mică construită din kb/rules/timing.yaml (aceleași reguli ca
kb.sqlite); golden-ul se repetă pe kb-ul real dacă e construit.

T-B4-01 golden pe pacientul demo · T-B4-02 proprietate pe 200 de regimuri aleatoare · T-B4-03 ancore schimbate.
"""

from __future__ import annotations

import copy
import json
import os
import random
import sqlite3
import time

import pytest
import validate as contracts
from engine_helpers import DEMO, FIX, MED_09, TODAY, demo, med, real_kb
from fastapi.testclient import TestClient

from polygraph.api import main
from polygraph.engine import analyze
from polygraph.kb import Kb, norm
from polygraph.schedule import build_schedule
from polygraph.store import Store

EXPECTED = json.loads((FIX / "expected_schedule.json").read_text(encoding="utf-8"))
MEAL_FOODS = ("before_meal", "with_meal", "after_meal")
EXTRA_INNS = [("cholecalciferol", "COLECALCIFEROLUM", "A11CC05")]


@pytest.fixture(scope="module")
def rules_kb(tmp_path_factory) -> Kb:
    import build  # kb/build.py
    import load_rules

    rules = load_rules.load_all()
    subs = [(r.inn, None, r.atc) for r in rules["timing"].rules] + EXTRA_INNS
    path = tmp_path_factory.mktemp("kb") / "kb.sqlite"
    conn = sqlite3.connect(path)
    conn.executescript(build.SCHEMA)
    by_inn = {}
    for i, (inn, dci, atc) in enumerate(subs, start=1):
        conn.execute("INSERT INTO substance(id, inn, dci_ro, atc) VALUES (?, ?, ?, ?)", (i, norm(inn), dci, atc))
        by_inn[norm(inn)] = i
    load_rules.write_rules(conn, rules, by_inn)
    conn.commit()
    conn.close()
    return Kb(path)


@pytest.fixture(scope="module")
def timing_rules(rules_kb) -> list[dict]:
    return list(rules_kb.timing.values())


def shape(schedule: dict) -> list[tuple]:
    """Golden-ul compară orele, etichetele și dozele (med_id, qty); textele nu se compară."""
    return [(m["time"], m["label"], sorted((d["med_id"], d["qty"]) for d in m["doses"])) for m in schedule["moments"]]


def run(kb, patient, meds, day=TODAY):
    t0 = time.perf_counter()
    out = build_schedule(patient, meds, day, kb)
    return out, (time.perf_counter() - t0) * 1000


# ---------------------------------------------------------------- verificatorul independent


def to_min(clock: str) -> int:
    h, m = clock.split(":")
    return int(h) * 60 + int(m)


def hard_violations(schedule: dict, meds: list[dict], kb: Kb) -> list[str]:
    """Reverifică regulile dure din timing.yaml pe programul ieșit, fără codul solverului."""
    a = {k: to_min(v) for k, v in schedule["anchors"].items()}
    meals = sorted((a["breakfast"], a["lunch"], a["dinner"]))
    by_id = {m["id"]: m for m in meds}

    def rules_of(m):
        out = []
        for s in m["substances"]:
            sub = kb.resolve(s.get("inn"), s.get("dci"), s.get("atc"))
            if sub and sub.id in kb.timing:
                out.append(kb.timing[sub.id])
        return out

    def matches(m, other):
        if other[:1].isupper() and other[1:2].isdigit():
            return any((s.get("atc") or "").startswith(other) for s in m["substances"])
        return any(norm(s.get("inn")) == norm(other) for s in m["substances"])

    placed = [(to_min(mo["time"]), d["med_id"], len(mo["doses"])) for mo in schedule["moments"] for d in mo["doses"]]
    bad = []
    for t, mid, together in placed:
        rules = rules_of(by_id[mid])
        food = next((r["with_food"] for r in rules if r["with_food"] != "any"), by_id[mid]["dosage"]["with_food"])
        if food == "empty_stomach":
            nxt = [x for x in meals if x >= t]
            prev = [x for x in meals if x <= t]
            if (nxt and nxt[0] - t < 30) or (prev and t - prev[-1] < 120):
                bad.append(f"{mid} empty_stomach {t}")
        elif food == "before_meal" and not any(15 <= x - t <= 60 for x in meals):
            bad.append(f"{mid} before_meal {t}")
        elif food in ("with_meal", "after_meal") and not any(0 <= t - x <= 30 for x in meals):
            bad.append(f"{mid} {food} {t}")
        for r in rules:
            if r.get("latest_time") and t > to_min(r["latest_time"]):
                bad.append(f"{mid} latest_time")
            if r.get("alone") and together > 1:
                bad.append(f"{mid} alone")
            for sep in r.get("min_separation") or []:
                gap = sep["hours"] * 60
                for t2, mid2, _ in placed:
                    if mid2 == mid or not matches(by_id[mid2], sep["other"]):
                        continue
                    if sep["direction"] == "before" and t + gap > t2:
                        bad.append(f"{mid} before {mid2}")
                    if sep["direction"] == "after" and t2 + gap > t:
                        bad.append(f"{mid} after {mid2}")
                    if sep["direction"] == "either" and abs(t - t2) < gap:
                        bad.append(f"{mid} either {mid2}")
    times = {}
    for t, mid, _ in placed:
        assert t not in times.setdefault(mid, set()), f"două doze de {mid} la aceeași oră"
        times[mid].add(t)
    return bad


# ---------------------------------------------------------------- T-B4-01


@pytest.mark.parametrize("which", ["rules", "real"])
def test_golden_demo(which, rules_kb):
    kb = rules_kb if which == "rules" else real_kb()
    patient, meds = demo()
    got, ms = run(kb, patient, meds)
    assert not contracts.schema_errors("schedule", got)
    assert shape(got) == shape(EXPECTED)
    assert got["unsatisfied"] == []
    assert got["solver"]["moments_count"] == 5
    assert ms < 100, f"solver {ms:.1f} ms"


def test_golden_reasons_are_from_rules(rules_kb):
    got, _ = run(rules_kb, *demo())
    doses = {(m["time"], d["med_id"]): d for m in got["moments"] for d in m["doses"]}
    euthyrox = doses[("07:00", "med_05")]
    assert "Singur, ca nimic să nu-i scadă absorbția" in euthyrox["reasons"]
    assert euthyrox["reasons"][0].endswith("(RCP Euthyrox)")
    assert "La cel puțin 4 ore după Euthyrox" in doses[("13:00", "med_06")]["reasons"]
    assert all(d["reasons"] and d["instruction"] for d in doses.values())


def test_with_med_09_is_still_valid(rules_kb):
    patient, meds = demo()
    got, _ = run(rules_kb, patient, [*meds, copy.deepcopy(MED_09)])
    assert not contracts.schema_errors("schedule", got)
    assert got["unsatisfied"] == []
    times = sorted(m["time"] for m in got["moments"] for d in m["doses"] if d["med_id"] == "med_09")
    assert len(times) == 2 and times[0] < "12:00" < times[1]


# ---------------------------------------------------------------- T-B4-02


def random_regimen(rng: random.Random, rules: list[dict]) -> list[dict]:
    meds, doses = [], 0
    for i, r in enumerate(rng.sample(rules, rng.randint(2, min(9, len(rules))))):
        # ca pe o rețetă reală: ce se ia la masă nu se prescrie la culcare
        allowed = ("morning", "noon", "evening") if r["with_food"] in MEAL_FOODS else ("morning", "noon", "evening", "bedtime")
        if r.get("latest_time"):
            allowed = ("morning", "noon")
        slots = [s for s in allowed if rng.random() < 0.35] or [allowed[0]]
        if r.get("interval_hours") == 12:
            slots = ["morning", "evening"]
        if doses + len(slots) > 15:
            break
        doses += len(slots)
        m = med(f"med_{i:02d}", r["inn"].title(), r["inn"], r["atc"])
        m["dosage"]["pattern"] = {s: (1 if s in slots else 0) for s in ("morning", "noon", "evening", "bedtime")}
        m["dosage"]["with_food"] = rng.choice(["any", r["with_food"]])
        meds.append(m)
    return meds


def test_random_regimens_respect_hard_rules(rules_kb, timing_rules):
    rng = random.Random(4)
    patient = copy.deepcopy(DEMO["patient"])
    worst, slowest, relaxed = 0.0, None, 0
    for _ in range(200):
        meds = random_regimen(rng, timing_rules)
        got, ms = run(rules_kb, patient, meds)
        if ms > worst:
            worst, slowest = ms, meds
        assert not contracts.schema_errors("schedule", got)
        assert sum(len(m["doses"]) for m in got["moments"]) == sum(
            sum(1 for v in m["dosage"]["pattern"].values() if v) for m in meds
        )
        bad = hard_violations(got, meds, rules_kb)
        if got["unsatisfied"]:
            relaxed += 1
            assert bad, got["unsatisfied"]  # ce raportează solverul se vede și în verificare
        else:
            assert not bad, bad
    # O singură pauză a runner-ului (GC, CI încărcat) nu e o regresie: regimul cel mai lent se re-măsoară.
    worst = min(run(rules_kb, patient, slowest)[1] for _ in range(3))
    # Runner-ele GitHub sunt de 2–3 ori mai lente decât un laptop; local bugetul rămâne 100 ms.
    budget = 250 if os.environ.get("CI") else 100
    assert worst < budget, f"cel mai lent regim: {worst:.1f} ms (buget {budget} ms)"
    assert relaxed < 100, relaxed  # majoritatea regimurilor au soluție fără relaxare


# ---------------------------------------------------------------- T-B4-03


def test_earlier_wake_moves_the_morning(rules_kb):
    patient, meds = demo()
    patient["anchors"].update(wake="05:30", breakfast="06:30")
    got, _ = run(rules_kb, patient, meds)
    assert got["unsatisfied"] == []
    want = shape(EXPECTED)
    shifted = [("05:30", *want[0][1:]), ("06:00", *want[1][1:]), ("06:30", *want[2][1:]), *want[3:]]
    assert shape(got) == shifted
    assert not hard_violations(got, meds, rules_kb)


def test_only_wake_changes(rules_kb):
    patient, meds = demo()
    patient["anchors"]["wake"] = "05:30"
    got, _ = run(rules_kb, patient, meds)
    assert got["unsatisfied"] == []
    first = got["moments"][0]
    assert first["time"] == "05:30" and [d["med_id"] for d in first["doses"]] == ["med_05"]
    assert not hard_violations(got, meds, rules_kb)


# ---------------------------------------------------------------- relaxarea și restul


def test_impossible_separation_is_reported_and_alerted(rules_kb):
    levo = med("med_01", "Euthyrox", "levothyroxine", "H03AA01")
    calcium = med("med_02", "Calciu", "calcium carbonate", "A12AA04")  # tot dimineața: 4 ore nu încap până la prânz
    patient = copy.deepcopy(DEMO["patient"])
    patient["anchors"]["lunch"] = "10:30"
    patient["anchors"]["breakfast"] = "08:00"
    got, _ = run(rules_kb, patient, [levo, calcium])
    assert not contracts.schema_errors("schedule", got)
    assert [u["rule"] for u in got["unsatisfied"]] == ["min_separation"]
    assert got["unsatisfied"][0]["med_ids"] == ["med_01", "med_02"]

    alerts = analyze(patient, [levo, calcium], TODAY, kb=rules_kb)["alerts"]
    timing = [a for a in alerts if a["kind"] == "timing"]
    assert len(timing) == 1 and timing[0]["action"] == "ask_doctor"
    assert timing[0]["id"] == "al_timing_med_01_med_02_min_separation"
    assert not contracts.schema_errors("alert", timing[0])


def test_skips_as_needed_ended_and_future_meds(rules_kb):
    patient, meds = demo()
    meds[0]["dosage"]["as_needed"] = True
    meds[1]["end_date"] = "2026-11-13"
    meds[2]["start_date"] = "2026-11-15"
    got, _ = run(rules_kb, patient, meds)
    ids = {d["med_id"] for m in got["moments"] for d in m["doses"]}
    assert ids == {"med_04", "med_05", "med_06", "med_07", "med_08"}


def test_no_meds(rules_kb):
    got, _ = run(rules_kb, copy.deepcopy(DEMO["patient"]), [])
    assert got["moments"] == [] and got["solver"]["moments_count"] == 0
    assert not contracts.schema_errors("schedule", got)


def test_demo_analysis_has_no_timing_alert(rules_kb):
    alerts = analyze(*demo(), TODAY, kb=rules_kb)["alerts"]
    assert not [a for a in alerts if a["kind"] == "timing"]


# ---------------------------------------------------------------- rutele


@pytest.fixture
def client(rules_kb, monkeypatch):
    monkeypatch.setenv("PG_TODAY", "2026-11-14")
    monkeypatch.setenv("DEMO_MODE", "1")
    main.configure(store=Store(":memory:"), kb=rules_kb)
    main.reset_demo()
    with TestClient(main.app) as c:
        yield c
    main.configure(None, None)


H = {"X-Patient-Token": "demo-token"}
P = "/v1/patients/pat_demo"


def test_schedule_route(client):
    r = client.get(f"{P}/schedule", headers=H)
    assert r.status_code == 200
    body = r.json()
    assert not contracts.schema_errors("schedule", body)
    assert body["date"] == "2026-11-14" and shape(body) == shape(EXPECTED)
    assert client.get(f"{P}/schedule?date=2026-11-20", headers=H).json()["date"] == "2026-11-20"
    assert client.get(f"{P}/schedule").status_code == 401
    assert client.get(f"{P}/schedule?date=ieri", headers=H).status_code == 422


def test_schedule_follows_meds_and_anchors(client):
    client.delete(f"{P}/meds/med_05", headers=H)
    client.patch(P, headers=H, json={"anchors": {**DEMO["patient"]["anchors"], "dinner": "18:00"}})
    body = client.get(f"{P}/schedule", headers=H).json()
    ids = {d["med_id"] for m in body["moments"] for d in m["doses"]}
    assert "med_05" not in ids
    assert "18:00" in [m["time"] for m in body["moments"]]


def test_doses_are_idempotent(client):
    dose = {"med_id": "med_05", "scheduled_at": "2026-11-14T07:00:00+02:00", "status": "taken"}
    r1 = client.post(f"{P}/doses", headers=H, json=dose)
    assert r1.status_code == 200 and not contracts.schema_errors("dose", r1.json())
    client.post(f"{P}/doses", headers=H, json={**dose, "scheduled_at": "2026-11-14T05:00:00Z"})
    client.post(f"{P}/doses", headers=H, json={**dose, "status": "pending"})
    stored = main.store().list_doses("pat_demo")
    assert len(stored) == 1 and stored[0]["status"] == "pending"
    assert client.post(f"{P}/doses", headers=H, json={**dose, "status": "maybe"}).status_code == 422
    assert client.post(f"{P}/doses", headers=H, json={**dose, "med_id": "med_99"}).status_code == 404
    assert client.post(f"{P}/doses", json=dose).status_code == 401
