"""Textele alertelor, în română, din template-uri per `kind` (fără LLM).

`title`, `patient_text` și `recommendation` sunt în română, cu numele comerciale ale pacientului.
Mecanismul și managementul din kb (curated în română, DDInter fără text) merg doar în `detail`.
Regula de siguranță: `recommendation` nu conține niciodată „opri…”, „nu mai luați” sau doze (T-B2-03);
`safe_recommendation` o verifică și, dacă un text din kb ar încălca regula, pune textul generic.
"""

from __future__ import annotations

import re

from polygraph.kb import norm

FORBIDDEN = re.compile(r"opri|nu mai lua|\bmg\b|\bmcg\b|\bml\b|\bui\b|\d\s*(?:cp|comprimat|capsul|pastil)", re.IGNORECASE)
GENERIC_RECOMMENDATION = "Discutați cu medicul sau cu farmacistul; arătați-le lista completă de medicamente."

SEVERITY_RO = {"critical": "de evitat", "major": "importantă", "moderate": "moderată", "minor": "minoră", "info": "informativă"}

SPECIALIST = {
    "cardiologie": "medicul cardiolog",
    "medicina de familie": "medicul de familie",
    "endocrinologie": "medicul endocrinolog",
    "gastroenterologie": "medicul gastroenterolog",
    "neurologie": "medicul neurolog",
    "orl": "medicul ORL",
    "psihiatrie": "medicul psihiatru",
    "reumatologie": "medicul reumatolog",
    "diabetologie": "medicul diabetolog",
    "nefrologie": "medicul nefrolog",
    "urologie": "medicul urolog",
    "pneumologie": "medicul pneumolog",
    "geriatrie": "medicul geriatru",
    "ortopedie": "medicul ortoped",
}


def safe_recommendation(text: str | None) -> str:
    text = (text or "").strip()
    if not text or FORBIDDEN.search(text):
        return GENERIC_RECOMMENDATION
    return text


def doctor(specialty: str | None) -> str:
    return SPECIALIST.get(norm(specialty), "medicul") if specialty else "medicul"


def ro_name(inn: str | None, dci_ro: str | None = None) -> str:
    """Numele românesc al substanței, din DCI-ul latin („WARFARINUM” → „warfarină”) sau din INN."""
    if dci_ro and " " not in dci_ro.strip():
        w = dci_ro.strip().lower()
        for a, b in (("th", "t"), ("ph", "f"), ("y", "i")):
            w = w.replace(a, b)
        if w.endswith("inum"):
            return w[:-4] + "ină"
        if w.endswith("um"):
            return w[:-2]
        return w
    w = (inn or dci_ro or "").strip().lower()
    for a, b in (("th", "t"), ("ph", "f"), ("y", "i"), ("oumarol", "umarol")):
        w = w.replace(a, b)
    if w.endswith("ine"):
        return w[:-1] + "ă"
    if w.endswith("in"):
        return w + "ă"
    if w.endswith("ole"):
        return w[:-1]
    return w


def articulated(name: str) -> str:
    """Forma articulată: „warfarină” → „warfarina”, „naproxen” → „naproxenul”."""
    if name.endswith("ă"):
        return name[:-1] + "a"
    if " " in name:
        return name
    return name + "ul"


def notify(caregiver: str | None) -> str:
    return f"Am trimis un mesaj către {caregiver}." if caregiver else "Am pregătit lista pentru farmacist."


def analogy_note(via_ro: str) -> str:
    return f"Evaluat prin analogie cu {articulated(via_ro)} (aceeași clasă); de confirmat de farmacist."


# ---------------------------------------------------------------- ddi


def ddi_title(severity: str, brand_a: str, brand_b: str) -> str:
    if severity == "critical":
        return f"{brand_a} și {brand_b}: combinație de evitat"
    if severity == "major":
        return f"{brand_a} și {brand_b}: interacțiune importantă"
    return f"{brand_a} și {brand_b}: interacțiune {SEVERITY_RO[severity]}"


def ddi_patient_text(severity: str, caregiver: str | None) -> str:
    if severity in ("critical", "major"):
        return f"Două dintre pastile, luate împreună, trebuie verificate de medic. {notify(caregiver)}"
    if severity == "moderate":
        return "Două dintre pastile se influențează puțin una pe alta. Farmacistul vă poate spune mai multe."
    return "O mică observație pentru farmacist, nimic de schimbat acum."


def ddi_recommendation(severity: str, action: str, newer_brand: str, other_specialty: str | None) -> str:
    if severity == "critical":
        return (
            f"Discutați cu medicul care a prescris {newer_brand} înainte de următoarea doză; "
            "arătați-i și farmacistului lista completă."
        )
    if severity == "major":
        return f"Discutați cu {doctor(other_specialty)} sau cu farmacistul înainte de următoarea doză de {newer_brand}."
    if action == "separate_times":
        return "Luați-le la ore diferite; programul zilnic din aplicație le separă deja."
    if severity == "moderate":
        return "Discutați cu farmacistul la următoarea vizită; arătați-i lista de medicamente."
    return "De verificat de farmacist la următoarea revizuire a listei."


# ---------------------------------------------------------------- food


def food_title(brand: str, food_label: str) -> str:
    return f"{brand} și {food_label}"


def food_patient_text(brand: str, food_label: str) -> str:
    return f"Atenție la {food_label} cât luați {brand}."


# ---------------------------------------------------------------- duplicate


def duplicate_title(same_substance: bool) -> str:
    return "Același medicament sub două nume" if same_substance else "Două medicamente din aceeași clasă"


def duplicate_patient_text(brands: list[str], caregiver: str | None) -> str:
    return f"{' și '.join(brands)} par să facă același lucru. {notify(caregiver)}"


def duplicate_recommendation() -> str:
    return "Arătați ambele cutii farmacistului sau medicului înainte de următoarea doză, ca să vă spună pe care o păstrați."


# ---------------------------------------------------------------- elderly / ACB / expirare


def elderly_patient_text(severity: str, caregiver: str | None) -> str:
    if severity in ("critical", "major"):
        return f"Una dintre pastile trebuie discutată cu medicul. {notify(caregiver)}"
    return "Una dintre pastile e bine să fie revăzută la următoarea vizită la medic."


def acb_title(total: int) -> str:
    return f"Efect anticolinergic cumulat (scor ACB {total})"


def acb_detail(total: int, names: list[str]) -> str:
    return (
        f"Scorul ACB total este {total} ({', '.join(names)}). Un scor de 3 sau mai mare crește riscul de confuzie, "
        "căderi și declin cognitiv la vârstnici."
    )


ACB_PATIENT = "Unele pastile pot da gură uscată, constipație sau amețeală. Spuneți-ne dacă le simțiți."
ACB_RECOMMENDATION = "Întrebați farmacistul sau medicul de familie dacă se poate reduce efectul anticolinergic al tratamentului."


def expired_title(brand: str) -> str:
    return f"Cutia de {brand} a expirat"


def expired_patient_text(brand: str) -> str:
    return f"Cutia de {brand} a expirat. Cereți una nouă de la farmacie."


EXPIRED_RECOMMENDATION = "Cereți la farmacie o cutie nouă și duceți-o pe cea expirată acolo, pentru reciclare."


# ---------------------------------------------------------------- timing (B4)


def timing_title(brands: list[str]) -> str:
    return f"Orele pentru {' și '.join(brands)} nu se potrivesc cu toate regulile"


def timing_patient_text(caregiver: str | None) -> str:
    who = f"{caregiver} și farmacistul vor" if caregiver else "Farmacistul va"
    return f"{who} verifica orele la care luați pastilele. Până atunci, luați-le ca de obicei."


def timing_recommendation(brands: list[str]) -> str:
    return f"Arătați programul farmacistului și întrebați-l cum se pot împărți orele pentru {' și '.join(brands)}."
