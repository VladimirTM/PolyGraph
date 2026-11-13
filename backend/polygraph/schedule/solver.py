"""Solverul de program (B4): dozele zilei → momente care respectă regulile de orar din `timing_rule`.

Determinist, fără OR-Tools: backtracking cu branch-and-bound peste doze (cele mai constrânse întâi), cu obiectiv
lexicografic: (0) constrângeri dure încălcate, (1) numărul de momente distincte, (2) preferințe încălcate,
(3) suma distanțelor față de ancora fiecărei doze. Constrângerile dure sunt penalizate, nu interzise: când nu există
program care să le respecte pe toate, iese cel mai bun program relaxat, iar încălcările ajung în `unsatisfied`.
Singura limită care nu se relaxează e maximum 5 momente (contract); 4 sunt mereu posibile, câte unul per fereastră.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import date
from typing import Any

from polygraph.kb import Kb, norm

Json = dict[str, Any]
VERSION = "1.0.0"
MAX_MOMENTS = 5
SLOTS = ("morning", "noon", "evening", "bedtime")
MEALS = ("breakfast", "lunch", "dinner")
MEAL_RO = {"breakfast": "micul dejun", "lunch": "prânz", "dinner": "cină"}
ATC_LIKE = re.compile(r"^[A-Z][0-9][0-9A-Z]{0,5}$")

# Punctele candidate (ancoră, decalaj în minute, eticheta). Ordinea e și prioritatea etichetei când două puncte cad
# la aceeași oră (07:30 = trezire + 30 = mic dejun - 30 → eticheta legată de masă).
POINTS: tuple[tuple[str, int, str], ...] = (
    ("wake", 0, "Imediat după trezire"),
    ("breakfast", -30, "Cu o jumătate de oră înainte de micul dejun"),
    ("breakfast", 0, "La micul dejun"),
    ("breakfast", 30, "După micul dejun"),
    ("lunch", -30, "Cu o jumătate de oră înainte de prânz"),
    ("lunch", 0, "La prânz"),
    ("lunch", 30, "După prânz"),
    ("dinner", -30, "Cu o jumătate de oră înainte de cină"),
    ("dinner", 0, "La cină"),
    ("dinner", 30, "După cină"),
    ("bed", 0, "La culcare"),
    ("dinner", 120, "Seara, după cină"),
    ("wake", 30, "La o jumătate de oră după trezire"),
)

INSTRUCTION_BY_FOOD = {
    "empty_stomach": "pe stomacul gol, cu un pahar cu apă",
    "before_meal": "înainte de masă",
    "with_meal": "la masă",
    "after_meal": "după masă",
    "any": "cu un pahar cu apă",
}


def to_min(clock: str) -> int:
    h, m = clock.split(":")
    return int(h) * 60 + int(m)


def to_clock(minutes: int) -> str:
    return f"{minutes // 60:02d}:{minutes % 60:02d}"


@dataclass
class Dose:
    med_id: str
    brand: str
    slot: str
    qty: float
    with_food: str = "any"
    alone: bool = False
    preferred: str = "none"
    default_time: str | None = None
    latest: int | None = None
    interval_h: float | None = None
    minutes_before_breakfast: int = 30
    instruction: str = ""
    source: str | None = None
    verified: bool = False
    raw: str = ""
    inns: tuple[str, ...] = ()
    atcs: tuple[str, ...] = ()
    separations: list[tuple[str, float, str]] = field(default_factory=list)  # (other, ore, direcție)
    # completate de solver
    candidates: list[int] = field(default_factory=list)
    anchor: int = 0

    def matches(self, other: str) -> bool:
        if ATC_LIKE.match(other):
            return any(a.startswith(other) for a in self.atcs)
        return norm(other) in self.inns


@dataclass(frozen=True)
class Sep:
    """Separare dură între dozele i și j: before = t_i + gap ≤ t_j; either = |t_i - t_j| ≥ gap; distinct = t_i ≠ t_j."""

    i: int
    j: int
    gap: int
    kind: str  # before | either | distinct


# ---------------------------------------------------------------- dozele zilei din medicamente


def short_source(source: str | None) -> str | None:
    if not source:
        return None
    head = re.split(r"[,;:(]", source, maxsplit=1)[0].strip()
    return head or None


def is_scheduled(med: Json, day: date) -> bool:
    dosage = med.get("dosage") or {}
    if dosage.get("as_needed"):
        return False
    try:
        if med.get("end_date") and date.fromisoformat(med["end_date"]) < day:
            return False
        if med.get("start_date") and date.fromisoformat(med["start_date"]) > day:
            return False
    except ValueError:
        pass
    return True


def doses_for(meds: list[Json], day: date, kb: Kb) -> list[Dose]:
    doses = []
    for m in meds:
        if not is_scheduled(m, day):
            continue
        dosage = m.get("dosage") or {}
        pattern = dosage.get("pattern") or {}
        inns, atcs, rules = [], [], []
        for s in m.get("substances") or []:
            sub = kb.resolve(s.get("inn"), s.get("dci"), s.get("atc"))
            inn = (sub.inn if sub else None) or norm(s.get("inn"))
            atc = (sub.atc if sub else None) or s.get("atc")
            if inn:
                inns.append(norm(inn))
            if atc:
                atcs.append(atc)
            if sub and sub.id in kb.timing:
                rules.append(kb.timing[sub.id])
        base = dict(
            med_id=m["id"],
            brand=(m.get("product") or {}).get("brand") or "Medicamentul",
            raw=dosage.get("raw") or "",
            inns=tuple(inns),
            atcs=tuple(atcs),
        )
        spec = merge_rules(rules, dosage.get("with_food") or "any")
        for slot in SLOTS:
            qty = pattern.get(slot) or 0
            if qty > 0:
                doses.append(Dose(slot=slot, qty=qty, **base, **spec, separations=list(spec_seps(rules))))
    return doses


def merge_rules(rules: list[Json], med_food: str) -> Json:
    """Regulile tuturor substanțelor unui medicament: cea mai strictă cerință de masă, prima preferință."""
    food = next((r["with_food"] for r in rules if r.get("with_food") not in (None, "any")), None) or med_food or "any"
    first = rules[0] if rules else {}
    latest = [to_min(r["latest_time"]) for r in rules if r.get("latest_time")]
    return {
        "with_food": food,
        "alone": any(r.get("alone") for r in rules),
        "preferred": next((r["preferred_time"] for r in rules if r.get("preferred_time") not in (None, "none")), "none"),
        "default_time": next((r["default_time"] for r in rules if r.get("default_time")), None),
        "latest": min(latest) if latest else None,
        "interval_h": next((r["interval_hours"] for r in rules if r.get("interval_hours")), None),
        "minutes_before_breakfast": max([30, *(r.get("minutes_before_breakfast") or 0 for r in rules)]),
        "instruction": first.get("instruction") or INSTRUCTION_BY_FOOD.get(food, ""),
        "source": first.get("source"),
        "verified": bool(first.get("verified")),
    }


def spec_seps(rules: list[Json]):
    for r in rules:
        for s in r.get("min_separation") or []:
            yield (s["other"], float(s["hours"]), s["direction"])


def separations(doses: list[Dose]) -> list[Sep]:
    best: dict[tuple[int, int, str], int] = {}

    def put(i: int, j: int, gap: int, kind: str) -> None:
        if kind != "before" and i > j:
            i, j = j, i
        best[(i, j, kind)] = max(gap, best.get((i, j, kind), 0))

    for i, d in enumerate(doses):
        for j, e in enumerate(doses):
            if i == j:
                continue
            if d.med_id == e.med_id and i < j:
                put(i, j, 1, "distinct")
                continue
            for other, hours, direction in d.separations:
                if d.med_id != e.med_id and e.matches(other):
                    gap = round(hours * 60)
                    if direction == "before":
                        put(i, j, gap, "before")
                    elif direction == "after":
                        put(j, i, gap, "before")
                    else:
                        put(i, j, gap, "either")
    return [Sep(i, j, gap, kind) for (i, j, kind), gap in best.items()]


# ---------------------------------------------------------------- candidații și costurile unare


def points(anchors: dict[str, int]) -> dict[int, str]:
    """Ora → eticheta, pentru toate punctele candidate ale zilei."""
    out: dict[int, str] = {}
    for anchor, offset, label in POINTS:
        t = anchors[anchor] + offset
        if 0 <= t < 24 * 60:
            out.setdefault(t, label)
    return out


def window(slot: str, a: dict[str, int]) -> tuple[int, int]:
    return {
        "morning": (a["wake"], a["lunch"] - 60),
        "noon": (a["lunch"] - 90, a["lunch"] + 90),
        "evening": (a["dinner"] - 60, a["bed"] - 60),
        "bedtime": (a["bed"] - 60, a["bed"]),
    }[slot]


def anchor_for(d: Dose, a: dict[str, int]) -> int:
    meal = {"morning": "breakfast", "noon": "lunch", "evening": "dinner"}.get(d.slot)
    if d.slot == "bedtime" or meal is None:
        return a["bed"]
    if d.with_food in ("empty_stomach", "any") and d.slot == "morning":
        return a["wake"]
    offset = {"empty_stomach": -30, "before_meal": -30, "after_meal": 30}.get(d.with_food, 0)
    return a[meal] + offset


def meal_times(a: dict[str, int]) -> list[tuple[str, int]]:
    return sorted(((m, a[m]) for m in MEALS), key=lambda x: x[1])


def unary_hard(d: Dose, t: int, a: dict[str, int]) -> list[str]:
    """Regulile dure încălcate de doza d la ora t, fără celelalte doze."""
    meals = meal_times(a)
    broken = []
    if d.with_food == "empty_stomach":
        nxt = next(((m, mt) for m, mt in meals if mt >= t), None)
        prev = next(((m, mt) for m, mt in reversed(meals) if mt <= t), None)
        need = d.minutes_before_breakfast if nxt and nxt[0] == "breakfast" else 30
        if (nxt and nxt[1] - t < need) or (prev and t - prev[1] < 120):
            broken.append("empty_stomach")
    elif d.with_food == "before_meal":
        if not any(15 <= mt - t <= 60 for _, mt in meals):
            broken.append("before_meal")
    elif d.with_food in ("with_meal", "after_meal"):
        if not any(0 <= t - mt <= 30 for _, mt in meals):
            broken.append(d.with_food)
    if d.latest is not None and t > d.latest:
        broken.append("latest_time")
    return broken


def unary_soft(d: Dose, t: int, a: dict[str, int]) -> int:
    pref = d.preferred
    if pref == "same_time_daily":
        pref = d.default_time or "none"
    if pref == "morning":
        return int(t >= 12 * 60)
    if pref == "evening":
        return int(t < 17 * 60)
    if pref == "bedtime":
        return int(t < a["dinner"] - 60)
    return 0


# ---------------------------------------------------------------- căutarea


@dataclass
class Problem:
    doses: list[Dose]
    seps: list[Sep]
    anchors: dict[str, int]
    labels: dict[int, str]
    hard: list[list[int]] = field(default_factory=list)  # per doză, per candidat
    soft: list[list[int]] = field(default_factory=list)
    dist: list[list[int]] = field(default_factory=list)


def prepare(doses: list[Dose], anchors: dict[str, int]) -> Problem:
    labels = points(anchors)
    for d in doses:
        lo, hi = window(d.slot, anchors)
        d.candidates = sorted(t for t in labels if lo <= t <= hi) or [anchor_for(d, anchors)]
        d.anchor = anchor_for(d, anchors)
    p = Problem(doses, separations(doses), anchors, labels)
    for d in doses:
        p.hard.append([len(unary_hard(d, t, anchors)) for t in d.candidates])
        p.soft.append([unary_soft(d, t, anchors) for t in d.candidates])
        p.dist.append([abs(t - d.anchor) for t in d.candidates])
    return p


def pair_cost(p: Problem, i: int, ti: int, j: int, tj: int) -> tuple[int, int]:
    """(dure, preferințe) încălcate între dozele i și j la orele date."""
    hard = soft = 0
    di, dj = p.doses[i], p.doses[j]
    if ti == tj and (di.alone or dj.alone):
        hard += 1
    if di.med_id == dj.med_id and di.interval_h and abs(abs(ti - tj) - di.interval_h * 60) > 90:
        soft += 1
    return hard, soft


def sep_broken(s: Sep, ti: int, tj: int) -> bool:
    if s.kind == "before":
        return ti + s.gap > tj
    if s.kind == "either":
        return abs(ti - tj) < s.gap
    return ti == tj


def solve(p: Problem) -> list[int]:
    """Indicele orei alese pentru fiecare doză (în p.doses[k].candidates)."""
    n = len(p.doses)
    if n == 0:
        return []
    # vecinii fiecărei doze: doar perechile care pot costa ceva (singur, separări, aceeași doză de două ori)
    seps_of: list[list[tuple[int, Sep]]] = [[] for _ in range(n)]
    for s in p.seps:
        seps_of[s.i].append((s.j, s))
        seps_of[s.j].append((s.i, s))
    pairs_of: list[list[int]] = [
        [j for j in range(n) if j != k and (p.doses[k].alone or p.doses[j].alone or p.doses[k].med_id == p.doses[j].med_id)]
        for k in range(n)
    ]
    clean = [sum(1 for h in hs if h == 0) for hs in p.hard]
    order = sorted(range(n), key=lambda k: (clean[k] or 99, -p.doses[k].alone, len(p.doses[k].candidates), k))
    min_dist = [min(d) for d in p.dist]

    time_of: list[int | None] = [None] * n
    choice: list[int | None] = [None] * n
    used: dict[int, int] = {}
    best: list[Any] = [None, None]  # (cost, alegere)

    def delta(k: int, c: int) -> tuple[int, int]:
        t = p.doses[k].candidates[c]
        hard, soft = p.hard[k][c], p.soft[k][c]
        for j in pairs_of[k]:
            tj = time_of[j]
            if tj is not None:
                h, sf = pair_cost(p, k, t, j, tj)
                hard, soft = hard + h, soft + sf
        for j, s in seps_of[k]:
            tj = time_of[j]
            if tj is not None and sep_broken(s, t if s.i == k else tj, tj if s.i == k else t):
                hard += 1
        return hard, soft

    def rec(pos: int, hard: int, soft: int, dist: int) -> None:
        moments = len(used)
        if pos == n:
            cost = (hard, moments, soft, dist)
            if best[0] is None or cost < best[0]:
                best[0], best[1] = cost, list(choice)
            return
        # marginea inferioară pentru dozele rămase, cu ce e deja așezat (forward checking)
        lb_hard = lb_soft = lb_dist = 0
        new_moment = False
        for q in range(pos + 1, n):
            r = order[q]
            costs = [delta(r, c) for c in range(len(p.doses[r].candidates))]
            lb_hard += min(h for h, _ in costs)
            lb_soft += min(sf for _, sf in costs)
            lb_dist += min_dist[r]
            new_moment = new_moment or not any(t in used for t in p.doses[r].candidates)
        k = order[pos]
        d = p.doses[k]
        options = []
        for c, t in enumerate(d.candidates):
            opens = t not in used
            if opens and moments >= MAX_MOMENTS:
                continue
            dh, ds = delta(k, c)
            options.append(((hard + dh, moments + opens, soft + ds, dist + p.dist[k][c]), c, t))
        options.sort()
        for (h, m, sf, dd), c, t in options:
            bound = (h + lb_hard, m + (new_moment and m == moments), sf + lb_soft, dd + lb_dist)
            if best[0] is not None and bound >= best[0]:
                continue
            choice[k], time_of[k] = c, t
            used[t] = used.get(t, 0) + 1
            rec(pos + 1, h, sf, dd)
            used[t] -= 1
            if not used[t]:
                del used[t]
            choice[k], time_of[k] = None, None

    rec(0, 0, 0, 0)
    return best[1]


# ---------------------------------------------------------------- textele


def food_reason(d: Dose, t: int, a: dict[str, int]) -> str | None:
    meals = meal_times(a)
    if d.with_food == "empty_stomach":
        nxt = next((m for m, mt in meals if mt >= t), None)
        if nxt:
            before = d.minutes_before_breakfast if nxt == "breakfast" else 30
            return f"{d.brand} se ia pe stomacul gol, cu cel puțin {before} de minute înainte de {MEAL_RO[nxt]}"
        return f"{d.brand} se ia pe stomacul gol, la cel puțin 2 ore după masă"
    if d.with_food == "before_meal":
        meal = next((m for m, mt in meals if 15 <= mt - t <= 60), None)
        return f"{d.brand} se ia înainte de {MEAL_RO[meal]}" if meal else f"{d.brand} se ia înainte de masă"
    if d.with_food == "with_meal":
        return f"{d.brand} se ia la masă"
    if d.with_food == "after_meal":
        return f"{d.brand} se ia după masă"
    return None


def preference_reason(d: Dose, t: int, a: dict[str, int]) -> str | None:
    if unary_soft(d, t, a):
        return None
    if d.preferred == "morning":
        return f"{d.brand} se ia dimineața"
    if d.preferred == "evening":
        return f"{d.brand} se ia seara"
    if d.preferred == "bedtime":
        return f"{d.brand} se ia seara, pentru că poate da somnolență"
    if d.preferred == "same_time_daily":
        return f"{d.brand} se ia în fiecare zi la aceeași oră" + (", seara" if d.default_time == "evening" else "")
    return None


def reasons_for(p: Problem, k: int, times: list[int]) -> list[str]:
    d, t, a = p.doses[k], times[k], p.anchors
    out: list[str] = []
    # sursa apare doar pentru regulile verificate în RCP-ul românesc (timing.yaml: verified)
    src = short_source(d.source) if d.verified else None
    first = food_reason(d, t, a) or preference_reason(d, t, a)
    if first:
        out.append(f"{first} ({src})" if src else first)
    if d.alone:
        out.append("Singur, ca nimic să nu-i scadă absorbția")
    seen = set()
    for s in p.seps:
        if s.kind == "distinct" or k not in (s.i, s.j):
            continue
        o = s.j if s.i == k else s.i
        other = p.doses[o]
        if other.med_id in seen:
            continue
        seen.add(other.med_id)
        hours = f"{s.gap // 60} ore" if s.gap % 60 == 0 else f"{s.gap} de minute"
        hours = "o oră" if s.gap == 60 else hours
        side = "după" if times[o] < t else "înainte de"
        out.append(f"La cel puțin {hours} {side} {other.brand}")
    if d.latest is not None and t <= d.latest:
        out.append(f"Nu mai târziu de ora {to_clock(d.latest)}")
    if not out:
        out.append(f"Așa cum scrie pe rețetă: {d.raw}" if d.raw else "Așa cum scrie pe rețetă")
    return out


RULE_RO = {
    "empty_stomach": "nu poate fi luat pe stomacul gol la nicio oră posibilă",
    "before_meal": "nu poate fi luat înainte de masă la nicio oră posibilă",
    "with_meal": "nu poate fi luat la masă la nicio oră posibilă",
    "after_meal": "nu poate fi luat după masă la nicio oră posibilă",
    "latest_time": "ar trebui luat mai devreme decât permite programul",
}


def unsatisfied(p: Problem, times: list[int]) -> list[Json]:
    out: dict[tuple[str, tuple[str, ...]], Json] = {}

    def add(rule: str, idx: list[int], reason: str) -> None:
        meds = tuple(sorted({p.doses[i].med_id for i in idx}))
        out.setdefault((rule, meds), {"med_ids": list(meds), "rule": rule, "reason": reason})

    n = len(p.doses)
    for k, d in enumerate(p.doses):
        for rule in unary_hard(d, times[k], p.anchors):
            add(rule, [k], f"{d.brand} {RULE_RO[rule]}.")
    for i in range(n):
        for j in range(i + 1, n):
            if times[i] == times[j] and (p.doses[i].alone or p.doses[j].alone):
                lone = p.doses[i] if p.doses[i].alone else p.doses[j]
                add("alone", [i, j], f"{lone.brand} ar trebui luat singur, dar programul îl pune cu alte medicamente.")
    for s in p.seps:
        if sep_broken(s, times[s.i], times[s.j]):
            a, b = p.doses[s.i], p.doses[s.j]
            if s.kind == "distinct":
                add("same_med", [s.i], f"Două doze de {a.brand} cad la aceeași oră.")
            else:
                add("min_separation", [s.i, s.j], f"{a.brand} și {b.brand} au nevoie de cel puțin {s.gap // 60} ore între ele.")
    return list(out.values())


# ---------------------------------------------------------------- intrarea


def build_schedule(patient: Json, meds: list[Json], day: date, kb: Kb) -> Json:
    anchors_raw = patient["anchors"]
    anchors = {k: to_min(v) for k, v in anchors_raw.items()}
    p = prepare(doses_for(meds, day, kb), anchors)
    chosen = solve(p)
    times = [p.doses[k].candidates[c] for k, c in enumerate(chosen)]
    by_time: dict[int, list[Json]] = {}
    for k, d in enumerate(p.doses):
        by_time.setdefault(times[k], []).append(
            {"med_id": d.med_id, "qty": d.qty, "instruction": d.instruction, "reasons": reasons_for(p, k, times)}
        )
    moments = [
        {"time": to_clock(t), "label": p.labels.get(t, to_clock(t)), "doses": sorted(ds, key=lambda x: x["med_id"])}
        for t, ds in sorted(by_time.items())
    ]
    return {
        "date": day.isoformat(),
        "anchors": dict(anchors_raw),
        "moments": moments,
        "unsatisfied": unsatisfied(p, times),
        "solver": {"moments_count": len(moments), "version": VERSION},
    }
