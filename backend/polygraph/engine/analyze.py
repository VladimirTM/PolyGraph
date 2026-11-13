"""analyze(patient, meds, today) → AnalysisResult: funcție pură (singurul I/O e citirea din kb), deterministă.

Medicamentele cu `end_date < today` sunt ignorate (rămân în istoric, ies din analiză). Rezultatul e sortat după
severitate, apoi kind, apoi id; id-urile sunt deterministe (al_<kind>_<med_ids sortate>[_<regulă / aliment>]).
"""

from __future__ import annotations

from datetime import date
from typing import Any, TypedDict

from polygraph.engine import acb, ddi, duplicate, elderly, expiry, food, timing
from polygraph.engine.context import Component, Ctx, Json
from polygraph.graph.build import build as build_graph
from polygraph.kb import SEV_RANK, Kb, default_kb


class AnalysisResult(TypedDict):
    alerts: list[Json]
    acb_total: int
    graph: Json


def is_active(med: Json, today: date) -> bool:
    end = med.get("end_date")
    if not end:
        return True
    try:
        return date.fromisoformat(end) >= today
    except ValueError:
        return True


def make_ctx(patient: Json, meds: list[Json], today: date, kb: Kb) -> Ctx:
    active = [m for m in meds if is_active(m, today)]
    ctx = Ctx(patient=patient, meds=active, today=today, kb=kb)
    for m in active:
        for s in m.get("substances") or []:
            sub = kb.resolve(s.get("inn"), s.get("dci"), s.get("atc"))
            ctx.components.append(Component(med=m, raw=s, sub=sub))
    return ctx


def sort_key(a: Json) -> tuple:
    return (SEV_RANK[a["severity"]], a["kind"], a["id"])


def run_checks(ctx: Ctx) -> tuple[list[Json], int]:
    ddi_alerts = ddi.check(ctx)
    alerts = [*ddi_alerts, *food.check(ctx), *duplicate.check(ctx), *elderly.check(ctx, ddi_alerts), *expiry.check(ctx)]
    alerts += timing.check(ctx)
    acb_total, acb_alerts = acb.check(ctx)
    alerts += acb_alerts
    return sorted({a["id"]: a for a in alerts}.values(), key=sort_key), acb_total


def analyze(
    patient: Json,
    meds: list[Json],
    today: date,
    kb: Kb | None = None,
    checkins: list[Json] | None = None,
) -> AnalysisResult:
    ctx = make_ctx(patient, meds, today, kb or default_kb())
    alerts, acb_total = run_checks(ctx)
    return {"alerts": alerts, "acb_total": acb_total, "graph": build_graph(ctx, alerts, checkins or [])}


def new_alerts(before: list[dict[str, Any]], after: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Alertele din `after` care nu existau în `before` (după id), pentru /what-if."""
    old = {a["id"] for a in before}
    return [a for a in after if a["id"] not in old]
