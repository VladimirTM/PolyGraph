"""„Pot să iau…?” (bonusul X1): medicamentul întrebat rulat ca what-if pe regimul pacientului (docs/PLAN.md, 1.3).

Răspunsul diferă după cea mai gravă alertă nouă (fără alimente), ca să nu fie mereu „întrebați medicul”:
- serious (critical / major): numele și motivul; „Nu luați X până nu vă răspunde medicul de familie”; eveniment în Noutăți.
- moderate (moderată sau minoră): interacțiunea, notată în fișă; fără eveniment.
- no_data (o substanță fără ddinter_id): spus deschis, întrebarea merge la medicul de familie; eveniment în Noutăți.
- none_found (toate substanțele sunt în DDInter și nu iese nimic): fără eveniment.
Niciun răspuns nu spune „puteți lua” și nimic despre tratamentele existente: interdicția privește doar medicamentul NOU.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field
from typing import Any

from polygraph.engine import new_alerts
from polygraph.extract.display import display_brand
from polygraph.kb import SEV_RANK, Kb, norm
from polygraph.voice.correlate import dative

Json = dict[str, Any]
# formele luate pe gură înaintea gelurilor și a fiolelor: „un Ketonal” e de obicei o capsulă, nu crema
ORAL = ("compr", "caps", "draj", "pulb", "sol. orala", "sirop", "plic")


SERIOUS = ("critical", "major")
WHATIF = "med_whatif"
SOURCES = {
    "ddinter": "DDInter",
    "beers": "AGS Beers 2023",
    "stopp": "STOPP/START",
    "acb": "scala ACB",
    "curated": "lista verificată de echipă",
    "rcp": "RCP (prospectul oficial)",
    "app": "aceeași clasă de medicamente (PolyGraph)",
}


@dataclass
class Answer:
    text: str
    case: str  # serious / moderate / no_data / none_found
    alert_ids: list[str]
    brand: str
    severity: str | None = None  # a celei mai grave alerte noi
    med_ids: list[str] = field(default_factory=list)  # medicamentele de pe listă implicate
    detail: str = ""  # interacțiunea și sursa, pentru corpul evenimentului din Noutăți

    @property
    def to_feed(self) -> bool:
        """Doar grav și „fără date” ajung la Ana și la medic; restul ar fi oboseală de alerte."""
        return self.case in ("serious", "no_data")


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


def _atcs(med: Json) -> list[str]:
    return [s.get("atc") or "" for s in med.get("substances") or []]


def _bleeds(atcs: list[list[str]]) -> bool:
    """Un anticoagulant / antiagregant în pereche, sau două antiinflamatoare (aspirina inclusă): sângerare."""
    anticoag = any(a.startswith("B01A") for side in atcs for a in side)
    nsaids = sum(any(a.startswith(("M01A", "N02BA")) for a in side) for side in atcs)
    return anticoag or nsaids >= 2


def _reason(alert: Json, atcs: list[list[str]]) -> str:
    if _bleeds(atcs):
        return "împreună cresc riscul de sângerare"
    if alert["kind"] == "duplicate":
        return "sunt din aceeași clasă, iar efectele se adună"
    return "au împreună o interacțiune importantă"


def _join(names: list[str]) -> str:
    return names[0] if len(names) == 1 else ", ".join(names[:-1]) + " și " + names[-1]


def answer(
    drug_query: Json,
    meds: list[Json],
    kb: Kb,
    alerts_for: Callable[[list[Json]], list[Json]],
    today_iso: str,
    caregiver: str | None = None,
) -> Answer | None:
    """None dacă medicamentul nu e în catalog (rămâne răspunsul generic „întrebați medicul de familie”)."""
    brand = drug_query["brand"]
    hit = pick_product(kb, drug_query["text"])
    if hit is None or not hit["substances"]:
        return None
    new = as_med(hit, today_iso)
    before = alerts_for(meds)
    after = alerts_for([*meds, new])
    # mâncarea și alcoolul nu răspund la întrebarea „pot să iau”; rămân în cardul lor.
    # La egalitate de severitate câștigă alerta cu medicamentul cel mai vechi de pe listă (Sintrom e med_01).
    found = sorted(
        (a for a in new_alerts(before, after) if a["kind"] != "food"),
        key=lambda a: (SEV_RANK[a["severity"]], sorted(a["med_ids"]), a["id"]),
    )
    by_id = {m["id"]: m for m in meds}
    names = {m["id"]: (m.get("product") or {}).get("brand") or m["id"] for m in meds}
    ids = [a["id"] for a in found]

    def others(alert: Json) -> list[str]:
        return [m for m in sorted(alert["med_ids"]) if m != WHATIF and m in by_id]

    if found and found[0]["severity"] in SERIOUS:
        worst = found[0]
        on_list = others(worst)
        if on_list:
            atcs = [_atcs(new), *(_atcs(by_id[m]) for m in on_list)]
            what = f"{brand} și {_join([names[m] for m in on_list])} {_reason(worst, atcs)}."
        else:
            what = f"Am găsit o alertă importantă pentru {brand}: {worst['title'].rstrip('.')}."
        source = SOURCES.get(worst["source"]["db"], worst["source"]["db"])
        return Answer(
            f"{what} Nu luați {brand} până nu vă răspunde medicul de familie. I-am trimis întrebarea lui și {dative(caregiver)}.",
            "serious",
            ids,
            brand,
            worst["severity"],
            on_list,
            f"{worst['title'].rstrip('.')}. Sursa: {source}.",
        )
    linked = [kb.resolve(s.get("inn"), s.get("dci"), s.get("atc")) for s in hit["substances"]]
    if any(sub is None or sub.ddinter_id is None for sub in linked):
        return Answer(
            f"Nu am date despre {brand}. I-am trimis întrebarea medicului de familie.",
            "no_data",
            ids,
            brand,
            None,
            [],
            f"{brand} nu are date în baza de interacțiuni (sursa verificată: DDInter).",
        )
    if found:
        sev = found[0]["severity"]
        top = [a for a in found if a["severity"] == sev]
        on_list = sorted({m for a in top for m in others(a)})
        word = "moderată" if sev == "moderate" else "minoră"
        what = (
            f"{brand} are o interacțiune {word} cu {_join([names[m] for m in on_list])}."
            if on_list
            else f"Am găsit o interacțiune {word} pentru {brand}."
        )
        who = f"{caregiver} și medicul de familie o văd" if caregiver else "medicul de familie o vede"
        return Answer(f"{what} Am notat întrebarea; {who} în fișa dumneavoastră.", "moderate", ids, brand, sev, on_list)
    return Answer("Nu am găsit o interacțiune cunoscută cu medicamentele dumneavoastră.", "none_found", [], brand)


def feed_event(patient: Json, checkin: Json, a: Answer) -> Json:
    """Evenimentul din Noutăți pentru o întrebare gravă sau fără date. Titlul nu are „: ”, ca aplicația să nu-l
    despartă în chip-uri de simptome (FeedEvent.symptomLabels)."""
    who = patient.get("name") or "Pacientul"
    answered = (
        f"I s-a spus să nu ia {a.brand} până nu răspunde medicul de familie."
        if a.case == "serious"
        else "Întrebarea așteaptă răspunsul medicului de familie."
    )
    return {
        "id": "ev_" + checkin["id"],
        "at": checkin["at"],
        "type": "checkin",
        "severity": a.severity if a.case == "serious" else None,
        "title": f"{who} a întrebat dacă poate lua {a.brand}",
        "body": f"{a.detail} {answered}",
        "med_ids": a.med_ids,
        "alert_id": None,
        "checkin_id": checkin["id"],
    }
