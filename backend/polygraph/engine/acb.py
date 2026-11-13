"""Sarcina anticolinergică (scala ACB, `kb/rules/acb.yaml`): suma scorurilor; ≥ prag → alertă `anticholinergic`."""

from __future__ import annotations

from polygraph.engine import texts_ro as T
from polygraph.engine.context import Ctx, make_alert
from polygraph.kb import norm


def score_of(ctx: Ctx, c) -> int:
    if c.sub and c.sub.id in ctx.kb.acb_by_sub:
        return ctx.kb.acb_by_sub[c.sub.id]
    inn = norm(c.sub.inn if c.sub else c.raw.get("inn"))
    return ctx.kb.acb_by_inn.get(inn, 0)


def total(ctx: Ctx) -> tuple[int, list]:
    """Scorul total (o substanță contează o dată, chiar dacă e în două produse) și componentele care contribuie."""
    seen: dict[str, int] = {}
    contrib = []
    for c in ctx.components:
        s = score_of(ctx, c)
        if s:
            contrib.append(c)
            seen[c.key] = s
    return sum(seen.values()), contrib


def check(ctx: Ctx) -> tuple[int, list[dict]]:
    acb_total, contrib = total(ctx)
    if acb_total < ctx.kb.acb_threshold:
        return acb_total, []
    names = list(dict.fromkeys(f"{c.name_ro} {score_of(ctx, c)}" for c in contrib))
    alert = make_alert(
        kind="anticholinergic",
        severity="moderate",
        med_ids=[c.med_id for c in contrib],
        title=T.acb_title(acb_total),
        patient_text=T.ACB_PATIENT,
        detail=T.acb_detail(acb_total, names),
        recommendation=T.ACB_RECOMMENDATION,
        action="ask_pharmacist",
        source={"db": "acb", "ref": "ACB Scale 2012 (Aging Brain Care / Regenstrief), kb/rules/acb.yaml", "url": None},
    )
    return acb_total, [alert]
