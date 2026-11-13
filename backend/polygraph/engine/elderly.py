"""Medicamentele potențial nepotrivite la vârstnici (Beers 2023 / STOPP, `kb/rules/elderly.yaml`), pe coduri ATC."""

from __future__ import annotations

from datetime import date

from polygraph.engine import texts_ro as T
from polygraph.engine.context import Component, Ctx, make_alert

BEERS_NOTE_MARK = " Evaluat prin analogie"


def _matches(atc: str | None, exact: list[str] | None, prefixes: list[str] | None, exclude: list[str]) -> bool:
    if not atc:
        return False
    if any(atc.startswith(x) for x in exclude):
        return False
    return bool((exact and atc in exact) or (prefixes and any(atc.startswith(p) for p in prefixes)))


def _days_since(start: str | None, today: date) -> int | None:
    if not start:
        return None
    try:
        return (today - date.fromisoformat(start)).days
    except ValueError:
        return None


def _daily_mg(c: Component) -> float | None:
    mg = c.raw.get("strength_mg")
    if mg is None:
        return None
    pattern = (c.med.get("dosage") or {}).get("pattern") or {}
    per_day = sum(v or 0 for v in pattern.values())
    return mg * per_day if per_day else mg


def _alert(ctx: Ctx, rule: dict, med_ids: list[str], extra: str = "") -> dict:
    sev = rule["severity"]
    src = rule["source"]
    return make_alert(
        kind="elderly_pim",
        severity=sev,
        med_ids=med_ids,
        title=rule["title"],
        patient_text=T.elderly_patient_text(sev, ctx.caregiver),
        detail=rule["detail"] + extra,
        recommendation=rule["recommendation"],
        action="contact_doctor" if sev in ("critical", "major") else "ask_pharmacist",
        source={"db": "beers" if "Beers" in src else "stopp", "ref": src, "url": None},
        suffix=rule["id"],
    )


def add_note_to_ddi(alert: dict, rule: dict) -> None:
    title = rule["title"]
    note = f" Și criteriul Beers 2023: {title[0].lower()}{title[1:]}, de evitat la vârstnici."
    detail = alert["detail"]
    i = detail.find(BEERS_NOTE_MARK)
    alert["detail"] = detail + note if i < 0 else detail[:i] + note + detail[i:]


def check(ctx: Ctx, ddi_alerts: list[dict]) -> list[dict]:
    age = ctx.age
    if age is None or age < ctx.kb.age_min:
        return []
    ddi_by_meds = {frozenset(a["med_ids"]): a for a in ddi_alerts}
    out: list[dict] = []
    for rule in ctx.kb.elderly_rules:
        exclude = rule.get("exclude_atc") or []
        if rule.get("count_classes_min"):
            hit_meds: set[str] = set()
            n = 0
            for sel in rule["classes"].values():
                prefixes, excl = (sel["atc_prefix"], sel.get("exclude_atc") or []) if isinstance(sel, dict) else (sel, [])
                meds = {c.med_id for c in ctx.components if _matches(c.atc, None, prefixes, excl)}
                if meds:
                    n += 1
                    hit_meds |= meds
            if n >= rule["count_classes_min"]:
                out.append(_alert(ctx, rule, sorted(hit_meds)))
            continue

        hits = [c for c in ctx.components if _matches(c.atc, rule.get("atc"), rule.get("atc_prefix"), exclude)]
        seen: set[str] = set()
        for c in hits:
            if c.med_id in seen:
                continue
            seen.add(c.med_id)
            with_prefix = rule.get("with_atc_prefix")
            if with_prefix:
                for other in ctx.components:
                    if other.med_id == c.med_id or not _matches(other.atc, None, with_prefix, []):
                        continue
                    ddi = ddi_by_meds.get(frozenset((c.med_id, other.med_id)))
                    if ddi is not None:  # aceeași pereche are deja alerta ddi: doar mențiunea Beers în detail
                        add_note_to_ddi(ddi, rule)
                    else:
                        out.append(_alert(ctx, rule, [c.med_id, other.med_id]))
                continue
            cond = rule.get("condition") or {}
            extra = ""
            if cond.get("duration_days_min"):
                days = _days_since(c.med.get("start_date"), ctx.today)
                if days is None:
                    extra = f" Se aplică dacă îl luați de mai mult de {cond['duration_days_min']} de zile."
                elif days < cond["duration_days_min"]:
                    continue
            if cond.get("strength_mg_gt") is not None:
                daily = _daily_mg(c)
                if daily is None or daily <= cond["strength_mg_gt"]:
                    continue
            out.append(_alert(ctx, rule, [c.med_id], extra))
    return list({a["id"]: a for a in out}.values())
