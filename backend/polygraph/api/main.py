"""Backend-ul real PolyGraph (FastAPI), din B2: pacienți, medicamente, analiză, what-if, căutare în kb.

Pornire: `make dev` (0.0.0.0:8000). Rutele care vin în etapele următoare (schedule B4, checkins B5,
share B6) rămân deocamdată pe mock. Variabile de mediu:
- PG_KB: calea către kb.sqlite (implicit kb/kb.sqlite, `make kb`)
- PG_APP_DB: calea către app.sqlite (implicit backend/app.sqlite)
- PG_TODAY: data „de azi” (ISO), pentru demo și teste; implicit data din Europe/Bucharest
- DEMO_MODE=1: creează pacientul demo (pat_demo, token demo-token) și activează POST /demo/reset
"""

from __future__ import annotations

import copy
import json
import os
import secrets
import sys
from contextlib import asynccontextmanager
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Annotated, Any, Literal
from zoneinfo import ZoneInfo

from fastapi import FastAPI, File, Form, Header, HTTPException, Request, Response, UploadFile
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, TypeAdapter, ValidationError

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "contracts"))

import validate as contracts  # noqa: E402  (contracts/validate.py: schemele JSON)

from polygraph.engine import analyze, new_alerts  # noqa: E402
from polygraph.extract.match import confirmed_product, scan  # noqa: E402
from polygraph.extract.ocr_match import OcrLine  # noqa: E402
from polygraph.kb import Kb, KbMissing, default_kb  # noqa: E402
from polygraph.store import Store  # noqa: E402

FIX = ROOT / "contracts" / "fixtures"
DEMO = json.loads((FIX / "demo_patient.json").read_text(encoding="utf-8"))
DEMO_ID, DEMO_TOKEN = "pat_demo", "demo-token"
TZ = ZoneInfo("Europe/Bucharest")
MED_FIELDS = ("product", "substances", "dosage", "prescriber", "start_date", "end_date", "photo_url", "match", "source")


class App:
    """Dependențele procesului; testele le înlocuiesc cu `configure(...)`."""

    store: Store | None = None
    kb: Kb | None = None


deps = App()


def configure(store: Store | None = None, kb: Kb | None = None) -> None:
    deps.store, deps.kb = store, kb


def store() -> Store:
    if deps.store is None:
        deps.store = Store()
    return deps.store


def kb() -> Kb:
    if deps.kb is None:
        deps.kb = default_kb()
    return deps.kb


def today() -> date:
    raw = os.environ.get("PG_TODAY")
    return date.fromisoformat(raw) if raw else datetime.now(TZ).date()


def now_iso() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def demo_mode() -> bool:
    return os.environ.get("DEMO_MODE") == "1"


def reset_demo(live_scan: bool = False) -> None:
    s = store()
    s.delete_patient(DEMO_ID)
    s.create_patient(copy.deepcopy(DEMO["patient"]), DEMO_TOKEN)
    meds = [m for m in DEMO["meds"] if not (live_scan and m["id"] in ("med_01", "med_02"))]
    s.replace_meds(DEMO_ID, copy.deepcopy(meds))


@asynccontextmanager
async def lifespan(_: FastAPI):
    if demo_mode() and store().get_patient(DEMO_ID) is None:
        reset_demo()
    yield


app = FastAPI(title="PolyGraph", version="1.0.0", lifespan=lifespan)


def invalid(schema: str, body: Any) -> None:
    errors = contracts.schema_errors(schema, body)
    if errors:
        raise HTTPException(422, {"message": "Corpul nu respectă schema.", "errors": errors[:10]})


def auth(pid: str, token: str | None) -> dict[str, Any]:
    patient = store().get_patient(pid)
    if patient is None:
        raise HTTPException(404, "Pacientul nu există.")
    if not token or store().patient_id_for_token(token) != pid:
        raise HTTPException(401, "Lipsește sau e greșit X-Patient-Token.")
    return patient


# ---------------------------------------------------------------- sistem


@app.get("/health")
def health() -> dict[str, Any]:
    return {"ok": True, "mode": "backend"}


# ---------------------------------------------------------------- pacienți


@app.post("/v1/patients", status_code=201)
def create_patient(body: dict[str, Any]) -> dict[str, Any]:
    invalid("patient_create", body)
    patient = {
        "id": f"pat_{secrets.token_hex(4)}",
        "name": body["name"],
        "birth_year": body["birth_year"],
        "caregiver_name": body.get("caregiver_name"),
        "anchors": body.get("anchors") or DEMO["patient"]["anchors"],
    }
    token = store().create_patient(patient)
    return {"id": patient["id"], "patient_token": token, "patient": patient}


@app.get("/v1/patients/{pid}")
def get_patient(pid: str, x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    return auth(pid, x_patient_token)


@app.patch("/v1/patients/{pid}")
def update_patient(pid: str, body: dict[str, Any], x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    patient = auth(pid, x_patient_token)
    extra = set(body) - {"name", "birth_year", "caregiver_name", "anchors"}
    if extra:
        raise HTTPException(422, f"Câmpuri necunoscute: {sorted(extra)}")
    patient = {**patient, **body}
    invalid("patient", patient)
    store().update_patient(pid, patient)
    return patient


# ---------------------------------------------------------------- medicamente


class ScanLine(BaseModel):
    text: str = Field(max_length=1024)
    height: float = Field(default=0, ge=0, le=1)


OCR_LINES = TypeAdapter(list[ScanLine])
MAX_SCAN_IMAGE = 5 * 1024 * 1024


@app.post("/v1/patients/{pid}/scan")
def scan_med(
    pid: str,
    kind: Literal["box", "prescription"] = Form(),
    ocr_lines: str | None = Form(None),
    datamatrix: str | None = Form(None, max_length=256),
    image: Annotated[UploadFile | None, File()] = None,
    x_patient_token: str | None = Header(None),
) -> dict[str, Any]:
    auth(pid, x_patient_token)
    try:
        data = OCR_LINES.validate_json(ocr_lines) if ocr_lines else []
    except ValidationError:
        raise HTTPException(422, "ocr_lines trebuie să conțină liniile OCR în format JSON.") from None
    if len(data) > 256:
        raise HTTPException(422, "Sunt prea multe linii OCR.")
    picture = image.file.read(MAX_SCAN_IMAGE + 1) if image else b""
    if len(picture) > MAX_SCAN_IMAGE:
        raise HTTPException(413, "Imaginea depășește 5 MB.")
    mime = (image.content_type or "image/jpeg") if image else "image/jpeg"
    return scan(kb(), store(), kind, [OcrLine(line.text, line.height) for line in data], picture, mime, datamatrix)


@app.get("/v1/patients/{pid}/meds")
def list_meds(pid: str, x_patient_token: str | None = Header(None)) -> list[dict[str, Any]]:
    auth(pid, x_patient_token)
    return store().list_meds(pid)


@app.post("/v1/patients/{pid}/meds", status_code=201)
def add_med(pid: str, body: dict[str, Any], x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    auth(pid, x_patient_token)
    invalid("medication_item", body)
    med = copy.deepcopy(body)
    med["id"] = store().free_med_id(pid, med.get("id"))
    catalog_id = None
    if med["product"].get("gtin"):
        try:
            catalog_id = confirmed_product(kb(), med)
        except KbMissing:
            pass
    store().add_med(pid, med, catalog_id)
    return med


@app.patch("/v1/patients/{pid}/meds/{mid}")
def update_med(pid: str, mid: str, body: dict[str, Any], x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    auth(pid, x_patient_token)
    med = store().get_med(pid, mid)
    if med is None:
        raise HTTPException(404, "Medicamentul nu există.")
    extra = set(body) - set(MED_FIELDS)
    if extra:
        raise HTTPException(422, f"Câmpuri care nu se pot edita: {sorted(extra)}")
    med = {**med, **copy.deepcopy(body)}
    invalid("medication_item", med)
    store().update_med(pid, med)
    return med


@app.delete("/v1/patients/{pid}/meds/{mid}", status_code=204)
def delete_med(pid: str, mid: str, x_patient_token: str | None = Header(None)) -> Response:
    auth(pid, x_patient_token)
    if not store().delete_med(pid, mid):
        raise HTTPException(404, "Medicamentul nu există.")
    return Response(status_code=204)


# ---------------------------------------------------------------- analiză


def run_analysis(pid: str, patient: dict[str, Any], meds: list[dict[str, Any]]) -> dict[str, Any]:
    result = analyze(patient, meds, today(), kb=kb(), checkins=store().list_checkins(pid))
    states = store().alert_states(pid)
    for a in result["alerts"]:
        if a["id"] in states:
            a.update(states[a["id"]])
    return result


@app.get("/v1/patients/{pid}/analysis")
def analysis(pid: str, x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    patient = auth(pid, x_patient_token)
    result = run_analysis(pid, patient, store().list_meds(pid))
    return {**result, "analyzed_at": now_iso()}


def med_from_kb(hit: dict[str, Any], mid: str) -> dict[str, Any]:
    """Un MedicationItem minim din rezultatul căutării în kb (pentru what-if pe text)."""
    return {
        "id": mid,
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
        "start_date": today().isoformat(),
        "end_date": None,
        "photo_url": None,
        "match": {"method": "exact_brand", "confidence": 0.9, "needs_review": False},
    }


@app.post("/v1/patients/{pid}/what-if")
def what_if(pid: str, body: dict[str, Any], x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    patient = auth(pid, x_patient_token)
    invalid("what_if_request", body)
    meds = store().list_meds(pid)
    taken = {m["id"] for m in meds}
    if "med" in body:
        matched = copy.deepcopy(body["med"])
        if matched["id"] in taken:
            matched["id"] = "med_whatif"
    else:
        hits = kb().search(body["query"], limit=1)
        if not hits:
            return {"matched": None, "new_alerts": []}
        matched = med_from_kb(hits[0], "med_whatif")
    before = run_analysis(pid, patient, meds)["alerts"]
    after = run_analysis(pid, patient, [*meds, matched])["alerts"]
    return {"matched": matched, "new_alerts": new_alerts(before, after)}


# ---------------------------------------------------------------- kb


@app.get("/v1/kb/search")
def kb_search(q: str, x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    if not x_patient_token or store().patient_id_for_token(x_patient_token) is None:
        raise HTTPException(401, "Lipsește sau e greșit X-Patient-Token.")
    if len(q.strip()) < 2:
        raise HTTPException(422, "Căutarea are nevoie de cel puțin 2 caractere.")
    return {"results": kb().search(q)}


# ---------------------------------------------------------------- demo


@app.post("/demo/reset")
def demo_reset(live_scan: int = 0) -> dict[str, Any]:
    if not demo_mode():
        raise HTTPException(404, "Ruta există doar cu DEMO_MODE=1.")
    reset_demo(live_scan=bool(live_scan))
    return {"id": DEMO_ID, "patient_token": DEMO_TOKEN, "patient": store().get_patient(DEMO_ID)}


@app.exception_handler(HTTPException)
async def http_error(_: Request, exc: HTTPException) -> JSONResponse:
    return JSONResponse({"detail": exc.detail}, status_code=exc.status_code)
