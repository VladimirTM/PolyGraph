"""Normalizează câmpurile din catalog și OCR pentru afișare."""

import re
from collections.abc import Iterable

from polygraph.extract.ocr_match import STRENGTH, UNITS
from polygraph.kb import norm

FORMS = {
    "compr": "comprimate",
    "compr film": "comprimate filmate",
    "compr cu elib prel": "comprimate cu eliberare prelungită",
    "compr gastrorez": "comprimate gastrorezistente",
    "caps": "capsule",
    "caps gastrorez": "capsule gastrorezistente",
    "caps moi": "capsule moi",
    "caps cu elib prel": "capsule cu eliberare prelungită",
    "sol inj": "soluție injectabilă",
    "sol perf": "soluție perfuzabilă",
    "sol orala": "soluție orală",
    "conc pt sol perf": "concentrat pentru soluție perfuzabilă",
    "crema": "cremă",
    "draj": "drajeuri",
    "supoz": "supozitoare",
}

SPECIALTIES = {
    "medicina de familie": "medicină de familie",
    "medicina interna": "medicină internă",
    "orl": "ORL",
}


def display_brand(brand: str, brand_norm: str, ocr_texts: Iterable[str] = ()) -> str:
    key = norm(brand_norm)
    for text in ocr_texts:
        if norm(text) == key:
            return text.strip()

    # Unele etichete ANMDMR includ concentrația sau forma după numele comercial.
    for token in re.finditer(r"\w+", brand):
        prefix = brand[: token.end()]
        if norm(prefix) == key:
            brand = prefix
            break
    return " ".join(
        token if any(char.isdigit() for char in token) or (len(token) <= 3 and token.isupper()) else token.title()
        for token in brand.split()
    )


def display_strength(text: str | None) -> str | None:
    def format_amount(match: re.Match[str]) -> str:
        amount, unit = match.groups()
        unit = UNITS.get(unit.lower(), unit.lower())
        return f"{amount} {'UI' if unit == 'ui' else unit}"

    return STRENGTH.sub(format_amount, text.strip()) if text else text


def display_form(text: str | None) -> str | None:
    return FORMS.get(norm(text), text.strip().lower()) if text else text


def display_specialty(text: str | None) -> str | None:
    return SPECIALTIES.get(norm(text), text.strip().lower()) if text else text
