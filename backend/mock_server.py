"""Serverul mock PolyGraph (P0): servește fixture-urile din contracts/ pe toate rutele din openapi.yaml.

Dev A construiește aplicația pe el din prima oră; nimic de aici nu e logică reală (motorul e B2).
Starea e în memorie și se pierde la repornire. Pornire: `make mock` (0.0.0.0:8000).

Pacientul demo: id `pat_demo`, token `demo-token`. `POST /v1/patients` creează un pacient nou care
primește cele 8 medicamente din fixture (ca onboarding-ul să ajungă direct la lista demo).
"""

from __future__ import annotations

import copy
import json
import re
import secrets
import struct
import zlib
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from typing import Any

from fastapi import FastAPI, Header, HTTPException, Request, Response
from fastapi.responses import HTMLResponse, JSONResponse

ROOT = Path(__file__).resolve().parent.parent
FIX = ROOT / "contracts" / "fixtures"


def _load(name: str) -> Any:
    return json.loads((FIX / name).read_text())


DEMO = _load("demo_patient.json")
MED_09 = _load("med_09_fromilid.json")
EXPECTED = _load("expected_alerts.json")
SCHEDULE = _load("expected_schedule.json")
CHECKIN = _load("checkin_demo.json")
GS1 = _load("gs1_cases.json")
ALL_ALERTS: list[dict[str, Any]] = EXPECTED["without_med_09"] + EXPECTED["added_with_med_09"]
ALL_MEDS: dict[str, dict[str, Any]] = {m["id"]: m for m in [*DEMO["meds"], MED_09]}

SEV_ORDER = {"critical": 0, "major": 1, "moderate": 2, "minor": 3, "info": 4}
ACB = {"amitriptyline": 3}
ATC4_LABELS = {
    "B01AA": "antagoniști ai vitaminei K",
    "M01AE": "antiinflamatoare (derivați de acid propionic)",
    "C10AA": "statine",
    "C08CA": "blocante ale canalelor de calciu",
    "H03AA": "hormoni tiroidieni",
    "A12AA": "calciu",
    "A11CC": "vitamina D",
    "A02BC": "inhibitori de pompă de protoni",
    "N06AA": "antidepresive triciclice",
    "J01FA": "macrolide",
}
FOOD_LABELS = {
    "grapefruit": "grepfrut",
    "alcohol": "alcool",
    "vitamin_k": "legume cu frunze verzi (vitamina K)",
    "soy": "soia",
    "fiber": "fibre alimentare",
}
KB_EXTRA = [
    {
        "brand": "Algocalmin",
        "strength_text": "500 mg",
        "form": "comprimate",
        "substances": [{"dci": "METAMIZOLUM NATRICUM", "inn": "metamizole sodium", "atc": "N02BB02", "strength_mg": 500.0}],
    }
]


def now() -> datetime:
    return datetime.now(UTC).replace(microsecond=0)


def iso(dt: datetime) -> str:
    return dt.isoformat().replace("+00:00", "Z")


class State:
    def __init__(self) -> None:
        self.patients: dict[str, dict[str, Any]] = {}
        self.tokens: dict[str, str] = {}  # token → patient id
        self.meds: dict[str, dict[str, dict[str, Any]]] = {}
        self.doses: dict[str, dict[tuple[str, str], dict[str, Any]]] = {}
        self.feed: dict[str, list[dict[str, Any]]] = {}
        self.alert_state: dict[str, dict[str, dict[str, Any]]] = {}
        self.shares: dict[str, tuple[str, datetime]] = {}
        self.counter = 0

    def next_id(self, prefix: str) -> str:
        self.counter += 1
        return f"{prefix}_{self.counter:04d}"

    def create(self, pid: str, token: str, patient: dict[str, Any], med_ids: list[str]) -> None:
        self.patients[pid] = patient
        self.tokens = {t: p for t, p in self.tokens.items() if p != pid}
        self.tokens[token] = pid
        self.meds[pid] = {mid: copy.deepcopy(ALL_MEDS[mid]) for mid in med_ids}
        self.doses[pid] = {}
        self.feed[pid] = []
        self.alert_state[pid] = {}

    def reset_demo(self, live_scan: bool = False) -> None:
        ids = [m["id"] for m in DEMO["meds"]]
        if live_scan:
            ids = [i for i in ids if i not in ("med_01", "med_02")]
        self.create("pat_demo", "demo-token", copy.deepcopy(DEMO["patient"]), ids)


state = State()
state.reset_demo()

app = FastAPI(title="PolyGraph mock", version="1.0.0")


def auth(pid: str, token: str | None) -> dict[str, Any]:
    if pid not in state.patients:
        raise HTTPException(404, "Pacientul nu există.")
    if not token or state.tokens.get(token) != pid:
        raise HTTPException(401, "Lipsește sau e greșit X-Patient-Token.")
    return state.patients[pid]


def active_med_ids(pid: str) -> set[str]:
    return set(state.meds[pid])


def analysis_alerts(pid: str) -> list[dict[str, Any]]:
    present = active_med_ids(pid)
    out = []
    for a in ALL_ALERTS:
        if set(a["med_ids"]) <= present:
            a = copy.deepcopy(a)
            caregiver = state.patients[pid].get("caregiver_name") or "aparținătorul"
            a["patient_text"] = a["patient_text"].replace("Ana", caregiver)
            a.update(state.alert_state[pid].get(a["id"], {}))
            out.append(a)
    return sorted(out, key=lambda a: (SEV_ORDER[a["severity"]], a["kind"], a["id"]))


def acb_total(pid: str) -> int:
    return sum(ACB.get(s["inn"] or "", 0) for m in state.meds[pid].values() for s in m["substances"])


def build_graph(pid: str, alerts: list[dict[str, Any]]) -> dict[str, Any]:
    patient = state.patients[pid]
    nodes: dict[str, dict[str, Any]] = {"p": {"id": "p", "type": "patient", "label": patient["name"]}}
    edges: list[dict[str, Any]] = []
    sub_of_med: dict[str, list[str]] = {}
    worst: dict[str, str] = {}
    for a in alerts:
        for mid in a["med_ids"]:
            if mid not in worst or SEV_ORDER[a["severity"]] < SEV_ORDER[worst[mid]]:
                worst[mid] = a["severity"]
    for mid, m in state.meds[pid].items():
        label = " ".join(x for x in (m["product"]["brand"], m["product"]["strength_text"]) if x)
        node = {"id": mid, "type": "product", "label": label, "prescriber": m["prescriber"]["specialty"]}
        if mid in worst:
            node["severity"] = worst[mid]
        nodes[mid] = node
        edges.append({"source": "p", "target": mid, "type": "takes"})
        for s in m["substances"]:
            if not s["atc"]:
                continue
            sid, cid = f"s:{s['atc']}", f"c:{s['atc'][:5]}"
            nodes.setdefault(sid, {"id": sid, "type": "substance", "label": s["inn"] or s["dci"] or s["atc"]})
            if cid not in nodes:
                nodes[cid] = {"id": cid, "type": "atc_class", "label": ATC4_LABELS.get(s["atc"][:5], s["atc"][:5])}
                edges.append({"source": sid, "target": cid, "type": "in_class"})
            elif not any(e["source"] == sid and e["target"] == cid for e in edges):
                edges.append({"source": sid, "target": cid, "type": "in_class"})
            edges.append({"source": mid, "target": sid, "type": "contains"})
            sub_of_med.setdefault(mid, []).append(sid)
    for a in alerts:
        if a["kind"] == "ddi" and len(a["med_ids"]) == 2:
            sa, sb = (sub_of_med.get(x, [None])[0] for x in a["med_ids"])
            if sa and sb:
                edges.append({"source": sa, "target": sb, "type": "interacts", "severity": a["severity"], "alert_id": a["id"]})
        if a["kind"] == "food":
            food = a["id"].rsplit("_", 1)[-1]
            fid = f"f:{food}"
            nodes.setdefault(fid, {"id": fid, "type": "food", "label": FOOD_LABELS.get(food, food)})
            sid = sub_of_med.get(a["med_ids"][0], [None])[0]
            if sid:
                edges.append(
                    {
                        "source": sid,
                        "target": fid,
                        "type": "food_interaction",
                        "severity": a["severity"],
                        "alert_id": a["id"],
                    }
                )
    for i, e in enumerate(edges):
        e["id"] = f"e{i}"
    return {"nodes": [{"data": n} for n in nodes.values()], "edges": [{"data": e} for e in edges]}


def push_event(pid: str, type_: str, title: str, body: str, *, severity=None, med_ids=None, alert_id=None, checkin_id=None):
    ev = {
        "id": state.next_id("ev"),
        "at": iso(now()),
        "type": type_,
        "severity": severity,
        "title": title,
        "body": body,
        "med_ids": med_ids or [],
        "alert_id": alert_id,
        "checkin_id": checkin_id,
    }
    state.feed[pid].append(ev)
    return ev


def emit_new_alerts(pid: str, before: set[str]) -> None:
    name = state.patients[pid]["name"]
    for a in analysis_alerts(pid):
        if a["id"] not in before and a["severity"] in ("critical", "major", "moderate"):
            push_event(
                pid,
                "alert_new",
                a["title"],
                f"Alertă nouă pentru {name}: {a['recommendation']}",
                severity=a["severity"],
                med_ids=a["med_ids"],
                alert_id=a["id"],
            )


# ---------------------------------------------------------------- sistem


@app.get("/health")
def health() -> dict[str, Any]:
    return {"ok": True, "mode": "mock"}


def _placeholder_png(w: int = 320, h: int = 240) -> bytes:
    raw = b"".join(b"\x00" + bytes([0xD9, 0xD4, 0xC7]) * w for _ in range(h))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


PLACEHOLDER = _placeholder_png()


@app.get("/media/{name}")
def media(name: str) -> Response:
    return Response(PLACEHOLDER, media_type="image/png")


# ---------------------------------------------------------------- pacienți


@app.post("/v1/patients", status_code=201)
def create_patient(body: dict[str, Any]) -> dict[str, Any]:
    if not body.get("name") or not isinstance(body.get("birth_year"), int):
        raise HTTPException(422, "Lipsesc numele sau anul nașterii.")
    pid = f"pat_{secrets.token_hex(4)}"
    token = secrets.token_urlsafe(16)
    patient = {
        "id": pid,
        "name": body["name"],
        "birth_year": body["birth_year"],
        "caregiver_name": body.get("caregiver_name", DEMO["patient"]["caregiver_name"]),
        "anchors": body.get("anchors") or DEMO["patient"]["anchors"],
    }
    state.create(pid, token, patient, [m["id"] for m in DEMO["meds"]])
    return {"id": pid, "patient_token": token, "patient": patient}


@app.get("/v1/patients/{pid}")
def get_patient(pid: str, x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    return auth(pid, x_patient_token)


@app.patch("/v1/patients/{pid}")
def update_patient(pid: str, body: dict[str, Any], x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    patient = auth(pid, x_patient_token)
    patient.update({k: v for k, v in body.items() if k in ("name", "birth_year", "caregiver_name", "anchors")})
    return patient


# ---------------------------------------------------------------- medicamente


def _gtin_from(raw: str) -> str | None:
    m = re.search(r"01(\d{14})", raw.removeprefix("]d2"))
    return m.group(1) if m else None


@app.post("/v1/patients/{pid}/scan")
async def scan(pid: str, request: Request, x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    auth(pid, x_patient_token)
    form = await request.form()
    kind = form.get("kind")
    if kind not in ("box", "prescription"):
        raise HTTPException(422, "kind trebuie să fie box sau prescription.")
    lines = []
    if isinstance(form.get("ocr_lines"), str) and form["ocr_lines"]:
        try:
            lines = [ln.get("text", "") for ln in json.loads(form["ocr_lines"])]
        except (ValueError, AttributeError):
            raise HTTPException(422, "ocr_lines nu e JSON valid.") from None
    raw_text = "\n".join(lines) or None
    present = active_med_ids(pid)
    warnings: list[str] = []
    candidate: dict[str, Any] | None = None

    if kind == "prescription":
        if "med_09" in present:
            warnings.append("Rețeta pare să fie deja adăugată.")
        else:
            candidate = copy.deepcopy(MED_09)
    else:
        dm = form.get("datamatrix")
        if isinstance(dm, str) and dm:
            gtin = _gtin_from(dm)
            case = next(
                (c for c in GS1["cases"] if c.get("expected") and c["expected"]["gtin"] == gtin and c.get("med_id")),
                None,
            )
            if case:
                candidate = copy.deepcopy(ALL_MEDS[case["med_id"]])
                exp = case["expected"]
                candidate["product"].update({"gtin": exp["gtin"], "expiry": exp["expiry"], "batch": exp["batch"]})
                candidate["source"] = "datamatrix"
            else:
                warnings.append("Codul de pe cutie nu e în fixture-urile mock-ului; se folosește primul medicament demo.")
        if candidate is None:
            missing = [m["id"] for m in DEMO["meds"] if m["id"] not in present]
            candidate = copy.deepcopy(ALL_MEDS[missing[0] if missing else "med_01"])
            if not missing:
                warnings.append("Toate cutiile demo sunt deja în listă; acesta ar fi un duplicat.")
    if candidate and candidate["product"]["expiry"] and candidate["product"]["expiry"] < date.today().isoformat():
        warnings.append("Cutia pare expirată.")
    return {"candidates": [candidate] if candidate else [], "warnings": warnings, "raw_text": raw_text}


@app.get("/v1/patients/{pid}/meds")
def list_meds(pid: str, x_patient_token: str | None = Header(None)) -> list[dict[str, Any]]:
    auth(pid, x_patient_token)
    return list(state.meds[pid].values())


@app.post("/v1/patients/{pid}/meds", status_code=201)
def add_med(pid: str, body: dict[str, Any], x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    auth(pid, x_patient_token)
    if not isinstance(body.get("id"), str) or not isinstance(body.get("product"), dict):
        raise HTTPException(422, "Corpul nu e un MedicationItem.")
    before = {a["id"] for a in analysis_alerts(pid)}
    med = copy.deepcopy(body)
    if med["id"] in state.meds[pid]:
        med["id"] = state.next_id("med_x")
    state.meds[pid][med["id"]] = med
    emit_new_alerts(pid, before)
    return med


@app.patch("/v1/patients/{pid}/meds/{mid}")
def update_med(pid: str, mid: str, body: dict[str, Any], x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    auth(pid, x_patient_token)
    if mid not in state.meds[pid]:
        raise HTTPException(404, "Medicamentul nu există.")
    state.meds[pid][mid].update({k: v for k, v in body.items() if k != "id"})
    return state.meds[pid][mid]


@app.delete("/v1/patients/{pid}/meds/{mid}", status_code=204)
def delete_med(pid: str, mid: str, x_patient_token: str | None = Header(None)) -> Response:
    auth(pid, x_patient_token)
    if state.meds[pid].pop(mid, None) is None:
        raise HTTPException(404, "Medicamentul nu există.")
    return Response(status_code=204)


# ---------------------------------------------------------------- analiză


@app.get("/v1/patients/{pid}/analysis")
def analysis(pid: str, x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    auth(pid, x_patient_token)
    alerts = analysis_alerts(pid)
    return {"alerts": alerts, "acb_total": acb_total(pid), "graph": build_graph(pid, alerts), "analyzed_at": iso(now())}


@app.post("/v1/patients/{pid}/what-if")
def what_if(pid: str, body: dict[str, Any], x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    auth(pid, x_patient_token)
    query = (body.get("query") or "").lower()
    med = body.get("med")
    is_09 = (med and any((s.get("inn") or "") == "clarithromycin" for s in med.get("substances", []))) or any(
        k in query for k in ("fromilid", "klacid", "klabax", "claritromicin")
    )
    if is_09:
        present = active_med_ids(pid) | {"med_09"}
        new = [a for a in EXPECTED["added_with_med_09"] if set(a["med_ids"]) <= present]
        return {"matched": med or copy.deepcopy(MED_09), "new_alerts": new}
    match = next((k for k in KB_EXTRA if k["brand"].lower() in query), None)
    if match:
        matched = copy.deepcopy(ALL_MEDS["med_02"])
        matched.update({"id": "med_whatif", "source": "voice", "substances": match["substances"]})
        matched["product"].update({"brand": match["brand"], "strength_text": match["strength_text"], "form": match["form"]})
        return {"matched": matched, "new_alerts": []}
    return {"matched": med, "new_alerts": []}


# ---------------------------------------------------------------- ziua


@app.get("/v1/patients/{pid}/schedule")
def schedule(pid: str, request: Request, x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    patient = auth(pid, x_patient_token)
    day = request.query_params.get("date")
    present = active_med_ids(pid)
    out = copy.deepcopy(SCHEDULE)
    out["date"] = day or date.today().isoformat()
    out["anchors"] = patient["anchors"]
    moments = []
    for mo in out["moments"]:
        mo["doses"] = [d for d in mo["doses"] if d["med_id"] in present]
        if mo["doses"]:
            moments.append(mo)
    out["moments"] = moments
    out["solver"]["moments_count"] = len(moments)
    return out


@app.post("/v1/patients/{pid}/doses")
def record_dose(pid: str, body: dict[str, Any], x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    auth(pid, x_patient_token)
    if body.get("status") not in ("taken", "skipped", "pending") or not body.get("med_id") or not body.get("scheduled_at"):
        raise HTTPException(422, "Doză invalidă.")
    dose = {
        "med_id": body["med_id"],
        "scheduled_at": body["scheduled_at"],
        "status": body["status"],
        "recorded_at": iso(now()),
    }
    state.doses[pid][(dose["med_id"], dose["scheduled_at"])] = dose
    return dose


@app.post("/v1/patients/{pid}/checkins", status_code=201)
async def checkin(pid: str, request: Request, x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    patient = auth(pid, x_patient_token)
    if request.headers.get("content-type", "").startswith("multipart/"):
        text = CHECKIN["transcript"]
    else:
        body = await request.json()
        text = (body or {}).get("text", "").strip()
        if not text:
            raise HTTPException(422, "Lipsește textul.")
    ci = copy.deepcopy(CHECKIN)
    ci.update({"id": state.next_id("ci"), "at": iso(now()), "transcript": text})
    if patient.get("caregiver_name") != "Ana":
        ci["reply_text"] = ci["reply_text"].replace("Anei", "aparținătorului")
    if ci["escalate"]:
        labels = ", ".join(s["label"] for s in ci["symptoms"])
        push_event(
            pid,
            "checkin",
            f"{patient['name']} a raportat: {labels}",
            "Posibil legat de Sintrom + Nurofen (alerta de sângerare deja găsită).",
            severity="major",
            med_ids=["med_01", "med_02"],
            checkin_id=ci["id"],
        )
    return ci


@app.get("/v1/patients/{pid}/feed")
def feed(pid: str, since: str | None = None, x_patient_token: str | None = Header(None)) -> list[dict[str, Any]]:
    auth(pid, x_patient_token)
    events = state.feed[pid]
    if since:
        try:
            cut = datetime.fromisoformat(since.replace("Z", "+00:00"))
        except ValueError:
            raise HTTPException(422, "since nu e o dată ISO 8601.") from None
        events = [e for e in events if datetime.fromisoformat(e["at"].replace("Z", "+00:00")) > cut]
    return list(reversed(events))


# ---------------------------------------------------------------- partajare


@app.post("/v1/patients/{pid}/share", status_code=201)
def share(pid: str, request: Request, x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    auth(pid, x_patient_token)
    token = secrets.token_urlsafe(16)
    expires = now() + timedelta(hours=72)
    state.shares[token] = (pid, expires)
    base = str(request.base_url).rstrip("/")
    return {"share_token": token, "url": f"{base}/share/{token}", "expires_at": iso(expires)}


def share_pid(token: str) -> str:
    entry = state.shares.get(token)
    if not entry or entry[1] < now():
        raise HTTPException(404, "Linkul a expirat sau nu există.")
    return entry[0]


def _page(title: str, body: str) -> str:
    return (
        "<!doctype html><html lang='ro'><head><meta charset='utf-8'>"
        "<meta name='viewport' content='width=device-width,initial-scale=1'>"
        f"<title>{title}</title><style>body{{font:100%/1.5 system-ui;margin:1.5rem;max-width:48rem}}"
        "h1{letter-spacing:-0.02em;line-height:1.1}.sev{font-weight:600}</style></head>"
        f"<body><p><em>Mock P0.</em></p>{body}</body></html>"
    )


@app.get("/share/{token}", response_class=HTMLResponse)
def share_page(token: str) -> str:
    share_pid(token)
    return _page(
        "Portalul medicului",
        "<h1>Portalul medicului de familie</h1><p>În backend-ul real (make dev), linkul îl adaugă pe pacient în lista "
        "medicului din /portal. Mock-ul nu are portal.</p>",
    )


@app.get("/share/{token}/graph", response_class=HTMLResponse)
def share_graph(token: str, embed: int = 0) -> str:
    pid = share_pid(token)
    g = build_graph(pid, analysis_alerts(pid))
    items = "".join(
        "<li><a href='#' onclick=\"window.webkit&&window.webkit.messageHandlers.alert"
        f".postMessage('{e['data']['alert_id']}');return false\">"
        f"{e['data']['source']} ↔ {e['data']['target']} ({e['data']['severity']})</a></li>"
        for e in g["edges"]
        if e["data"]["type"] == "interacts"
    )
    return _page("Graf", f"<h1>Graf (mock)</h1><p>{len(g['nodes'])} noduri, {len(g['edges'])} muchii.</p><ul>{items}</ul>")


# ---------------------------------------------------------------- kb


@app.get("/v1/kb/search")
def kb_search(q: str, x_patient_token: str | None = Header(None)) -> dict[str, Any]:
    if not x_patient_token or x_patient_token not in state.tokens:
        raise HTTPException(401, "Lipsește sau e greșit X-Patient-Token.")
    ql = q.lower()
    pool = [
        {
            "brand": m["product"]["brand"],
            "strength_text": m["product"]["strength_text"],
            "form": m["product"]["form"],
            "substances": m["substances"],
        }
        for m in ALL_MEDS.values()
    ] + KB_EXTRA
    hits = [
        r
        for r in pool
        if ql in r["brand"].lower() or any(ql in (s["inn"] or "") or ql in (s["dci"] or "").lower() for s in r["substances"])
    ]
    return {"results": hits[:20]}


# ---------------------------------------------------------------- demo


@app.post("/demo/reset")
def demo_reset(live_scan: int = 0) -> dict[str, Any]:
    state.reset_demo(live_scan=bool(live_scan))
    return {"id": "pat_demo", "patient_token": "demo-token", "patient": state.patients["pat_demo"]}


@app.post("/demo/missed-dose")
def demo_missed_dose() -> dict[str, Any]:
    pid = "pat_demo"
    name = state.patients[pid]["name"]
    return push_event(
        pid,
        "dose_missed",
        f"{name} n-a confirmat dozele de la 13:00",
        "Calcium + Vitamin D, la prânz.",
        severity="info",
        med_ids=["med_06"],
    )


@app.exception_handler(HTTPException)
async def http_error(_: Request, exc: HTTPException) -> JSONResponse:
    return JSONResponse({"detail": exc.detail}, status_code=exc.status_code)
