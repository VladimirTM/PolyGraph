"""T-P0-01: validate.py trece pe contracte și pică pe mutații."""

import copy
import json
from pathlib import Path

import pytest
import validate as contracts

FIX = Path(__file__).resolve().parents[2] / "contracts" / "fixtures"


@pytest.fixture
def fixtures():
    return {p.name: json.loads(p.read_text()) for p in FIX.glob("*.json")}


def test_contracts_are_valid():
    assert contracts.main() == 0


def test_schemas_and_openapi():
    assert contracts.check_schemas() == []
    assert contracts.check_openapi() == []


def mutated(fixtures, fn):
    f = copy.deepcopy(fixtures)
    fn(f)
    return contracts.check_fixtures(f)


def test_invalid_enum_fails(fixtures):
    errors = mutated(fixtures, lambda f: f["expected_alerts.json"]["without_med_09"][0].update(kind="interaction"))
    assert any("kind" in e for e in errors)


def test_extra_field_fails(fixtures):
    errors = mutated(fixtures, lambda f: f["demo_patient.json"]["meds"][0].update(color="red"))
    assert any("Additional properties" in e for e in errors)


def test_missing_required_fails(fixtures):
    errors = mutated(fixtures, lambda f: f["checkin_demo.json"].pop("escalate"))
    assert any("escalate" in e for e in errors)


def test_unknown_symptom_fails(fixtures):
    errors = mutated(fixtures, lambda f: f["checkin_demo.json"]["symptoms"][0].update(code="headache_xyz"))
    assert any("necunoscut" in e for e in errors)


def test_unknown_med_id_fails(fixtures):
    errors = mutated(fixtures, lambda f: f["expected_alerts.json"]["without_med_09"][0].update(med_ids=["med_77"]))
    assert any("inexistente" in e for e in errors)


def test_forbidden_recommendation_fails(fixtures):
    def bad(f):
        f["expected_alerts.json"]["without_med_09"][0]["recommendation"] = "Opriți Sintrom-ul."

    assert any("opri" in e for e in mutated(fixtures, bad))


def test_bad_gtin_fails(fixtures):
    def bad(f):
        f["gs1_cases.json"]["cases"][0]["expected"]["gtin"] = "05949000000010"

    assert any("GTIN invalid" in e for e in mutated(fixtures, bad))


def test_symptoms_md_has_about_30_codes():
    codes, errors = contracts.symptom_codes()
    assert errors == []
    assert 28 <= len(codes) <= 40
    assert {"dizziness_orthostatic", "bruising", "black_stool", "fall", "confusion"} <= set(codes)
    assert codes["black_stool"]["red_flag"] and not codes["bruising"]["red_flag"]
