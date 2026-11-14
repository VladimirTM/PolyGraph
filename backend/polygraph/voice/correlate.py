"""Corelarea deterministă a simptomelor cu medicamentele (B5) și răspunsul pentru pacient, din template-uri.

Pentru fiecare simptom:
(a) alertele deschise care explică simptomul prin interacțiunea însăși (harta ALERT_SYMPTOMS: ex. o interacțiune
    cu un anticoagulant → semnele de sângerare) → basis "alert:<id>". Dacă mai multe alerte explică același
    simptom, rămân doar cele cu severitatea cea mai mare. Efectele adverse ale unei singure substanțe nu leagă
    simptomul de o alertă: altfel orice alertă pe amitriptilină ar „explica” toate efectele ei;
(b) celelalte medicamente active cu simptomul printre efectele din adverse_effects.yaml → basis "adverse_effects.yaml".
escalate = orice red_flag sau orice corelare cu o alertă major / critical.
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

from polygraph.engine.context import Component, Ctx
from polygraph.kb import SEV_RANK
from polygraph.voice.understand import Symptom, Understanding

Json = dict[str, Any]

BLEEDING = {"bruising", "bleeding_gums", "nosebleed", "black_stool", "blood_in_urine", "vomiting_blood"}
MYOPATHY = {"muscle_pain", "muscle_weakness", "dark_urine"}
ANTICHOLINERGIC = {"confusion", "drowsiness", "dry_mouth", "constipation", "urinary_retention"}
TRICYCLIC_ELDERLY = {"confusion", "drowsiness", "urinary_retention"}  # ce face triciclicul periculos la vârstnic (Beers)
GI_BLEED = {"stomach_pain", "black_stool", "vomiting_blood"}

OPEN = {"open", "acknowledged"}


def _atcs(ctx: Ctx, alert: Json) -> list[str]:
    ids = set(alert["med_ids"])
    return [c.atc for c in ctx.components if c.med_id in ids and c.atc]


def _has(prefix: str) -> Callable[[Ctx, Json], bool]:
    return lambda ctx, a: any(atc.startswith(prefix) for atc in _atcs(ctx, a))


# (kind-urile alertei, condiția pe substanțele implicate, simptomele explicate)
ALERT_SYMPTOMS: list[tuple[set[str], Callable[[Ctx, Json], bool], set[str]]] = [
    ({"ddi"}, _has("B01A"), BLEEDING),  # anticoagulant + altceva: sângerare
    ({"ddi"}, _has("C10AA"), MYOPATHY),  # statină cu concentrația crescută: afectare musculară
    ({"elderly_pim"}, _has("N06AA"), TRICYCLIC_ELDERLY),  # triciclic la vârstnic
    ({"anticholinergic"}, lambda ctx, a: True, ANTICHOLINERGIC),  # scorul ACB peste prag
    ({"elderly_pim"}, _has("M01A"), GI_BLEED),  # AINS cronic la vârstnic: sângerare digestivă
]


def explained_by(ctx: Ctx, alert: Json) -> set[str]:
    out: set[str] = set()
    for kinds, cond, codes in ALERT_SYMPTOMS:
        if alert["kind"] in kinds and cond(ctx, alert):
            out |= codes
    return out


def _med_has_effect(c: Component, code: str, adverse: dict[int, set[str]]) -> bool:
    return bool(c.sub) and code in adverse.get(c.sub.id, ())


def correlate(ctx: Ctx, alerts: list[Json], symptoms: list[Symptom]) -> tuple[list[Json], bool]:
    """→ (correlations, escalate). Corelările pe alerte vin primele, apoi cele din adverse_effects.yaml."""
    open_alerts = [a for a in alerts if a.get("status", "open") in OPEN]
    explains = {a["id"]: explained_by(ctx, a) for a in open_alerts}
    by_alert: list[Json] = []
    by_effect: list[Json] = []
    escalate = any(s.red_flag for s in symptoms)
    for s in symptoms:
        matched = [a for a in open_alerts if s.code in explains[a["id"]]]
        if matched:
            worst = min(SEV_RANK[a["severity"]] for a in matched)
            matched = [a for a in matched if SEV_RANK[a["severity"]] == worst]
        covered: set[str] = set()
        for a in sorted(matched, key=lambda a: a["id"]):
            by_alert.append({"symptom": s.code, "med_ids": sorted(a["med_ids"]), "basis": f"alert:{a['id']}"})
            covered |= set(a["med_ids"])
            if a["severity"] in ("major", "critical"):
                escalate = True
        rest = sorted(
            {c.med_id for c in ctx.components if c.med_id not in covered and _med_has_effect(c, s.code, ctx.kb.adverse)}
        )
        if rest:
            by_effect.append({"symptom": s.code, "med_ids": rest, "basis": "adverse_effects.yaml"})
    return by_alert + by_effect, escalate


# ---------------------------------------------------------------- răspunsul (template-uri, nu LLM)


def dative(name: str | None) -> str:
    """„Ana” → „Anei”; un nume care nu se termină în -a → „lui Ion”; fără aparținător → „aparținătorului”."""
    if not name:
        return "aparținătorului"
    if name.endswith("a"):
        return name[:-1] + "ei"
    return f"lui {name}"


MAX_ADVICE = 2
QUESTIONS = {"can_i_take", "which_pill_now"}


def unwell_hint(caregiver: str | None) -> str:
    """Fraza pentru un check-in fără simptome: „spuneți-i Anei”, nu „Ana” (Q3-18)."""
    who = dative(caregiver) if caregiver else "cuiva apropiat"
    return f"Dacă nu vă simțiți bine, spuneți-i {who} sau medicului."


def reply_text(
    u: Understanding, correlations: list[Json], escalate: bool, caregiver: str | None, can_take: str | None = None
) -> str:
    """`can_take`: răspunsul X1 (polygraph/voice/can_i_take.py) pentru un medicament din catalog, dacă există."""
    # „Mulțumesc.” doar când pacientul a spus cum se simte; la o întrebare, direct răspunsul.
    parts = [] if u.intent in QUESTIONS and not u.symptoms else ["Mulțumesc."]
    if escalate:
        parts.append(f"I-am trimis {dative(caregiver)} ce mi-ați spus.")
    # Întâi semnele de alarmă, apoi simptomele legate de o alertă, apoi restul, în ordinea spusă.
    linked = {c["symptom"] for c in correlations if c["basis"].startswith("alert:")}
    ordered = sorted(u.symptoms, key=lambda s: (not s.red_flag, s.code not in linked))
    parts += [s.advice for s in ordered[:MAX_ADVICE]]
    if u.intent == "can_i_take":
        dq = u.drug_query
        if can_take:
            parts.append(can_take)
        elif dq and dq["source"] == "patient":
            parts.append(f"{dq['brand']} e pe lista dumneavoastră: uitați-vă pe ecranul „Acum” când îi vine ora.")
        else:
            what = f" {dq['brand']}" if dq else " un medicament nou"
            parts.append(f"Înainte să luați{what}, întrebați medicul de familie.")
    elif u.intent == "which_pill_now":
        parts.append("Pe ecranul „Acum” scrie ce pastilă urmează.")
    elif not u.symptoms:
        parts.append(unwell_hint(caregiver))
    return " ".join(parts)


def feed_event(patient: Json, checkin: Json, alerts: list[Json], meds: list[Json], red_flags: set[str]) -> Json:
    """Evenimentul din Noutăți pentru un check-in escaladat."""
    by_id = {a["id"]: a for a in alerts}
    brands = {m["id"]: (m.get("product") or {}).get("brand") or m["id"] for m in meds}
    red = [s for s in checkin["symptoms"] if s["code"] in red_flags]
    labels = ", ".join(s["label"] for s in checkin["symptoms"]) or "un check-in"
    lines: list[str] = []
    severity = "critical" if red else None
    med_ids: list[str] = []
    for c in checkin["correlations"]:
        med_ids += [m for m in c["med_ids"] if m not in med_ids]
        if c["basis"].startswith("alert:"):
            a = by_id.get(c["basis"][6:])
            if a is None:
                continue
            names = " + ".join(brands.get(m, m) for m in c["med_ids"])
            line = f"Posibil legat de {names} ({a['title']})."
            if line not in lines:
                lines.append(line)
            if severity is None or SEV_RANK[a["severity"]] < SEV_RANK[severity]:
                severity = a["severity"]
    if red:
        lines.insert(0, "Semn de alarmă: " + ", ".join(s["label"] for s in red) + ".")
    return {
        "id": "ev_" + checkin["id"],
        "at": checkin["at"],
        "type": "checkin",
        "severity": severity,
        "title": f"{patient.get('name') or 'Pacientul'} a raportat: {labels}",
        "body": " ".join(lines) or checkin["transcript"],
        "med_ids": med_ids,
        "alert_id": None,
        "checkin_id": checkin["id"],
    }
