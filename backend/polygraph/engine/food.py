"""Interacțiunile cu alimente (dfi din `kb/curated_dfi.csv`): o alertă per (substanță, aliment)."""

from __future__ import annotations

from polygraph.engine import texts_ro as T
from polygraph.engine.context import Component, Ctx, brand, make_alert
from polygraph.kb import SEVERITY_OF_LEVEL, norm


def analogy_for(ctx: Ctx, c: Component, source_text: str) -> dict | None:
    """Rândurile dfi `class_analogy` nu au coloana „via”: sora e cea din clasa ATC4 numită în sursă."""
    if not (c.sub and c.sub.atc4):
        return None
    text = norm(source_text)
    for sister in ctx.kb.class_members(c.sub.atc4):
        if sister.id == c.sub.id:
            continue
        ro = T.ro_name(sister.inn, sister.dci_ro)
        if norm(ro) in text or norm(sister.inn) in text:
            return {"via": ro, "atc4": sister.atc4}
    return None


def check(ctx: Ctx) -> list[dict]:
    groups: dict[tuple[int, str], list[Component]] = {}
    for c in ctx.components:
        if c.sub:
            for row in ctx.kb.dfi(c.sub.id):
                groups.setdefault((c.sub.id, row["food"]), []).append(c)

    alerts = []
    for (sid, food), comps in groups.items():
        row = next(r for r in ctx.kb.dfi(sid) if r["food"] == food)
        severity = SEVERITY_OF_LEVEL.get(row["level"])
        if severity is None:
            continue
        label = ctx.kb.foods.get(food, {}).get("label_ro") or row["food_ro"] or food
        meds = list(dict.fromkeys(c.med_id for c in comps))
        brands = " / ".join(brand(ctx.med(m)) for m in meds)
        c = comps[0]
        basis = row["basis"] if row["basis"] in ("direct", "curated", "class_analogy") else "direct"
        analogy = analogy_for(ctx, c, row["source"] or "") if basis == "class_analogy" else None
        detail = f"{c.name_ro.capitalize()} ({brands}) + {label}: {row['description'] or 'interacțiune cu alimentul'}"
        if analogy:
            detail += f" {T.analogy_note(analogy['via'])}"
        alerts.append(
            make_alert(
                kind="food",
                severity=severity,
                med_ids=meds,
                title=T.food_title(brands, label),
                patient_text=T.food_patient_text(brands, label),
                detail=detail,
                recommendation=row["management"] or f"Evitați {label} cât luați {brands}.",
                action="avoid_food",
                source={"db": "curated", "ref": f"kb/curated_dfi.csv: {row['source']}", "url": row["source_url"]},
                basis=basis if (basis != "class_analogy" or analogy) else "direct",
                analogy=analogy,
                suffix=food,
            )
        )
    return alerts
