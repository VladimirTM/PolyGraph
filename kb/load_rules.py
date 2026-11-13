"""Regulile YAML din kb/rules/ → tabelele elderly_rule, acb, timing_rule, adverse_effect, food_alias.

Fiecare fișier e validat de un model pydantic (T-B1-03); fiecare regulă trebuie să aibă `source`.
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Annotated, Literal

import yaml
from pydantic import BaseModel, ConfigDict, Field, StringConstraints, field_validator, model_validator

from common import RULES_DIR, SYMPTOMS_PATH, norm

Source = Annotated[str, StringConstraints(strip_whitespace=True, min_length=3)]
Atc = Annotated[str, StringConstraints(pattern=r"^[A-Z][0-9A-Z]{0,6}$")]


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


# --- elderly.yaml -------------------------------------------------------------------------


class Condition(Strict):
    duration_days_min: int | None = None
    strength_mg_gt: float | None = None


class AtcSelector(Strict):
    atc_prefix: list[Atc]
    exclude_atc: list[Atc] = []


class ElderlyRule(Strict):
    id: str
    atc: list[Atc] | None = None
    atc_prefix: list[Atc] | None = None
    exclude_atc: list[Atc] = []
    with_atc_prefix: list[Atc] | None = None
    condition: Condition | None = None
    count_classes_min: int | None = None
    classes: dict[str, list[Atc] | AtcSelector] | None = None
    severity: Literal["critical", "major", "moderate", "minor", "info"]
    title: str
    detail: str
    recommendation: str
    source: Source
    stopp_id: str = ""

    @model_validator(mode="after")
    def _has_selector(self):
        if not (self.atc or self.atc_prefix or (self.count_classes_min and self.classes)):
            raise ValueError(f"{self.id}: lipsește atc / atc_prefix / count_classes_min + classes")
        return self


class ElderlyFile(Strict):
    version: int
    age_min: int
    rules: list[ElderlyRule]


# --- acb.yaml -----------------------------------------------------------------------------


class AcbFile(Strict):
    version: int
    threshold_alert: int
    source: Source
    scores: dict[Literal[1, 2, 3], list[str]]


# --- timing.yaml --------------------------------------------------------------------------


class Separation(Strict):
    other: str
    hours: float = Field(gt=0)
    direction: Literal["before", "after", "either"]


class TimingRule(Strict):
    inn: str
    atc: Atc
    with_food: Literal["empty_stomach", "before_meal", "with_meal", "after_meal", "any"]
    preferred_time: Literal["morning", "evening", "bedtime", "same_time_daily", "none"] = "none"
    min_separation: list[Separation] = []
    minutes_before_breakfast: int | None = None
    default_time: str | None = None
    latest_time: str | None = None
    interval_hours: float | None = None
    weekly: bool = False
    alone: bool = False
    instruction: str
    source: Source
    verified: bool


class TimingFile(Strict):
    version: int
    rules: list[TimingRule]


# --- adverse_effects.yaml -----------------------------------------------------------------


class AdverseEffect(Strict):
    inn: str
    atc: Atc
    effects: list[str] = Field(min_length=1)
    source: Source
    verified: bool


class AdverseFile(Strict):
    version: int
    substances: list[AdverseEffect]


# --- food_alias.yaml ----------------------------------------------------------------------


class FoodAlias(Strict):
    key: Annotated[str, StringConstraints(pattern=r"^[a-z][a-z0-9_]*$")]
    label_ro: str
    synonyms: list[str] = []
    ddinter: list[str] = []
    source: Source

    @field_validator("synonyms")
    @classmethod
    def _nonempty(cls, v):
        return [s for s in v if s.strip()]


class FoodFile(Strict):
    version: int
    foods: list[FoodAlias]


FILES = {
    "elderly": ("elderly.yaml", ElderlyFile),
    "acb": ("acb.yaml", AcbFile),
    "timing": ("timing.yaml", TimingFile),
    "adverse_effects": ("adverse_effects.yaml", AdverseFile),
    "food_alias": ("food_alias.yaml", FoodFile),
}


def load_all(rules_dir: Path = RULES_DIR) -> dict[str, BaseModel]:
    out = {}
    for key, (name, model) in FILES.items():
        with (rules_dir / name).open(encoding="utf-8") as fh:
            out[key] = model.model_validate(yaml.safe_load(fh))
    return out


def symptom_codes(path: Path = SYMPTOMS_PATH) -> set[str]:
    """Codurile din tabelul din contracts/symptoms.md (prima coloană)."""
    codes = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\|\s*([a-z][a-z0-9_]*)\s*\|", line)
        if m and m.group(1) != "cod":
            codes.add(m.group(1))
    return codes


class FoodKeys:
    """Potrivește alimentul dintr-un rând curated pe cheia din food_alias.yaml (etichetă sau sinonim)."""

    def __init__(self, foods: FoodFile):
        self.lookup = {}
        for f in foods.foods:
            for text in [f.label_ro, *f.synonyms, *f.ddinter]:
                self.lookup[norm(text)] = f.key

    def __call__(self, food_ro: str) -> str:
        key = self.lookup.get(norm(food_ro))
        if key is None:
            raise ValueError(f"alimentul {food_ro!r} din curated_dfi.csv nu are cheie în food_alias.yaml")
        return key


def write_rules(conn, rules: dict[str, BaseModel], sub_by_inn: dict[str, int]) -> list[str]:
    """Scrie regulile; întoarce INN-urile din reguli care nu există în substance (avertismente)."""
    missing: list[str] = []

    def sid(inn: str) -> int | None:
        s = sub_by_inn.get(norm(inn))
        if s is None:
            missing.append(inn)
        return s

    elderly: ElderlyFile = rules["elderly"]
    conn.execute("INSERT INTO kb_meta(key, value) VALUES ('elderly_age_min', ?)", (str(elderly.age_min),))
    for r in elderly.rules:
        conn.execute(
            "INSERT INTO elderly_rule(id, severity, title, detail, recommendation, source, stopp_id, spec)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (r.id, r.severity, r.title, r.detail, r.recommendation, r.source, r.stopp_id, r.model_dump_json(exclude_none=True)),
        )

    acb: AcbFile = rules["acb"]
    conn.execute("INSERT INTO kb_meta(key, value) VALUES ('acb_threshold_alert', ?)", (str(acb.threshold_alert),))
    for score, inns in acb.scores.items():
        for inn in inns:
            conn.execute(
                "INSERT INTO acb(inn, substance_id, score, source) VALUES (?, ?, ?, ?)", (norm(inn), sid(inn), score, acb.source)
            )

    for r in rules["timing"].rules:
        conn.execute(
            "INSERT INTO timing_rule(inn, substance_id, atc, with_food, preferred_time, instruction, source, verified, spec)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                norm(r.inn),
                sid(r.inn),
                r.atc,
                r.with_food,
                r.preferred_time,
                r.instruction,
                r.source,
                r.verified,
                r.model_dump_json(),
            ),
        )

    for a in rules["adverse_effects"].substances:
        s = sid(a.inn)
        for code in a.effects:
            conn.execute(
                "INSERT INTO adverse_effect(inn, substance_id, atc, symptom_code, source, verified) VALUES (?, ?, ?, ?, ?, ?)",
                (norm(a.inn), s, a.atc, code, a.source, a.verified),
            )

    for f in rules["food_alias"].foods:
        conn.execute(
            "INSERT INTO food_alias(key, label_ro, synonyms, ddinter, source) VALUES (?, ?, ?, ?, ?)",
            (f.key, f.label_ro, json.dumps(f.synonyms, ensure_ascii=False), json.dumps(f.ddinter), f.source),
        )
    return missing
