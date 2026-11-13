"""Interacțiunile medicament–medicament (plan 5.3).

Pentru fiecare pereche de substanțe din medicamente diferite, nivelul vine, în ordine, din:
(1) `kb/curated_ddi.csv` (rândurile curate, cu basis-ul lor; un rând curat `Unknown` oprește regula de clasă);
(2) nivelul DDInter direct;
(3) regula de clasă pentru `Unknown`: o soră din aceeași clasă ATC4 (a oricăreia dintre substanțe) cu nivel pentru
    aceeași pereche; dacă sunt mai multe, cea mai gravă, apoi prima după INN;
(4) altfel nicio alertă (doar o muchie gri în graf).
O singură alertă per pereche de medicamente: cea mai gravă dintre perechile lor de substanțe.
"""

from __future__ import annotations

from dataclasses import dataclass
from itertools import combinations

from polygraph.engine import texts_ro as T
from polygraph.engine.context import Component, Ctx, brand, make_alert, specialty
from polygraph.kb import SEV_RANK, SEVERITY_OF_LEVEL, Ddi, Kb, Substance

DDINTER_URL = "https://ddinter2.scbdd.com/"


@dataclass(frozen=True)
class Finding:
    a: Component
    b: Component
    severity: str
    basis: str
    level: str
    ddi: Ddi | None  # rândul direct (curated sau DDInter); None la regula de clasă
    via: Substance | None = None  # sora de clasă (regula de clasă sau analogia din curated)
    via_level: str | None = None


def class_analogy(kb: Kb, a: Substance, b: Substance) -> tuple[Substance, str] | None:
    """Sora de clasă cu nivel pentru aceeași pereche: (soră, nivel) sau None."""
    best: tuple[int, str, Substance, str] | None = None
    for me, other in ((a, b), (b, a)):
        if not me.atc4:
            continue
        for sister in kb.class_members(me.atc4):
            if sister.id in (me.id, other.id):
                continue
            row = kb.ddi(sister.id, other.id)
            if row and row.level in SEVERITY_OF_LEVEL:
                cand = (SEV_RANK[SEVERITY_OF_LEVEL[row.level]], sister.inn, sister, row.level)
                if best is None or cand[:2] < best[:2]:
                    best = cand
    return (best[2], best[3]) if best else None


def evaluate(ctx: Ctx, a: Component, b: Component) -> Finding | None:
    if not (a.sub and b.sub) or a.sub.id == b.sub.id:
        return None
    row = ctx.kb.ddi(a.sub.id, b.sub.id)
    if row is None:
        return None
    if row.level in SEVERITY_OF_LEVEL:
        via = None
        if row.basis == "class_analogy" and row.analogy_via:
            via = ctx.kb.resolve(row.analogy_via, None, None)
        basis = row.basis if row.basis in ("direct", "curated", "class_analogy") else "direct"
        return Finding(a, b, SEVERITY_OF_LEVEL[row.level], basis, row.level, row, via)
    # Unknown: curated („verificat, fără nivel”) oprește analogia; altfel regula de clasă.
    if row.source == "ddinter":
        found = class_analogy(ctx.kb, a.sub, b.sub)
        if found:
            sister, level = found
            return Finding(a, b, SEVERITY_OF_LEVEL[level], "class_analogy", "Unknown", None, sister, level)
    ctx.unknown_pairs.append((a, b))
    return None


def separated_by_schedule(kb: Kb, a: Substance, b: Substance) -> bool:
    """O regulă de separare din timing.yaml între cele două (atunci acțiunea e `separate_times`)."""
    for me, other in ((a, b), (b, a)):
        for sep in (kb.timing.get(me.id) or {}).get("min_separation", []):
            target = sep["other"]
            if target == other.inn or (other.atc and target[:1].isupper() and other.atc.startswith(target)):
                return True
    return False


def to_alert(ctx: Ctx, f: Finding) -> dict:
    a, b = sorted((f.a, f.b), key=lambda c: c.med_id)
    ma, mb = a.med, b.med
    # „noul” medicament: cel fără medic (OTC), apoi cel început mai târziu
    if specialty(ma) is None and specialty(mb) is not None:
        newer, older = ma, mb
    elif specialty(mb) is None and specialty(ma) is not None:
        newer, older = mb, ma
    else:
        newer, older = sorted((ma, mb), key=lambda m: (m.get("start_date") or "", m["id"]))[::-1]

    action = "contact_doctor" if f.severity in ("critical", "major") else "monitor"
    if action == "monitor" and separated_by_schedule(ctx.kb, a.sub, b.sub):
        action = "separate_times"

    head = f"{a.name_ro.capitalize()} ({brand(ma)}) + {b.name_ro} ({brand(mb)})"
    if f.ddi and f.ddi.mechanism:
        mech = f.ddi.mechanism
        if mech[1:2].islower():  # „Amlodipina crește…” → „amlodipina crește…”, dar „AINS…” rămâne
            mech = mech[0].lower() + mech[1:]
        detail = f"{head}: {mech}"
        if f.ddi.management:
            detail += f" {f.ddi.management}"
    else:
        detail = f"{head}: interacțiune {T.SEVERITY_RO[f.severity]} (nivel DDInter {f.via_level or f.level})."

    analogy = None
    if f.basis == "class_analogy" and f.via:
        via_ro = T.ro_name(f.via.inn, f.via.dci_ro)
        analogy = {"via": via_ro, "atc4": f.via.atc4}
        detail += f" {T.analogy_note(via_ro)}"

    if f.ddi and f.ddi.source == "curated":
        source = {"db": "curated", "ref": f"kb/curated_ddi.csv: {f.ddi.ref}", "url": f.ddi.source_url}
    elif f.ddi:
        source = {"db": "ddinter", "ref": f"DDInter: {a.sub.inn} + {b.sub.inn} = {f.level} ({f.ddi.ref})", "url": DDINTER_URL}
    else:
        other = b.sub if f.via and f.via.atc4 == a.sub.atc4 else a.sub
        source = {
            "db": "ddinter",
            "ref": f"DDInter: {a.sub.inn} + {b.sub.inn} = Unknown; {f.via.inn} + {other.inn} = {f.via_level}",
            "url": DDINTER_URL,
        }

    return make_alert(
        kind="ddi",
        severity=f.severity,
        med_ids=[ma["id"], mb["id"]],
        title=T.ddi_title(f.severity, brand(ma), brand(mb)),
        patient_text=T.ddi_patient_text(f.severity, ctx.caregiver),
        detail=detail,
        recommendation=T.ddi_recommendation(f.severity, action, brand(newer), specialty(older)),
        action=action,
        source=source,
        basis=f.basis,
        analogy=analogy,
    )


def check(ctx: Ctx) -> list[dict]:
    best: dict[tuple[str, str], Finding] = {}
    for a, b in combinations(ctx.components, 2):
        if a.med_id == b.med_id:
            continue
        f = evaluate(ctx, a, b)
        if f is None:
            continue
        key = tuple(sorted((a.med_id, b.med_id)))
        if key not in best or SEV_RANK[f.severity] < SEV_RANK[best[key].severity]:
            best[key] = f
    return [to_alert(ctx, f) for f in best.values()]
