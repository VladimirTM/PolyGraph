"""Regulile de orar care nu se pot respecta (B4): fiecare intrare din `Schedule.unsatisfied` → o alertă `timing`
cu `action: ask_doctor` (plan 5.4). Programul se calculează pentru ziua analizei, cu ancorele pacientului."""

from __future__ import annotations

from polygraph.engine import texts_ro as T
from polygraph.engine.context import Ctx, brand, make_alert
from polygraph.schedule import build_schedule


def check(ctx: Ctx) -> list[dict]:
    if not ctx.patient.get("anchors") or not ctx.meds:
        return []
    out = []
    for u in build_schedule(ctx.patient, ctx.meds, ctx.today, ctx.kb)["unsatisfied"]:
        brands = [brand(ctx.med(m)) for m in u["med_ids"]]
        out.append(
            make_alert(
                kind="timing",
                severity="moderate",
                med_ids=u["med_ids"],
                title=T.timing_title(brands),
                patient_text=T.timing_patient_text(ctx.caregiver),
                detail=u["reason"],
                recommendation=T.timing_recommendation(brands),
                action="ask_doctor",
                source={"db": "schedule", "ref": f"kb/rules/timing.yaml: {u['rule']}", "url": None},
                suffix=u["rule"],
            )
        )
    return out
