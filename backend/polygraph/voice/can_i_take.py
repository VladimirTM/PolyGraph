"""„Pot să iau…?” (bonusul X1): medicamentul întrebat rulat ca what-if pe regimul pacientului, cu răspunsul prudent
decis pe 14.11.2026 (docs/PLAN.md, 1.3). Răspunsul nu spune niciodată „puteți lua”: motorul vede doar interacțiunile din
baza de date, iar lipsa unei alerte nu înseamnă că medicamentul e sigur. Trei răspunsuri posibile:

(a) what-if găsește o alertă nouă → „Înainte să luați X, întrebați medicul de familie. <titlul alertei celei mai grave>.”
(b) toate substanțele sunt în baza de interacțiuni și nu iese nimic → „Nu am găsit o interacțiune cunoscută…, dar întrebați
    farmacistul înainte.”
(c) cel puțin o substanță nu e în baza de interacțiuni → „Nu am date despre X…; întrebați medicul sau farmacistul.”
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

from polygraph.engine import new_alerts
from polygraph.extract.display import display_brand
from polygraph.kb import SEV_RANK, Kb, norm

Json = dict[str, Any]
# formele luate pe gură înaintea gelurilor și a fiolelor: „un Ketonal” e de obicei o capsulă, nu crema
ORAL = ("compr", "caps", "draj", "pulb", "sol. orala", "sirop", "plic")


@dataclass
class Answer:
    text: str
    case: str  # alert / none_found / no_data
    alert_ids: list[str]
    brand: str


def pick_product(kb: Kb, query: str) -> Json | None:
    """Produsul cel mai probabil pentru numele rostit: brandul care începe cu el, luat pe gură, cu o singură substanță
    („paracetamol” → un paracetamol simplu, nu o combinație cu tramadol care îl conține)."""
    key = norm(query)
    hits = kb.search_with_keys(query, limit=40)
    if not hits:
        return None

    def rank(entry: tuple[Json, str]) -> tuple:
        hit, brand_norm = entry
        oral = any(k in (hit["form"] or "").lower() for k in ORAL)
        return (not brand_norm.startswith(key), not oral, len(hit["substances"]) != 1)

    hit, brand_norm = min(hits, key=rank)
    return {**hit, "brand": display_brand(hit["brand"], brand_norm)}


def as_med(hit: Json, today_iso: str) -> Json:
    """Un MedicationItem minim pentru what-if (aceeași formă ca la POST /what-if cu `query`)."""
    return {
        "id": "med_whatif",
        "source": "manual",
        "product": {
            "brand": hit["brand"],
            "strength_text": hit["strength_text"],
            "form": hit["form"],
            "gtin": None,
            "pack_size": None,
            "expiry": None,
            "batch": None,
        },
        "substances": hit["substances"],
        "dosage": {
            "raw": "",
            "pattern": {"morning": 0, "noon": 0, "evening": 0, "bedtime": 0},
            "as_needed": True,
            "with_food": "any",
        },
        "prescriber": {"name": None, "specialty": None},
        "start_date": today_iso,
        "end_date": None,
        "photo_url": None,
        "match": {"method": "exact_brand", "confidence": 0.9, "needs_review": False},
    }


def answer(
    drug_query: Json,
    meds: list[Json],
    kb: Kb,
    alerts_for: Callable[[list[Json]], list[Json]],
    today_iso: str,
) -> Answer | None:
    """None dacă medicamentul nu e în catalog (rămâne răspunsul generic „întrebați medicul de familie”)."""
    brand = drug_query["brand"]
    hit = pick_product(kb, drug_query["text"])
    if hit is None or not hit["substances"]:
        return None
    before = alerts_for(meds)
    after = alerts_for([*meds, as_med(hit, today_iso)])
    # mâncarea și alcoolul nu răspund la întrebarea „pot să iau”; rămân în cardul lor
    found = [a for a in new_alerts(before, after) if a["kind"] != "food"]
    if found:
        worst = min(found, key=lambda a: SEV_RANK[a["severity"]])
        return Answer(
            f"Înainte să luați {brand}, întrebați medicul de familie. {worst['title'].rstrip('.')}.",
            "alert",
            [a["id"] for a in sorted(found, key=lambda a: SEV_RANK[a["severity"]])],
            brand,
        )
    linked = [kb.resolve(s.get("inn"), s.get("dci"), s.get("atc")) for s in hit["substances"]]
    if any(sub is None or sub.ddinter_id is None for sub in linked):
        return Answer(
            f"Nu am date despre {brand} în baza de interacțiuni. Întrebați medicul sau farmacistul înainte să-l luați.",
            "no_data",
            [],
            brand,
        )
    return Answer(
        f"Nu am găsit o interacțiune cunoscută între {brand} și medicamentele dumneavoastră, "
        "dar întrebați farmacistul înainte să-l luați.",
        "none_found",
        [],
        brand,
    )
