"""Ordonează căile de scanare și construiește candidații de confirmat."""

import logging
import re
import secrets

from polygraph.extract.display import display_brand, display_form, display_specialty, display_strength
from polygraph.extract.gemini import extract_image
from polygraph.extract.gs1 import decode_datamatrix, parse_gs1, valid_gtin
from polygraph.extract.ocr_match import Match, OcrLine, RawExtraction, box_match, catalog, prescription_matches, strengths
from polygraph.extract.posology import parse_posology
from polygraph.kb import Kb
from polygraph.store import Store

LOG = logging.getLogger("uvicorn.error")
MANUAL = "Nu am putut citi cutia, completați manual."
PHOTO = "Fotografiați din nou cutia pentru a confirma informațiile."


def scan(kb: Kb, store: Store, kind: str, lines: list[OcrLine], image: bytes, mime: str, datamatrix: str | None) -> dict:
    code = None
    warnings = []
    if kind == "box":
        if datamatrix:
            try:
                code = parse_gs1(datamatrix)
            except ValueError:
                pass
        # un cod citit greșit de telefon (reflexie, cutie curbată) se mai caută o dată în poză
        if code is None and image:
            code = decode_datamatrix(image)
        if datamatrix and code is None:
            warnings.append("Codul DataMatrix nu a putut fi citit.")

    cached_id = store.cached_gtin(code["gtin"], kb.version) if code else None
    cached = catalog(kb)[0].get(cached_id) if cached_id is not None else None
    unread: list[str] = []  # rândurile de rețetă care n-au putut fi potrivite, numite în avertizare
    if cached:
        matches, route = [Match(cached, RawExtraction(), "gtin_cache", 1.0)], "gtin_cache"
    elif kind == "prescription":
        matches, unread = prescription_matches(kb, lines)
        route = "ocr_match"
    else:
        match = box_match(kb, lines)
        matches, route = [match] if match else [], "ocr_match"
    missing = bool(unread)

    if image and (missing or not matches or any(m.confidence < 0.85 for m in matches)):
        vision = []
        raw_rows = extract_image(image, kind, mime)
        for raw in raw_rows:
            match = box_match(kb, [], raw)
            if match:
                vision.append(match)
        if vision and (
            not matches
            or (
                len(vision) >= len(matches)
                and all(m.confidence >= 0.85 for m in vision)
                and (kind == "box" or {m.product.id for m in matches} <= {m.product.id for m in vision})
            )
        ):
            matches, route = vision[:1] if kind == "box" else vision, "gemini"
            missing = len(vision) != len(raw_rows)
            unread = []

    candidates = [candidate(kb, m, kind, code, route, lines) for m in matches]
    if not candidates:
        warnings.append(MANUAL if kind == "box" else "Nu am putut citi rețeta, completați manual.")
        route = "gtin_miss" if kind == "box" and code and not image and not lines else "manual"
    elif unread:
        warnings += [f"Nu am găsit «{text}». Adăugați-l manual." for text in unread]
    elif missing:
        warnings.append("Unele medicamente de pe rețetă trebuie completate manual.")
    for m, c in zip(matches, candidates, strict=True):
        dosage = c["dosage"]
        if m.raw.posology_text and not dosage["as_needed"] and not any(dosage["pattern"].values()):
            warnings.append(f"Nu am înțeles posologia «{m.raw.posology_text.strip()}» la {c['product']['brand']}.")
    if kind == "box" and any(m["match"]["needs_review"] for m in candidates):
        warnings.append(PHOTO)
    names = ", ".join(f"{c['product']['brand']} {c['product']['strength_text'] or ''}".strip() for c in candidates)
    LOG.info(
        "SCAN      route=%-11s încredere %.2f → %s",
        route,
        max((m.confidence for m in matches), default=0),
        names or "nimic (completare manuală)",
    )
    return {"candidates": candidates, "warnings": warnings, "raw_text": "\n".join(line.text for line in lines) or None}


def candidate(kb: Kb, match: Match, kind: str, code: dict | None, route: str, lines: list[OcrLine]) -> dict:
    product, raw = match.product, match.raw
    dosage, dosage_review = parse_posology(raw.posology_text)
    rows = kb.scan_substances(product.id) if route != "gemini" or raw.dci_text else ()
    strength = strengths(product.strength)
    strength_mg = None
    if len(rows) == len(strength) == 1:
        amount, unit = strength[0]
        if unit in ("g", "mg", "mcg"):
            strength_mg = float(amount) * {"g": 1000, "mg": 1, "mcg": 0.001}[unit]
    substances = [
        {
            "dci": dci,
            "inn": inn,
            "atc": atc if atc and re.fullmatch(r"[A-Z][0-9]{2}[A-Z]{2}[0-9]{2}", atc) else None,
            "strength_mg": strength_mg,
        }
        for dci, inn, atc, _ in rows
    ]
    unconfirmed = route != "gtin_cache" and (
        not raw.strength_text or not raw.dci_text or (route == "gemini" and (not raw.brand or not raw.form or not raw.pack_size))
    )
    return {
        "id": f"med_{secrets.token_hex(6)}",
        "source": "datamatrix" if code else "photo_rx" if kind == "prescription" else "photo_box",
        "product": {
            "brand": display_brand(
                product.brand, product.key if match.method != "exact_dci" else product.brand, (line.text for line in lines)
            ),
            "strength_text": display_strength(product.strength),
            "form": display_form(raw.form or product.form),
            "pack_size": raw.pack_size if raw.pack_size and raw.pack_size > 0 else None,
            **{key: code[key] if code else None for key in ("gtin", "expiry", "batch")},
        },
        "substances": substances,
        "dosage": dosage,
        "prescriber": {"name": raw.prescriber_text, "specialty": display_specialty(raw.specialty)},
        "start_date": None,
        "end_date": None,
        "photo_url": None,
        "match": {
            "method": match.method,
            "confidence": round(match.confidence, 3),
            "needs_review": unconfirmed
            or match.confidence < 0.85
            or not substances
            or any(s["atc"] is None for s in substances)
            or (kind == "prescription" and dosage_review),
        },
    }


def confirmed_product(kb: Kb, med: dict) -> int | None:
    product = med["product"]
    gtin = product.get("gtin")
    if not gtin or not valid_gtin(gtin) or not med["substances"]:
        return None
    match = box_match(kb, [], RawExtraction(brand=product["brand"], strength_text=product["strength_text"]))
    if not match or match.method != "exact_brand":
        return None
    expected = {(d, i, a) for d, i, a, _ in kb.scan_substances(match.product.id)}
    actual = {(s["dci"], s["inn"], s["atc"]) for s in med["substances"]}
    return match.product.id if actual == expected else None
