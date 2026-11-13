"""Cutiile expirate: `product.expiry < today` → `expired`, `major`, acțiunea `replace_box`."""

from __future__ import annotations

from datetime import date

from polygraph.engine import texts_ro as T
from polygraph.engine.context import Ctx, brand, make_alert


def check(ctx: Ctx) -> list[dict]:
    out = []
    for m in ctx.meds:
        raw = (m.get("product") or {}).get("expiry")
        if not raw:
            continue
        try:
            expiry = date.fromisoformat(raw)
        except ValueError:
            continue
        if expiry < ctx.today:
            b = brand(m)
            out.append(
                make_alert(
                    kind="expired",
                    severity="major",
                    med_ids=[m["id"]],
                    title=T.expired_title(b),
                    patient_text=T.expired_patient_text(b),
                    detail=f"{b}: data de expirare de pe cutie este {expiry.strftime('%d.%m.%Y')}.",
                    recommendation=T.EXPIRED_RECOMMENDATION,
                    action="replace_box",
                    source={"db": "app", "ref": "data de expirare (cutie / DataMatrix)", "url": None},
                )
            )
    return out
