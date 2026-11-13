"""Dublurile terapeutice: (a) aceeași substanță în ≥ 2 produse active; (b) aceeași clasă ATC4 dintr-o listă albă
de clase cu risc la dublare; (c) perechile din tabela kb `duplication`. Toate `major`."""

from __future__ import annotations

from itertools import combinations

from polygraph.engine import texts_ro as T
from polygraph.engine.context import Component, Ctx, brand, make_alert

# AINS, benzodiazepine anxiolitice / hipnotice, IPP, antivitamine K, antiagregante, diuretice de ansă
RISKY_CLASSES = {
    "M01AE": "antiinflamatoare (AINS, derivați de acid propionic)",
    "M01AB": "antiinflamatoare (AINS, derivați de acid acetic)",
    "M01AC": "antiinflamatoare (AINS, oxicami)",
    "M01AX": "alte antiinflamatoare (AINS)",
    "N05BA": "benzodiazepine (anxiolitice)",
    "N05CD": "benzodiazepine (somnifere)",
    "A02BC": "inhibitori de pompă de protoni",
    "B01AA": "antivitamine K (anticoagulante)",
    "B01AC": "antiagregante plachetare",
    "C03CA": "diuretice de ansă",
}
# Plan B2: M01A, N05BA, N05CD, A02BC, B01AA, B01AC, C03C (prefixe ATC4 sau mai scurte)
RISKY_PREFIXES = ("M01A", "N05BA", "N05CD", "A02BC", "B01AA", "B01AC", "C03C")


def _alert(ctx: Ctx, comps: list[Component], same: bool, why: str) -> dict:
    meds = sorted(dict.fromkeys(c.med_id for c in comps))
    brands = [brand(ctx.med(m)) for m in meds]
    if same:
        detail = f"{comps[0].name_ro.capitalize()} apare în {' și '.join(brands)}: aceeași substanță, luată de două ori."
    else:
        names = ", ".join(dict.fromkeys(f"{c.name_ro} ({brand(c.med)})" for c in comps))
        detail = f"{names}: {why}; efectele (și riscurile) se adună."
    return make_alert(
        kind="duplicate",
        severity="major",
        med_ids=meds,
        title=T.duplicate_title(same),
        patient_text=T.duplicate_patient_text(brands, ctx.caregiver),
        detail=detail,
        recommendation=T.duplicate_recommendation(),
        action="ask_pharmacist",
        source={"db": "app", "ref": "dublură terapeutică (aceeași substanță / aceeași clasă ATC)", "url": None},
    )


def check(ctx: Ctx) -> list[dict]:
    alerts: dict[str, dict] = {}

    def add(a: dict) -> None:
        alerts.setdefault(a["id"], a)

    by_key: dict[str, list[Component]] = {}
    for c in ctx.components:
        by_key.setdefault(c.key, []).append(c)
    same_meds: set[frozenset[str]] = set()
    for comps in by_key.values():
        meds = {c.med_id for c in comps}
        if len(meds) >= 2:
            same_meds.add(frozenset(meds))
            add(_alert(ctx, comps, True, ""))

    by_class: dict[str, list[Component]] = {}
    for c in ctx.components:
        if c.atc4 and c.atc4.startswith(RISKY_PREFIXES):
            by_class.setdefault(c.atc4, []).append(c)
    for atc4, comps in by_class.items():
        meds = {c.med_id for c in comps}
        keys = {c.key for c in comps}
        if len(meds) >= 2 and len(keys) >= 2 and frozenset(meds) not in same_meds:
            add(_alert(ctx, comps, False, f"aceeași clasă ({RISKY_CLASSES.get(atc4, atc4)})"))

    if ctx.kb.duplication:
        for a, b in combinations(ctx.components, 2):
            if a.med_id != b.med_id and a.sub and b.sub:
                note = ctx.kb.duplication.get(frozenset((a.sub.id, b.sub.id)))
                if note:
                    add(_alert(ctx, [a, b], False, note))
    return list(alerts.values())
