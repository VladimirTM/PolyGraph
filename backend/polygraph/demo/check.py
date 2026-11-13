"""`make demo-check` (R4): scenariul demo din docs/PLAN.md, secțiunea 7, rulat prin API și comparat cu contracts/fixtures.

Două moduri:
- implicit, în proces: backend-ul real cu o bază de date temporară, DEMO_MODE=1, data din fixture și Gemini oprit
  (dovada că drumul critic nu are nevoie de internet);
- `--url http://IP:8000`: serverul pornit cu `make demo`, exact cel la care se conectează telefoanele
  (`make demo-check URL=http://127.0.0.1:8000`). La final, pacientul demo e resetat pentru scanarea live.

Ieșirea e 0 doar dacă toți pașii trec.
"""

from __future__ import annotations

import argparse
import copy
import html
import json
import os
import sys
import tempfile
import time
import warnings
from collections.abc import Callable
from datetime import date, timedelta
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[3]
FIX = ROOT / "contracts" / "fixtures"
OCR = ROOT / "demo" / "ocr"
sys.path.insert(0, str(ROOT / "contracts"))

import validate as contracts  # noqa: E402

Json = dict[str, Any]
P = "/v1/patients/pat_demo"
H = {"X-Patient-Token": "demo-token"}
DEMO = json.loads((FIX / "demo_patient.json").read_text(encoding="utf-8"))
EXPECTED = json.loads((FIX / "expected_alerts.json").read_text(encoding="utf-8"))
SCHEDULE = json.loads((FIX / "expected_schedule.json").read_text(encoding="utf-8"))
CHECKIN = json.loads((FIX / "checkin_demo.json").read_text(encoding="utf-8"))
MED_09 = json.loads((FIX / "med_09_fromilid.json").read_text(encoding="utf-8"))
FIXTURE_MEDS = {m["id"]: m for m in DEMO["meds"]}


class Failed(AssertionError):
    pass


def need(condition: Any, message: str) -> None:
    if not condition:
        raise Failed(message)


def key(a: Json) -> tuple:
    return (a["kind"], a["severity"], tuple(sorted(a["med_ids"])), a["basis"])


def valid(schema: str, body: Any) -> Any:
    errors = contracts.schema_errors(schema, body)
    need(not errors, f"{schema} nu respectă contractul: {errors[:3]}")
    return body


class Scenario:
    def __init__(self, client, code: str):
        self.c = client
        self.code = code
        self.day: date | None = None

    # ------------------------------------------------------------ ajutoare HTTP

    def get(self, path: str, status: int = 200, **kw) -> Any:
        r = self.c.get(path, **kw)
        need(r.status_code == status, f"GET {path} → {r.status_code}: {r.text[:200]}")
        return r

    def post(self, path: str, status: int = 200, **kw) -> Any:
        r = self.c.post(path, **kw)
        need(r.status_code == status, f"POST {path} → {r.status_code}: {r.text[:200]}")
        return r

    def scan(self, name: str) -> Json:
        raw = json.loads((OCR / f"{name}.json").read_text(encoding="utf-8"))
        data = {"kind": raw["kind"], "ocr_lines": json.dumps(raw["ocr_lines"])}
        if raw.get("datamatrix"):
            data["datamatrix"] = raw["datamatrix"]
        result = valid("extraction", self.post(f"{P}/scan", headers=H, data=data).json())
        need(result["candidates"], f"{name}: niciun candidat ({result['warnings']})")
        return result

    def confirm(self, fixture_med: Json, candidate: Json) -> None:
        """Ce face sheet-ul de confirmare: produsul citit (cod, expirare) peste medicamentul pacientului demo."""
        med = copy.deepcopy(fixture_med)
        for field in ("gtin", "expiry", "batch"):
            med["product"][field] = candidate["product"][field]
        self.post(f"{P}/meds", 201, headers=H, json=valid("medication_item", med))

    def analysis(self) -> Json:
        return valid("analysis", self.get(f"{P}/analysis", headers=H).json())

    def feed(self) -> list[Json]:
        events = self.get(f"{P}/feed", headers=H).json()
        for e in events:
            valid("feed_event", e)
        return events

    def alerts_match(self, want: list[Json]) -> Json:
        result = self.analysis()
        got, expected = sorted(key(a) for a in result["alerts"]), sorted(key(a) for a in want)
        missing = [k for k in expected if k not in got]
        extra = [k for k in got if k not in expected]
        need(not missing and not extra, f"alertele diferă de expected_alerts.json: lipsesc {missing}, în plus {extra}")
        return result

    # ------------------------------------------------------------ pașii, în ordinea din secțiunea 7

    def health(self) -> str:
        body = self.get("/health").json()
        need(body.get("ok") and body.get("mode") == "backend", f"/health: {body}")
        return "backend real"

    def reset(self) -> str:
        body = valid("patient_created", self.post("/demo/reset", params={"live_scan": 1}).json())
        need(body["id"] == "pat_demo", "reset: alt pacient")
        meds = self.get(f"{P}/meds", headers=H).json()
        need(len(meds) == 6, f"după reset cu live_scan trebuie 6 medicamente, sunt {len(meds)}")
        self.day = date.fromisoformat(self.get(f"{P}/schedule", headers=H).json()["date"])
        missed = [e for e in self.feed() if e["type"] == "dose_missed"]
        need(len(missed) == 2, f"istoricul demo trebuie să aibă 2 doze ratate, are {len(missed)}")
        return f"6 medicamente, istoric pe 7 zile, azi = {self.day:%d.%m.%Y}"

    def scan_boxes(self) -> str:
        sintrom = self.scan("sintrom_box_fara_cod")["candidates"][0]
        need("B01AA07" in {s["atc"] for s in sintrom["substances"]}, f"Sintrom: ATC greșit {sintrom['substances']}")
        self.confirm(FIXTURE_MEDS["med_01"], sintrom)
        nurofen = self.scan("nurofen_box")["candidates"][0]
        need("M01AE01" in {s["atc"] for s in nurofen["substances"]}, f"Nurofen: ATC greșit {nurofen['substances']}")
        need(nurofen["product"]["expiry"] == "2027-09-30", f"Nurofen: expirarea din DataMatrix {nurofen['product']}")
        self.confirm(FIXTURE_MEDS["med_02"], nurofen)
        raw = json.loads((OCR / "nurofen_box.json").read_text(encoding="utf-8"))
        again = self.post(f"{P}/scan", headers=H, data={"kind": "box", "datamatrix": raw["datamatrix"]}).json()
        need(
            again["candidates"] and again["candidates"][0]["match"]["method"] == "gtin_cache", "a doua scanare nu vine din cache"
        )
        return "Sintrom (OCR) + Nurofen (DataMatrix + OCR) confirmate; a doua scanare din cache-ul GTIN"

    def alerts_and_graph(self) -> str:
        result = self.alerts_match(EXPECTED["without_med_09"])
        need(result["acb_total"] == 3, f"ACB {result['acb_total']} în loc de 3")
        valid("graph", result["graph"])
        need("al_ddi_med_01_med_02" in json.dumps(result["graph"]), "graful nu are muchia Sintrom – Nurofen")
        grave = [e for e in self.feed() if e["type"] == "alert_new" and e["alert_id"] == "al_ddi_med_01_med_02"]
        need(grave, "Noutățile n-au alerta nouă Sintrom + Nurofen")
        return f"{len(result['alerts'])} alerte = expected_alerts.json, ACB 3, muchia Sintrom – Nurofen în graf"

    def schedule(self) -> str:
        body = valid("schedule", self.get(f"{P}/schedule", headers=H).json())

        def shape(s: Json) -> list:
            return [(m["time"], sorted(d["med_id"] for d in m["doses"])) for m in s["moments"]]

        need(shape(body) == shape(SCHEDULE), f"programul diferă de expected_schedule.json: {shape(body)}")
        first = body["moments"][0]
        dose = {"med_id": first["doses"][0]["med_id"], "scheduled_at": f"{body['date']}T{first['time']}:00+02:00"}
        for _ in range(2):  # idempotent
            valid("dose", self.post(f"{P}/doses", headers=H, json={**dose, "status": "taken"}).json())
        return f"{len(body['moments'])} momente = expected_schedule.json; „Am luat” salvat (idempotent)"

    def checkin(self) -> str:
        started = time.perf_counter()
        ci = valid("checkin", self.post(f"{P}/checkins", 201, headers=H, json={"text": CHECKIN["transcript"]}).json())
        elapsed = time.perf_counter() - started
        need([s["code"] for s in ci["symptoms"]] == [s["code"] for s in CHECKIN["symptoms"]], f"simptome: {ci['symptoms']}")
        need(ci["correlations"] == CHECKIN["correlations"], f"corelări: {ci['correlations']}")
        need(ci["escalate"] is True, "check-in-ul demo trebuie escaladat")
        need(elapsed < 4, f"check-in în {elapsed:.1f} s (limita 4 s)")
        event = next((e for e in self.feed() if e["checkin_id"] == ci["id"]), None)
        need(event and "Sintrom + Nurofen" in event["body"], f"Noutățile pentru Ana: {event}")
        return "amețeală + vânătăi → Sintrom + Nurofen, escaladat; apare în Noutăți"

    def new_doctor(self) -> str:
        fromilid = self.scan("fromilid_prescription")["candidates"]
        rx = next((c for c in fromilid if "J01FA09" in {s["atc"] for s in c["substances"]}), None)
        need(rx, f"rețeta ORL: claritromicina lipsește din {[c['product']['brand'] for c in fromilid]}")
        need(rx["dosage"]["pattern"] == MED_09["dosage"]["pattern"], f"posologia rețetei: {rx['dosage']['pattern']}")
        med = copy.deepcopy(MED_09)
        # tratamentul de 7 zile începe azi, oricare ar fi ziua demo-ului
        med["start_date"], med["end_date"] = self.day.isoformat(), (self.day + timedelta(days=6)).isoformat()
        self.post(f"{P}/meds", 201, headers=H, json=valid("medication_item", med))
        result = self.alerts_match(EXPECTED["without_med_09"] + EXPECTED["added_with_med_09"])
        critical = [a["id"] for a in result["alerts"] if a["severity"] == "critical"]
        need(critical == ["al_ddi_med_03_med_09"], f"alerta critică: {critical}")
        new = {e["alert_id"] for e in self.feed() if e["type"] == "alert_new"}
        need({"al_ddi_med_03_med_09", "al_ddi_med_01_med_09"} <= new, f"Noutățile n-au alertele noi: {new}")
        return "Fromilid 1-0-1 → critică simvastatină + claritromicină, gravă Sintrom + claritromicină"

    def portal(self) -> str:
        r = self.c.post("/portal/login", data={"code": self.code, "next": "/portal"})
        need(r.status_code == 303, f"autentificarea în portal → {r.status_code} (codul e PG_DOCTOR_CODE?)")
        page = self.get("/portal").text
        order = [page.find(f'/portal/patients/{pid}"') for pid in ("pat_demo", "pat_demo_ion", "pat_demo_ana")]
        need(-1 not in order and order == sorted(order), "Maria nu e prima în lista medicului")
        self.get(f"{P.replace('/v1', '/portal')}")
        note = "Discut la consultație înlocuirea Nurofen-ului."
        review = {"decision": "change_at_visit", "note": note}
        self.post("/portal/patients/pat_demo/alerts/al_ddi_med_01_med_02/review", json=review)
        alert = next(a for a in self.analysis()["alerts"] if a["id"] == "al_ddi_med_01_med_02")
        need(alert["status"] == "reviewed_by_doctor" and alert["resolution"]["note"] == note, f"decizia: {alert}")
        need(any(e["type"] == "doctor_reviewed" for e in self.feed()), "decizia nu a ajuns în Noutăți")
        return "Maria prima în listă; „Modific la consultație” + notă → alertă și Noutăți"

    def print_sheet(self) -> str:
        page = self.get("/portal/patients/pat_demo/print").text
        grave = [a for a in self.analysis()["alerts"] if a["severity"] in ("critical", "major")]
        absent = [a["title"] for a in grave if html.escape(a["title"]) not in page and a["title"] not in page]
        need(not absent, f"lipsesc de pe fișa de tipărit: {absent}")
        return f"reconcilierea are toate cele {len(grave)} alerte grave"

    def missed_dose(self) -> str:
        event = valid("feed_event", self.post("/demo/missed-dose").json())
        need(event["type"] == "dose_missed", f"doza ratată: {event}")
        need(any(e["id"] == event["id"] for e in self.feed()), "doza ratată nu e în Noutăți")
        return event["title"]

    def cleanup(self) -> str:
        self.post("/demo/reset", params={"live_scan": 1})
        return "pacientul demo e gata pentru scanarea live (Sintrom și Nurofen lipsesc)"


STEPS: list[tuple[str, str, Callable[[Scenario], str]]] = [
    ("–", "Serverul răspunde", Scenario.health),
    ("–", "Reset demo (live_scan)", Scenario.reset),
    ("0:15", "Ana scanează 2 cutii", Scenario.scan_boxes),
    ("0:45", "Alertele și graful", Scenario.alerts_and_graph),
    ("1:15", "Programul și „Am luat”", Scenario.schedule),
    ("1:40", "Check-in-ul vocal", Scenario.checkin),
    ("2:10", "Medic nou: rețeta ORL", Scenario.new_doctor),
    ("2:30", "Portalul medicului de familie", Scenario.portal),
    ("2:50", "Reconcilierea de tipărit", Scenario.print_sheet),
    ("plan B", "Doză ratată (modul demo)", Scenario.missed_dose),
    ("–", "Reset pentru scenă", Scenario.cleanup),
]


def run(client, code: str, out=print) -> bool:
    scenario = Scenario(client, code)
    ok = True
    total = time.perf_counter()
    for moment, title, step in STEPS:
        started = time.perf_counter()
        try:
            detail = step(scenario)
            mark = "✓"
        except Failed as exc:
            detail, mark, ok = str(exc), "✗", False
        except Exception as exc:  # noqa: BLE001  (conexiune refuzată, JSON stricat: tot un pas picat)
            detail, mark, ok = f"{type(exc).__name__}: {exc}", "✗", False
        ms = (time.perf_counter() - started) * 1000
        out(f"  {mark} {moment:>6}  {title:<32} {ms:6.0f} ms  {detail}")
        if not ok and step in (Scenario.health, Scenario.reset):
            break
    out(f"\n{'VERDE' if ok else 'ROȘU'}: scenariul demo în {time.perf_counter() - total:.1f} s")
    return ok


def in_process(code: str) -> bool:
    os.environ.update(DEMO_MODE="1", PG_TODAY=EXPECTED["today"], GEMINI_API_KEY="")
    with tempfile.TemporaryDirectory() as tmp:
        os.environ["PG_MEDIA_DIR"] = str(Path(tmp) / "media")
        with warnings.catch_warnings():
            # avertismentul Starlette despre httpx nu ține de scenariu și ar ascunde rezultatul
            warnings.simplefilter("ignore")
            from fastapi.testclient import TestClient

        from polygraph.api import main
        from polygraph.store import Store

        main.configure(Store(Path(tmp) / "app.sqlite"))
        with TestClient(main.app, follow_redirects=False) as client:
            return run(client, code)


def live(url: str, code: str) -> bool:
    import httpx

    with httpx.Client(base_url=url.rstrip("/"), timeout=15, follow_redirects=False) as client:
        return run(client, code)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--url", help="serverul pornit cu `make demo`; implicit, backend-ul în proces")
    parser.add_argument("--code", default=os.environ.get("PG_DOCTOR_CODE") or "medic-demo", help="codul medicului demo")
    args = parser.parse_args()
    print(f"Scenariul demo (secțiunea 7) · {'server ' + args.url if args.url else 'în proces, fără Gemini'}\n")
    sys.exit(0 if (live(args.url, args.code) if args.url else in_process(args.code)) else 1)


if __name__ == "__main__":
    main()
