"""Potrivire OCR în catalogul local și segmentare de rețete."""

import json
import re
from collections import defaultdict
from dataclasses import dataclass, replace
from decimal import Decimal
from functools import cache

from rapidfuzz import fuzz, process

from polygraph.kb import Kb, norm

STRENGTH = re.compile(r"(?<!\w)(\d{1,8}(?:[.,]\d{1,8})?)\s*(micrograme|miligrame|mcg|[µμu]g|mg|g|ml|ui|iu)\b", re.I)
UNITS = {"micrograme": "mcg", "µg": "mcg", "μg": "mcg", "ug": "mcg", "miligrame": "mg", "iu": "ui"}
CONFUSABLES = str.maketrans({"0": "o", "1": "l", "i": "l"})
RX_PREFIX = re.compile(r"^\s*(?:rp\s*[./:]+\s*)?(?:\d+[.)]\s*)?", re.I)
RX_END = re.compile(r"^(?:data prescrierii|semnatura|parafa|document fictiv)\b")
DOSAGE = re.compile(r"\b(?:d s|dimineata|seara|la pranz|la culcare|pe zi|ori pe zi|la nevoie|mese|masa|nemancate)\b")
FORM = re.compile(r"\b(comprimate(?: filmate)?|capsule|picaturi|sirop|solutie|crema|gel|pulbere)\b")
SPECIALTY = re.compile(
    r"\b(cardiologie|medicina de familie|medicina interna|geriatrie|neurologie|psihiatrie|"
    r"endocrinologie|diabetologie|dermatologie|pneumologie|gastroenterologie|orl|otorinolaringologie)\b"
)


@dataclass(frozen=True)
class RawExtraction:
    brand: str | None = None
    strength_text: str | None = None
    form: str | None = None
    dci_text: str | None = None
    pack_size: int | None = None
    posology_text: str | None = None
    prescriber_text: str | None = None
    specialty: str | None = None


@dataclass(frozen=True)
class OcrLine:
    text: str
    height: float = 0


@dataclass(frozen=True)
class Product:
    id: int
    brand: str
    key: str
    strength: str | None
    form: str | None
    dci: str | None


@dataclass(frozen=True)
class Match:
    product: Product
    raw: RawExtraction
    method: str
    confidence: float


def strengths(text: str | None) -> tuple:
    # Unitatea de volum din „500 mg/ml” face parte din concentrație.
    out = []
    text = text or ""
    for match in STRENGTH.finditer(text):
        amount, unit = match.groups()
        unit = UNITS.get(unit.lower(), unit.lower())
        if re.match(r"\s*/\s*ml\b", text[match.end() :], re.I):
            unit += "/ml"
        out.append((Decimal(amount.replace(",", ".")), unit))
    return tuple(out)


@cache
def catalog(kb: Kb) -> tuple[dict, dict, dict, dict]:
    products, brands, dcis, confusing = {}, defaultdict(list), defaultdict(list), defaultdict(set)
    for pid, brand, key, strength, form, dci in kb.scan_catalog():
        key = norm(key)
        product = Product(pid, brand, key, strength, form, dci)
        products[pid] = product
        brands[key].append(product)
        confusing[key.translate(CONFUSABLES)].add(key)
        aliases = {norm(dci)}
        for latin, inn, _, synonyms in kb.scan_substances(pid):
            aliases.update(map(norm, [latin, inn, *json.loads(synonyms)]))
            for name in (latin, inn):
                key_name = norm(name)
                stem = key_name.removesuffix("um")
                aliases.update(
                    (
                        stem,
                        stem + "a",
                        stem.replace("th", "t").replace("y", "i") + "a",
                        key_name.replace("coum", "cum").removesuffix("olum") + "ol",
                    )
                )
        for alias in aliases - {""}:
            dcis[alias].append(product)
    return products, dict(brands), dict(dcis), dict(confusing)


def words(text: str) -> list[str]:
    return norm(text.replace("®", "").replace("™", "")).split()


def phrases(text: str, prefix: bool = False) -> set[str]:
    tokens = words(text)
    starts = range(min(1, len(tokens))) if prefix else range(len(tokens))
    return {" ".join(tokens[i : i + size]) for i in starts for size in range(1, min(3, len(tokens) - i) + 1)}


def aliases_in(text: str, index: dict, prefix: bool = False) -> set[str]:
    keys = phrases(text, prefix) & index.keys()
    whole = " ".join(words(text))
    if whole in index:
        keys.add(whole)
    return keys


def box_match(kb: Kb, lines: list[OcrLine], raw: RawExtraction | None = None) -> Match | None:
    _, brands, dcis, confusing = catalog(kb)
    ranked = sorted(lines, key=lambda line: -line.height)
    text = "\n".join(line.text for line in lines)
    observed = strengths(raw.strength_text if raw else text)
    brand_texts = [raw.brand or ""] if raw else [line.text for line in ranked]
    dci_texts = [raw.dci_text or ""] if raw else brand_texts
    dci_keys = set().union(*(aliases_in(value, dcis) for value in dci_texts))
    dci_ids = {p.id for key in dci_keys for p in dcis[key]}
    scored = {}
    for i, value in enumerate(brand_texts):
        for key in aliases_in(value, brands):
            scored[key] = max(scored.get(key, 0), 100 + len(key) / 100 - i / 1000)

    if not scored and not (dci_ids and observed):
        queries = set().union(*(phrases(value) for value in brand_texts))
        for query in sorted(queries):
            if len(query) < 4 or not query[0].isalnum():
                continue
            for key in confusing.get(query.translate(CONFUSABLES), ()):
                scored[key] = max(scored.get(key, 0), 96)
            if not observed:
                continue
            for key, score, _ in process.extract(query, brands.keys(), scorer=fuzz.WRatio, score_cutoff=88, limit=8):
                if fuzz.ratio(query, key) >= 83:
                    scored[key] = max(scored.get(key, 0), min(score, 95))

    candidates = []
    for key, score in scored.items():
        for product in brands[key]:
            strength = strengths(product.strength)
            if observed and strength and not all(value in observed for value in strength):
                continue
            if (dci_ids or (raw and raw.dci_text)) and product.id not in dci_ids:
                continue
            candidates.append((product, score, bool(strength and all(value in observed for value in strength))))

    if not candidates and observed and dci_ids:
        for product in {p for key in dci_keys for p in dcis[key]}:
            if strengths(product.strength) == observed:
                manufacturer = bool(raw and raw.brand and norm(raw.brand) in product.key.split())
                candidates.append((product, 90 if manufacturer else 87, True))

    if not candidates:
        return None
    candidates.sort(key=lambda entry: (-entry[2], -entry[1], entry[0].id))
    product, score, same_strength = candidates[0]
    exact = score >= 100
    method = "exact_brand" if exact else "exact_dci" if score in (87, 90) and product.id in dci_ids else "fuzzy"
    alternatives = [p for p, other_score, same in candidates if same == same_strength and abs(other_score - score) < 0.005]
    if len({p.key for p in alternatives}) > 1 and method == "fuzzy":
        return None
    if len({(strengths(p.strength), p.dci) for p in alternatives}) > 1:
        return None

    form = FORM.search(norm(text))
    pack = re.search(r"\b(\d{1,4})\s+(?:comprimate|capsule|plicuri)\b", norm(text))
    if not raw:
        raw = RawExtraction(
            brand=product.brand,
            strength_text=STRENGTH.search(text)[0] if observed else None,
            form=form[1] if form else None,
            dci_text=max(sorted(dci_keys), key=len, default=None),
            pack_size=int(pack[1]) if pack and int(pack[1]) else None,
        )
    confidence = (
        (0.96 if exact else 0.88 if score >= 96 or method == "exact_dci" else 0.83)
        if same_strength
        else (0.83 if exact else 0.77)
    )
    if product.id in dci_ids:
        confidence += 0.02
    if method == "exact_dci":
        # Nu afișa marca unui alt producător ca și cum ar fi fost citită.
        label = (raw.brand if score == 90 else None) or raw.dci_text or product.dci
        if not label:
            return None
        product = replace(product, brand=label, form=raw.form)
    return Match(product, raw, method, confidence)


def prescription_matches(kb: Kb, lines: list[OcrLine]) -> tuple[list[Match], bool]:
    _, brands, dcis, _ = catalog(kb)
    starts = []
    end = len(lines)
    missing = False
    for i, line in enumerate(lines):
        if starts and RX_END.search(norm(line.text)):
            end = i
            break
        text = RX_PREFIX.sub("", line.text)
        if aliases_in(text, brands, True) or aliases_in(text, dcis, True):
            starts.append(i)
        elif re.search(r"^\s*(?:rp\s*[./:]+\s*\S|\d+[.)]\s+\D)", line.text, re.I) and strengths(text):
            starts.append(i)

    if not starts:
        return [], False
    header = "\n".join(line.text for line in lines[: starts[0]])
    doctor = re.search(r"(?im)^\s*(?:dr\.?|medic(?: prescriptor)?\s*:)\s+([^\n]+)", header)
    specialty = SPECIALTY.search(norm(header))
    results = []
    for start, stop in zip(starts, [*starts[1:], end], strict=True):
        first = replace(lines[start], text=RX_PREFIX.sub("", lines[start].text))
        segment = lines[start + 1 : stop]
        posology = []
        evidence = [first]
        for line in segment:
            if posology or DOSAGE.search(norm(line.text)) or re.search(r"\d\s*-\s*\d\s*-\s*\d", line.text):
                posology.append(line.text)
            else:
                evidence.append(line)
        match = box_match(kb, evidence)
        if not match:
            missing = True
            continue
        raw = replace(
            match.raw,
            posology_text=" ".join(posology) or None,
            prescriber_text=doctor[1].strip() if doctor else None,
            specialty=specialty[1] if specialty else None,
        )
        results.append(replace(match, raw=raw))
    return results, missing
