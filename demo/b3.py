"""Scenariu B3 cu intrări sintetice și backend-ul real în memorie."""

import json
from io import BytesIO

import zxingcpp
from fastapi.testclient import TestClient
from PIL import Image
from polygraph.api import main
from polygraph.kb import Kb
from polygraph.store import Store

PATIENT = "/v1/patients/pat_demo"
HEADERS = {"X-Patient-Token": "demo-token"}


def request(client, method, endpoint, *, status=200, **kwargs):
    response = client.request(method, PATIENT + endpoint, headers=HEADERS, **kwargs)
    if response.status_code != status:
        raise RuntimeError(
            f"{method} {endpoint}: {response.status_code} {response.text}"
        )
    return response.json()


def scan(client, *lines, kind="box", image=None):
    data = {
        "kind": kind,
        "ocr_lines": json.dumps([{"text": line, "height": 0.1} for line in lines]),
    }
    files = {"image": ("cod-demo.jpg", image, "image/jpeg")} if image else None
    return request(client, "POST", "/scan", data=data, files=files)


def sample_datamatrix():
    cases = json.loads((main.FIX / "gs1_cases.json").read_text())["cases"]
    case = next(case for case in cases if case["name"] == "sintrom_synthetic")
    barcode = zxingcpp.create_barcode(
        case["raw"].removeprefix("]d2"), zxingcpp.BarcodeFormat.DataMatrix
    )
    pixels = zxingcpp.write_barcode_to_image(barcode, scale=8)
    buffer = BytesIO()
    Image.frombytes("L", tuple(reversed(pixels.shape)), bytes(memoryview(pixels))).save(
        buffer, "JPEG", quality=95
    )
    return buffer.getvalue(), case["expected"]["gtin"]


def confirm(client, medication):
    return request(client, "POST", "/meds", status=201, json=medication)


def show_interaction(client, left_id, right_id, severity):
    analysis = request(client, "GET", "/analysis")
    for alert in analysis["alerts"]:
        if (
            alert["kind"] == "ddi"
            and alert["severity"] == severity
            and set(alert["med_ids"]) == {left_id, right_id}
        ):
            print(f"   Alertă {severity}: {alert['title']}")
            return
    raise RuntimeError(f"Lipsește alerta {severity} pentru {left_id} și {right_id}.")


def run():
    main.configure(Store(":memory:"), Kb())
    main.reset_demo(live_scan=True)
    image, gtin = sample_datamatrix()
    with TestClient(main.app) as client:
        print("Demo B3 · pacient fictiv, text OCR simulat, cod DataMatrix generat")
        print("1. Scanare Sintrom cu eroare OCR și cod DataMatrix în imagine")
        (sintrom,) = scan(client, "SlNTR0M®", "4 mg", image=image)["candidates"]
        if sintrom["product"]["gtin"] != gtin or sintrom["match"]["method"] != "fuzzy":
            raise RuntimeError(
                "Scanarea Sintrom nu a folosit potrivirea OCR și codul din imagine."
            )
        saved_sintrom = confirm(client, sintrom)
        print(f"   {sintrom['product']['brand']} · GTIN {gtin} · confirmat în listă")

        print("2. Rescanare doar din imagine")
        (cached,) = scan(client, image=image)["candidates"]
        if (
            cached["match"]["method"] != "gtin_cache"
            or cached["product"]["brand"] != sintrom["product"]["brand"]
        ):
            raise RuntimeError("Rescanarea nu a găsit produsul confirmat în cache.")
        print(f"   {cached['product']['brand']} · gtin_cache")

        print("3. Scanare Nurofen și analiză după confirmare")
        (nurofen,) = scan(client, "NUROFEN FORTE", "400 mg", "Ibuprofen")["candidates"]
        saved_nurofen = confirm(client, nurofen)
        show_interaction(client, saved_sintrom["id"], saved_nurofen["id"], "major")

        print("4. Scanare rețetă fictivă Fromilid și analiză după confirmare")
        (fromilid,) = scan(
            client,
            "Dr. Ionescu Andrei",
            "Medic specialist ORL",
            "Rp./ Fromilid 500 mg comprimate filmate",
            "DCI: Claritromicină",
            "D.S.: 1-0-1, după mese",
            kind="prescription",
        )["candidates"]
        dosage = fromilid["dosage"]
        pattern = dosage["pattern"]
        if (
            pattern != {"morning": 1, "noon": 0, "evening": 1, "bedtime": 0}
            or dosage["with_food"] != "after_meal"
        ):
            raise RuntimeError("Posologia rețetei demo nu a fost extrasă corect.")
        saved_fromilid = confirm(client, fromilid)
        print(
            f"   {fromilid['product']['brand']} · {pattern['morning']:g}-{pattern['noon']:g}-{pattern['evening']:g} · după mese"
        )
        show_interaction(client, "med_03", saved_fromilid["id"], "critical")

        print("5. Scanare text necunoscut")
        unknown = scan(client, "Zezouxan 4 mg")
        if unknown["candidates"] or not unknown["warnings"]:
            raise RuntimeError(
                "Scanarea necunoscută trebuia să ceară completare manuală."
            )
        print(f"   {unknown['warnings'][0]}")


if __name__ == "__main__":
    run()
