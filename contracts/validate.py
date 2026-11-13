"""Validează contractele PolyGraph (nivelul R1 din `make check`).

- fiecare schemă din contracts/schema/ e o JSON Schema 2020-12 validă;
- openapi.yaml e un OpenAPI 3.1 valid (cu $ref-urile către scheme rezolvate);
- exemplele (contracts/examples/<schema>.<nume>.json) și fixture-urile trec schemele;
- verificări încrucișate: id-urile de medicamente există, codurile de simptome sunt în symptoms.md,
  alertele așteptate sunt unice, GTIN-urile din gs1_cases.json au cifra de control corectă.

Rulare: `uv run --project backend python contracts/validate.py` (exit ≠ 0 la orice eroare).
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

import yaml
from jsonschema import Draft202012Validator, FormatChecker
from openapi_spec_validator import validate as validate_openapi
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT202012

ROOT = Path(__file__).resolve().parent
SCHEMA_DIR = ROOT / "schema"
FIXTURES = ROOT / "fixtures"
EXAMPLES = ROOT / "examples"


def _retrieve(uri: str) -> Resource:
    path = Path(uri.removeprefix("file://"))
    return Resource.from_contents(
        json.loads(path.read_text()), default_specification=DRAFT202012
    )


REGISTRY: Registry = Registry(retrieve=_retrieve)  # type: ignore[call-arg]


def load_schema(name: str) -> dict[str, Any]:
    path = SCHEMA_DIR / f"{name}.schema.json"
    schema = json.loads(path.read_text())
    # $id = calea fișierului, ca $ref-urile relative („alert.schema.json”) să se rezolve de pe disc
    return {**schema, "$id": path.as_uri()}


def validator(name: str) -> Draft202012Validator:
    return Draft202012Validator(
        load_schema(name), registry=REGISTRY, format_checker=FormatChecker()
    )


def schema_errors(name: str, instance: Any) -> list[str]:
    return [
        f"{'/'.join(str(p) for p in e.absolute_path) or '<root>'}: {e.message}"
        for e in sorted(
            validator(name).iter_errors(instance), key=lambda e: list(e.absolute_path)
        )
    ]


def symptom_codes(
    md_path: Path = ROOT / "symptoms.md",
) -> tuple[dict[str, dict[str, Any]], list[str]]:
    """Citește tabelul din symptoms.md → {cod: {label, synonyms, red_flag, advice}} + erori."""
    codes: dict[str, dict[str, Any]] = {}
    errors: list[str] = []
    for line in md_path.read_text().splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) != 5 or cells[0] in ("cod", "") or set(cells[0]) <= {"-"}:
            continue
        code, label, synonyms, red_flag, advice = cells
        syn = [s.strip() for s in synonyms.split(";") if s.strip()]
        if not re.fullmatch(r"[a-z][a-z_]*", code):
            errors.append(f"symptoms.md: cod invalid „{code}”")
        if code in codes:
            errors.append(f"symptoms.md: cod duplicat „{code}”")
        if len(syn) < 3:
            errors.append(f"symptoms.md: „{code}” are {len(syn)} sinonime (minimum 3)")
        if red_flag not in ("da", "nu"):
            errors.append(f"symptoms.md: „{code}” are red_flag „{red_flag}” (da / nu)")
        codes[code] = {
            "label": label,
            "synonyms": syn,
            "red_flag": red_flag == "da",
            "advice": advice,
        }
    if len(codes) < 25:
        errors.append(f"symptoms.md: doar {len(codes)} coduri (așteptat ~30)")
    return codes, errors


def gtin_ok(gtin: str) -> bool:
    if not re.fullmatch(r"\d{14}", gtin):
        return False
    body, check = gtin[:-1], int(gtin[-1])
    s = sum(int(d) * (3 if i % 2 == 0 else 1) for i, d in enumerate(reversed(body)))
    return (10 - s % 10) % 10 == check


def check_schemas() -> list[str]:
    errors = []
    for path in sorted(SCHEMA_DIR.glob("*.schema.json")):
        try:
            Draft202012Validator.check_schema(json.loads(path.read_text()))
            # rezolvă toate $ref-urile o dată (prinde referințe rupte)
            validator(path.name.removesuffix(".schema.json")).is_valid({})
        except Exception as e:  # noqa: BLE001
            errors.append(f"{path.name}: {e}")
    return errors


def check_openapi() -> list[str]:
    path = ROOT / "api" / "openapi.yaml"
    spec = yaml.safe_load(path.read_text())
    errors = []
    try:
        validate_openapi(spec, base_uri=path.as_uri())
    except Exception as e:  # noqa: BLE001
        errors.append(f"openapi.yaml: {e}")
    for ref in re.findall(r'\$ref: "(\.\./schema/[^"#]+)', path.read_text()):
        if not (path.parent / ref).resolve().exists():
            errors.append(f"openapi.yaml: $ref către un fișier inexistent: {ref}")
    return errors


def check_examples() -> list[str]:
    errors = []
    for path in sorted(EXAMPLES.glob("*.json")):
        name = path.name.split(".")[0]
        if not (SCHEMA_DIR / f"{name}.schema.json").exists():
            errors.append(f"examples/{path.name}: nu există schema „{name}”")
            continue
        errors += [
            f"examples/{path.name}: {e}"
            for e in schema_errors(name, json.loads(path.read_text()))
        ]
    return errors


def check_fixtures(fixtures: dict[str, Any] | None = None) -> list[str]:
    """Validează fixture-urile. `fixtures` permite testelor să dea variante mutate."""
    if fixtures is None:
        fixtures = {p.name: json.loads(p.read_text()) for p in FIXTURES.glob("*.json")}
    errors: list[str] = []

    def err(where: str, msgs: list[str]) -> None:
        errors.extend(f"fixtures/{where}: {m}" for m in msgs)

    demo = fixtures["demo_patient.json"]
    med09 = fixtures["med_09_fromilid.json"]
    err("demo_patient.json#patient", schema_errors("patient", demo["patient"]))
    for i, m in enumerate(demo["meds"]):
        err(f"demo_patient.json#meds/{i}", schema_errors("medication_item", m))
    err("med_09_fromilid.json", schema_errors("medication_item", med09))
    med_ids = [m.get("id") for m in demo["meds"]] + [med09.get("id")]
    if len(set(med_ids)) != len(med_ids):
        err("demo_patient.json", ["id-uri de medicamente duplicate"])

    exp = fixtures["expected_alerts.json"]
    alert_ids: set[str] = set()
    for group in ("without_med_09", "added_with_med_09"):
        for i, a in enumerate(exp[group]):
            where = f"expected_alerts.json#{group}/{i}"
            err(where, schema_errors("alert", a))
            if a.get("id") in alert_ids:
                err(where, [f"id duplicat {a.get('id')}"])
            alert_ids.add(a.get("id"))
            unknown = set(a.get("med_ids", [])) - set(med_ids)
            if unknown:
                err(where, [f"med_ids inexistente: {sorted(unknown)}"])
            if group == "without_med_09" and "med_09" in a.get("med_ids", []):
                err(where, ["alertă cu med_09 în lista fără med_09"])
            if group == "added_with_med_09" and "med_09" not in a.get("med_ids", []):
                err(where, ["alertă fără med_09 în lista added_with_med_09"])
            rec = a.get("recommendation", "").lower()
            if re.search(r"opri|nu mai lua|\bmg\b", rec):
                err(where, ["recommendation conține „opri”, „nu mai lua” sau o doză"])

    sched = fixtures["expected_schedule.json"]
    err("expected_schedule.json", schema_errors("schedule", sched))
    for mo in sched.get("moments", []):
        for d in mo.get("doses", []):
            if d.get("med_id") not in med_ids:
                err("expected_schedule.json", [f"med_id inexistent {d.get('med_id')}"])

    codes, sym_errors = symptom_codes()
    errors.extend(sym_errors)
    ci = fixtures["checkin_demo.json"]
    err("checkin_demo.json", schema_errors("checkin", ci))
    for s in ci.get("symptoms", []):
        if s.get("code") not in codes:
            err("checkin_demo.json", [f"cod de simptom necunoscut {s.get('code')}"])
    for c in ci.get("correlations", []):
        if c.get("symptom") not in codes:
            err(
                "checkin_demo.json",
                [f"corelare cu simptom necunoscut {c.get('symptom')}"],
            )
        if set(c.get("med_ids", [])) - set(med_ids):
            err(
                "checkin_demo.json",
                [f"corelare cu med_ids inexistente {c.get('med_ids')}"],
            )
        basis = c.get("basis", "")
        if basis.startswith("alert:") and basis.removeprefix("alert:") not in alert_ids:
            err("checkin_demo.json", [f"basis către o alertă inexistentă {basis}"])

    for i, case in enumerate(fixtures["gs1_cases.json"]["cases"]):
        where = f"gs1_cases.json#cases/{i}"
        for key in ("name", "raw", "expected"):
            if key not in case:
                err(where, [f"lipsește „{key}”"])
        expected = case.get("expected")
        if expected is None:
            if not case.get("error"):
                err(where, ["expected = null fără „error”"])
            continue
        if set(expected) != {"gtin", "expiry", "batch", "serial"}:
            err(where, ["expected trebuie să aibă exact gtin, expiry, batch, serial"])
        if not gtin_ok(expected.get("gtin") or ""):
            err(where, [f"GTIN invalid {expected.get('gtin')}"])
        if case.get("med_id") and case["med_id"] not in med_ids:
            err(where, [f"med_id inexistent {case['med_id']}"])
    return errors


def main() -> int:
    errors = check_schemas() + check_openapi() + check_examples() + check_fixtures()
    for e in errors:
        print(f"✗ {e}")
    if errors:
        print(f"\n{len(errors)} erori în contracte.")
        return 1
    n_schemas = len(list(SCHEMA_DIR.glob("*.schema.json")))
    n_examples = len(list(EXAMPLES.glob("*.json")))
    print(
        f"✓ contracte valide: {n_schemas} scheme, openapi.yaml, {n_examples} exemple, fixture-urile demo"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
