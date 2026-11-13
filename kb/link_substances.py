"""Legarea substanțelor: componentele DCI din catalog (latină) ↔ substanțele DDInter (engleză).

Ordinea (plan B1.4): (c) kb/overrides.csv are prioritate; (b) stem latin → englez, potrivire exactă pe forma
„scheletică”, apoi rapidfuzz WRatio ≥ 90 (plus ratio ≥ 80 și aceeași primă literă, ca un nume scurt să nu se
lege de unul care îl conține); (a) o DCI dintr-un produs cu o singură substanță, rămasă nelegată, se leagă prin
ATC5 de substanța care are deja acel ATC5 (dacă e unică).
"""

from __future__ import annotations

import csv
import json
import re
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from rapidfuzz import fuzz, process

from common import KB_DIR, latin_variants, norm, norm_dci, skeleton

OVERRIDES_PATH = KB_DIR / "overrides.csv"
WRATIO_MIN = 90
RATIO_MIN = 80


@dataclass
class Substance:
    id: int
    inn: str
    dci_ro: str | None = None
    atc: str | None = None
    ddinter_id: str | None = None
    synonyms: list[str] = field(default_factory=list)
    atc_votes: Counter = field(default_factory=Counter)


@dataclass
class LinkResult:
    substances: list[Substance]
    by_dci: dict[str, int]  # componentă DCI normalizată → substance.id
    method: dict[str, str]  # componentă DCI → override / exact / fuzzy / atc5 / unlinked
    fuzzy_log: list[tuple[str, str, float]]


class DDInterIndex:
    def __init__(self, drugs: dict[str, str]):
        self.drugs = drugs
        self.by_skel: dict[str, str] = {}
        for did, name in drugs.items():
            self.by_skel.setdefault(skeleton(name), did)
        # și fără calificativul din paranteză („Dorzolamide (ophthalmic)”), dacă forma simplă nu există
        for did, name in drugs.items():
            self.by_skel.setdefault(skeleton(re.sub(r"\(.*?\)", " ", name)), did)
        self.choices = list(self.by_skel.keys())

    def match(self, component: str) -> tuple[str | None, str, float, str]:
        variants = latin_variants(component)
        for v in variants:
            did = self.by_skel.get(skeleton(v))
            if did:
                return did, "exact", 100.0, v
        best: tuple[str | None, str, float, str] = (None, "unlinked", 0.0, variants[0] if variants else "")
        for v in variants:
            sk = skeleton(v)
            hit = process.extractOne(sk, self.choices, scorer=fuzz.WRatio, score_cutoff=WRATIO_MIN)
            # aceeași primă literă: „isoconazol” nu e „tioconazol”, „lipegfilgrastim” nu e „pegfilgrastim”
            if hit and hit[0][:1] == sk[:1] and fuzz.ratio(sk, hit[0]) >= RATIO_MIN and hit[1] > best[2]:
                best = (self.by_skel[hit[0]], "fuzzy", hit[1], v)
        return best


def load_overrides(path: Path = OVERRIDES_PATH) -> dict[str, dict]:
    out = {}
    with path.open(encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            out[norm_dci(row["dci_ro"])] = {k: (v.strip() or None) for k, v in row.items()}
    return out


def link(drugs: dict[str, str], products: list, overrides: dict[str, dict] | None = None) -> LinkResult:
    overrides = load_overrides() if overrides is None else overrides
    index = DDInterIndex(drugs)

    # 1. O substanță pentru fiecare medicament DDInter (ca ddi să le poată referi pe toate).
    substances: list[Substance] = []
    by_ddinter: dict[str, Substance] = {}
    for did in sorted(drugs, key=lambda d: int(d.removeprefix("DDInter"))):
        s = Substance(id=len(substances) + 1, inn=norm(drugs[did]), ddinter_id=did)
        substances.append(s)
        by_ddinter[did] = s
    by_inn = {s.inn: s for s in substances}

    # 2. Componentele DCI, cu frecvența și ATC-ul din produsele cu o singură substanță.
    freq: Counter = Counter()
    single_atc: dict[str, Counter] = defaultdict(Counter)
    for p in products:
        comps = p.components
        for c in comps:
            freq[c] += 1
        if len(comps) == 1 and p.atc:
            single_atc[comps[0]][p.atc] += 1
    for dci in overrides:
        freq.setdefault(dci, 0)

    by_dci: dict[str, int] = {}
    method: dict[str, str] = {}
    fuzzy_log: list[tuple[str, str, float]] = []

    def attach(s: Substance, dci: str, how: str) -> None:
        by_dci[dci] = s.id
        method[dci] = how
        if s.dci_ro is None:
            s.dci_ro = dci
        elif dci != s.dci_ro and dci not in s.synonyms:
            s.synonyms.append(dci)
        s.atc_votes.update(single_atc.get(dci, Counter()))

    pending: list[str] = []
    for dci, _ in sorted(freq.items(), key=lambda kv: (-kv[1], kv[0])):
        ov = overrides.get(dci)
        if ov:
            s = by_ddinter.get(ov["ddinter_id"]) if ov.get("ddinter_id") else by_inn.get(norm(ov["inn"] or ""))
            if s is None:
                s = Substance(id=len(substances) + 1, inn=norm(ov["inn"] or dci))
                substances.append(s)
                by_inn[s.inn] = s
            if ov.get("atc"):
                s.atc = ov["atc"]  # fixat de override, nu se mai votează
            attach(s, dci, "override")
            continue
        did, how, score, variant = index.match(dci)
        if did:
            attach(by_ddinter[did], dci, how)
            if how == "fuzzy":
                fuzzy_log.append((dci, drugs[did], score))
        else:
            pending.append(dci)

    # 3. ATC-ul substanțelor legate (votul produselor cu o singură substanță), apoi legarea prin ATC5.
    fixed = {s.id for s in substances if s.atc}
    for s in substances:
        if s.id not in fixed and s.atc_votes:
            s.atc = s.atc_votes.most_common(1)[0][0]
    atc_owner: dict[str, set[int]] = defaultdict(set)
    for s in substances:
        if s.atc and s.ddinter_id:
            atc_owner[s.atc].add(s.id)
    by_id = {s.id: s for s in substances}
    for dci in pending:
        atcs = single_atc.get(dci)
        atc = atcs.most_common(1)[0][0] if atcs else None
        owners = atc_owner.get(atc, set()) if atc and len(atc) == 7 else set()
        if len(owners) == 1:
            attach(by_id[next(iter(owners))], dci, "atc5")
            continue
        # nelegată la DDInter: substanță doar românească (fără interacțiuni cunoscute)
        s = Substance(id=len(substances) + 1, inn=latin_variants(dci)[0] if latin_variants(dci) else norm(dci), atc=atc)
        substances.append(s)
        attach(s, dci, "unlinked")
    return LinkResult(substances, by_dci, method, fuzzy_log)


def write_substances(conn, result: LinkResult) -> None:
    conn.executemany(
        "INSERT INTO substance(id, inn, dci_ro, atc, ddinter_id, synonyms) VALUES (?, ?, ?, ?, ?, ?)",
        [(s.id, s.inn, s.dci_ro, s.atc, s.ddinter_id, json.dumps(s.synonyms, ensure_ascii=False)) for s in result.substances],
    )


def write_product_substances(conn, products: list, product_ids: list[int], result: LinkResult) -> None:
    rows = set()
    for p, pid in zip(products, product_ids, strict=True):
        for c in p.components:
            rows.add((pid, result.by_dci[c]))
    conn.executemany("INSERT INTO product_substance(product_id, substance_id) VALUES (?, ?)", sorted(rows))
