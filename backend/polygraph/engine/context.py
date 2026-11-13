"""Contextul unei analize: pacientul, medicamentele active, substanțele lor rezolvate în kb și constructorul de alerte."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from typing import Any

from polygraph.engine import texts_ro as T
from polygraph.kb import SEV_RANK, Kb, Substance

Json = dict[str, Any]


@dataclass(frozen=True)
class Component:
    """O substanță dintr-un medicament activ, cu rândul din kb (None dacă nu e în kb)."""

    med: Json
    raw: Json
    sub: Substance | None

    @property
    def med_id(self) -> str:
        return self.med["id"]

    @property
    def atc(self) -> str | None:
        return (self.sub.atc if self.sub else None) or self.raw.get("atc")

    @property
    def atc4(self) -> str | None:
        atc = self.atc
        return atc[:5] if atc and len(atc) >= 5 else None

    @property
    def key(self) -> str:
        """Identitatea substanței: id-ul din kb sau, în lipsă, INN / ATC / DCI din medicament."""
        if self.sub:
            return f"kb:{self.sub.id}"
        return "raw:" + (self.raw.get("inn") or self.raw.get("atc") or self.raw.get("dci") or "?").lower()

    @property
    def name_ro(self) -> str:
        if self.sub:
            return T.ro_name(self.sub.inn, self.sub.dci_ro)
        return T.ro_name(self.raw.get("inn"), self.raw.get("dci"))


@dataclass
class Ctx:
    patient: Json
    meds: list[Json]  # doar cele active, în ordinea primită
    today: date
    kb: Kb
    components: list[Component] = field(default_factory=list)
    unknown_pairs: list[tuple[Component, Component]] = field(default_factory=list)  # muchii gri în graf

    @property
    def age(self) -> int | None:
        by = self.patient.get("birth_year")
        return self.today.year - by if by else None

    @property
    def caregiver(self) -> str | None:
        return self.patient.get("caregiver_name")

    def med(self, mid: str) -> Json:
        return next(m for m in self.meds if m["id"] == mid)


def brand(med: Json) -> str:
    return (med.get("product") or {}).get("brand") or "medicamentul"


def specialty(med: Json) -> str | None:
    return (med.get("prescriber") or {}).get("specialty")


def route_to(kind: str, severity: str) -> list[str]:
    """Plan 5.3: critical / major (în afară de food) → aparținător + medic; moderate → aparținător; minor → medicul de familie.

    Alertele de mâncare stau în cardul lor („Mâncare și băutură”): moderate și peste → aparținător + medicul de familie.
    Pacientul primește direct doar interacțiunile grave (vede `patient_text`).
    """
    if kind == "food":
        return ["doctor"] if SEV_RANK[severity] >= SEV_RANK["minor"] else ["caregiver", "doctor"]
    if severity in ("critical", "major"):
        return (["patient"] if kind in ("ddi", "duplicate", "expired") else []) + ["caregiver", "doctor"]
    if severity == "moderate":
        return ["caregiver"]
    if severity == "minor":
        return ["doctor"]
    return ["patient"]


def alert_id(kind: str, med_ids: list[str], suffix: str | None = None) -> str:
    parts = ["al", kind, *sorted(med_ids)]
    if suffix:
        parts.append(suffix)
    return "_".join(parts).lower()


def make_alert(
    *,
    kind: str,
    severity: str,
    med_ids: list[str],
    title: str,
    patient_text: str,
    detail: str,
    recommendation: str,
    action: str,
    source: Json,
    basis: str = "direct",
    analogy: Json | None = None,
    suffix: str | None = None,
) -> Json:
    med_ids = sorted(set(med_ids))
    return {
        "id": alert_id(kind, med_ids, suffix),
        "kind": kind,
        "severity": severity,
        "med_ids": med_ids,
        "title": title,
        "patient_text": patient_text,
        "detail": detail,
        "recommendation": T.safe_recommendation(recommendation),
        "action": action,
        "route_to": route_to(kind, severity),
        "source": {"db": source.get("db", "app"), "ref": source.get("ref"), "url": source.get("url")},
        "basis": basis,
        "analogy": analogy,
        "status": "open",
        "resolution": None,
    }
