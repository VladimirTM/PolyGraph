import json
import unicodedata
from contextlib import nullcontext
from hashlib import sha256
from io import BytesIO
from pathlib import Path
from time import perf_counter
from urllib.error import HTTPError

import pytest
import validate as contracts
import zxingcpp
from engine_helpers import real_kb
from fastapi.testclient import TestClient
from PIL import Image

from polygraph.api import main
from polygraph.extract import gemini, match
from polygraph.extract.gs1 import parse_gs1
from polygraph.extract.posology import parse_posology
from polygraph.store import Store

ROOT = Path(__file__).resolve().parents[2]
CASES = json.loads((ROOT / "contracts/fixtures/gs1_cases.json").read_text())["cases"]
HEADERS = {"X-Patient-Token": "demo-token"}
SCAN = "/v1/patients/pat_demo/scan"
MEDS = "/v1/patients/pat_demo/meds"


@pytest.fixture(scope="module")
def kb():
    return real_kb()


@pytest.fixture
def client(kb, tmp_path, monkeypatch):
    monkeypatch.setenv("PG_MEDIA_DIR", str(tmp_path / "media"))
    main.configure(Store(":memory:"), kb)
    main.reset_demo()
    with TestClient(main.app) as client:
        yield client
    main.configure()


def post_scan(client, *lines, kind="box", code=None, picture=None):
    data = {"kind": kind, "ocr_lines": json.dumps([{"text": line, "height": 0.2} for line in lines])}
    if code:
        data["datamatrix"] = code
    response = client.post(
        SCAN, headers=HEADERS, data=data, files={"image": ("test.png", picture, "image/png")} if picture else None
    )
    assert response.status_code == 200, response.text
    result = response.json()
    assert not contracts.schema_errors("extraction", result)
    return result


@pytest.mark.parametrize(
    ("raw", "pattern", "food", "prn", "review"),
    [
        ("1-0-1", (1, 0, 1, 0), "any", False, False),
        ("1-1-1", (1, 1, 1, 0), "any", False, False),
        ("0-0-1", (0, 0, 1, 0), "any", False, False),
        ("0-0-0-1", (0, 0, 0, 1), "any", False, False),
        ("D.S.: 1/2 - 0 - 1", (0.5, 0, 1, 0), "any", False, False),
        ("1/2 seara", (0, 0, 0.5, 0), "any", False, False),
        ("½ cp seara", (0, 0, 0.5, 0), "any", False, False),
        ("1 cp/zi dimineața", (1, 0, 0, 0), "any", False, False),
        ("Dimineața 1 capsulă", (1, 0, 0, 0), "any", False, False),
        ("2 cp la culcare", (0, 0, 0, 2), "any", False, False),
        ("0,5 cp la prânz", (0, 0.5, 0, 0), "any", False, False),
        ("1 cp dimineața și 1 cp seara", (1, 0, 1, 0), "any", False, False),
        ("1 cp dimineața pe stomacul gol", (1, 0, 0, 0), "empty_stomach", False, False),
        ("1-0-1 înainte de masă", (1, 0, 1, 0), "before_meal", False, False),
        ("1 comprimat seara în timpul mesei", (0, 0, 1, 0), "with_meal", False, False),
        ("1-1-1 după mese", (1, 1, 1, 0), "after_meal", False, False),
        ("1 comprimat la nevoie", (0, 0, 0, 0), "any", True, False),
        ("De 2 ori pe zi", (0, 0, 0, 0), "any", False, True),
        ("1 cp/zi", (0, 0, 0, 0), "any", False, True),
        ("Conform indicațiilor", (0, 0, 0, 0), "any", False, True),
    ],
)
def test_posology(raw, pattern, food, prn, review):
    dosage, needs_review = parse_posology(raw)
    assert tuple(dosage["pattern"].values()) == pattern
    assert dosage["with_food"] == food
    assert dosage["as_needed"] == prn
    assert needs_review == review


@pytest.mark.parametrize("case", CASES, ids=[case["name"] for case in CASES])
def test_gs1(case):
    if case["expected"]:
        assert parse_gs1(case["raw"]) == case["expected"]
    else:
        with pytest.raises(ValueError, match=case["error"]):
            parse_gs1(case["raw"])


@pytest.mark.parametrize(
    ("ocr", "atc"),
    [
        ("Sintrom 4 mg", "B01AA07"),
        ("Nurofen Forte 400 mg", "M01AE01"),
        ("Simvastatină Arena 40 mg", "C10AA01"),
        ("Amlodipină Arena 10 mg", "C08CA01"),
        ("Euthyrox 75 mcg", "H03AA01"),
        ("Calciu + Vitamina D3", "A12AA04"),
        ("Omeprazol Zentiva 20 mg", "A02BC01"),
        ("Amitriptilină Arena 25 mg", "N06AA09"),
    ],
)
def test_demo_box_transcriptions(client, ocr, atc, caplog, monkeypatch):
    caplog.set_level("INFO")
    monkeypatch.setattr(match, "extract_image", lambda *_: pytest.fail("Scanarea deterministă a apelat Gemini"))
    started = perf_counter()
    result = post_scan(client, ocr)
    assert perf_counter() - started < 3
    assert atc in {s["atc"] for s in result["candidates"][0]["substances"]}
    assert "route=ocr_match" in caplog.text


def test_demo_prescription(client):
    result = post_scan(
        client,
        "REȚETĂ MEDICALĂ",
        "Medic prescriptor",
        "Dr. Ionescu Andrei",
        "Medic specialist ORL (otorinolaringologie)",
        "Rp./",
        "Fromilid 500 mg comprimate filmate",
        "DCI: Claritromicină",
        "Cantitate: 1 cutie x 14 comprimate",
        "D.S.: 1 comprimat dimineața și 1 comprimat seara",
        "(1-0-1), timp de 7 zile",
        "După mese, cu un pahar cu apă.",
        "Data prescrierii: 14.11.2026",
        kind="prescription",
    )
    (candidate,) = result["candidates"]
    assert candidate["substances"][0]["atc"] == "J01FA09"
    assert candidate["prescriber"] == {"name": "Ionescu Andrei", "specialty": "ORL"}
    assert list(candidate["dosage"]["pattern"].values()) == [1, 0, 1, 0]
    assert candidate["dosage"]["with_food"] == "after_meal"
    assert candidate["product"]["pack_size"] == 14


@pytest.mark.parametrize(
    ("clean", "noisy"),
    [
        ("Sintrom 4 mg", "SlNTR0M® 4mg"),
        ("Fromilid 500 mg", "FR0M1L1D 500mg"),
        ("Algocalmin 500 mg", "ALG0CALMlN 500mg"),
        ("Euthyrox 75 mcg", "EUTHYR0X 75mcg"),
        ("Nurofen 400 mg", "NUR0FEN 400mg"),
        ("Simvastatină Arena 40 mg", "SIMVASTATlNA ARENA 40mg"),
        ("Amlodipină Arena 10 mg", "AML0DIPINA ARENA 10mg"),
        ("Omeprazol Zentiva 20 mg", "0MEPRAZ0L ZENTIVA 20mg"),
        ("Amitriptilină Arena 25 mg", "AMITRIPTILINA ARENA 25mg"),
        ("Calciu + Vitamina D3", "CALCIU + VlTAMINA D3"),
    ],
)
def test_ocr_noise(client, clean, noisy):
    expected = post_scan(client, clean)["candidates"][0]
    actual = post_scan(client, noisy)["candidates"][0]
    assert actual["product"] == expected["product"]
    assert actual["substances"] == expected["substances"]


@pytest.mark.parametrize("unit", ["µg", "mcg", "ug"])
def test_strength_unit_aliases(client, unit):
    (candidate,) = post_scan(client, f"Euthyrox 100 {unit}")["candidates"]
    assert candidate["substances"][0]["strength_mg"] == 0.1


def test_generic_manufacturer(client, monkeypatch):
    monkeypatch.setattr(match, "extract_image", lambda *_: [match.RawExtraction("Actavis", "10 mg", dci_text="Amlodipină")])
    (candidate,) = post_scan(client, picture=b"fixture")["candidates"]
    assert "amlodipin" in candidate["product"]["brand"].lower()
    assert candidate["substances"][0]["atc"] == "C08CA01"
    assert candidate["match"]["needs_review"]


@pytest.mark.parametrize("raw", [match.RawExtraction(), match.RawExtraction(brand="Zezouxan", strength_text="4 mg")])
def test_unknown_and_null_fields(client, monkeypatch, raw):
    monkeypatch.setattr(match, "extract_image", lambda *_: [raw])
    result = post_scan(client, "Zezouxan 4 mg", picture=b"fixture")
    assert result["candidates"] == []
    assert match.MANUAL in result["warnings"]


def test_gtin_is_learned_on_confirmation_and_image_fallback(client):
    raw = CASES[0]["raw"].removeprefix("]d2")
    barcode = zxingcpp.create_barcode(raw, zxingcpp.BarcodeFormat.DataMatrix)
    pixels = zxingcpp.write_barcode_to_image(barcode, scale=5)
    out = BytesIO()
    Image.frombytes("L", tuple(reversed(pixels.shape)), bytes(memoryview(pixels))).save(out, format="PNG")
    picture = out.getvalue()

    assert not post_scan(client, picture=picture)["candidates"]
    (first,) = post_scan(client, "Sintrom 4 mg", picture=picture)["candidates"]
    assert first["product"]["gtin"] == CASES[0]["expected"]["gtin"]
    assert first["match"]["method"] == "exact_brand"
    assert first["product"]["brand"] == "Sintrom"
    assert first["product"]["strength_text"] == "4 mg"
    assert not post_scan(client, code=raw)["candidates"]
    assert client.post(MEDS, headers=HEADERS, json=first).status_code == 201

    (cached,) = post_scan(client, picture=picture)["candidates"]
    assert cached["match"]["method"] == "gtin_cache"
    assert cached["product"]["batch"] == "AB123"
    assert cached["dosage"]["raw"] is None
    assert cached["prescriber"]["name"] is None


def test_gemini_cache_and_timeout(tmp_path, monkeypatch):
    monkeypatch.setattr(gemini, "CACHE", tmp_path)
    monkeypatch.setenv("GEMINI_API_KEY", "test")
    raw = match.RawExtraction(brand="Sintrom", strength_text="4 mg")
    data = gemini.ADAPTER.dump_json([raw]).decode()
    envelope = {"candidates": [{"content": {"parts": [{"text": data}]}}]}
    monkeypatch.setattr(gemini, "urlopen", lambda *_, timeout: nullcontext(BytesIO(json.dumps(envelope).encode())))
    assert gemini.extract_image(b"image", "box") == [raw]
    monkeypatch.setenv("GEMINI_API_KEY", "")
    assert gemini.extract_image(b"image", "box") == [raw]
    monkeypatch.setenv("GEMINI_API_KEY", "test")

    def fail(*_, timeout):
        assert timeout == 8
        raise TimeoutError

    monkeypatch.setattr(gemini, "urlopen", fail)
    assert gemini.extract_image(b"other image", "box") == []


def test_gemini_empty_answer_is_not_cached(tmp_path, monkeypatch):
    monkeypatch.setattr(gemini, "CACHE", tmp_path)
    monkeypatch.setenv("GEMINI_API_KEY", "test")
    raw = match.RawExtraction(brand="Sintrom", strength_text="4 mg")
    answers = iter([[], [raw]])

    def reply(*_, timeout):
        data = gemini.ADAPTER.dump_json(next(answers)).decode()
        envelope = {"candidates": [{"content": {"parts": [{"text": data}]}}]}
        return nullcontext(BytesIO(json.dumps(envelope).encode()))

    monkeypatch.setattr(gemini, "urlopen", reply)
    assert gemini.extract_image(b"image", "box") == []
    assert not list(tmp_path.iterdir())
    assert gemini.extract_image(b"image", "box") == [raw]
    assert len(list(tmp_path.iterdir())) == 1


def test_gemini_does_not_retry(tmp_path, monkeypatch):
    monkeypatch.setattr(gemini, "CACHE", tmp_path)
    monkeypatch.setenv("GEMINI_API_KEY", "test")
    calls = []

    def busy(request, timeout):
        calls.append(timeout)
        raise HTTPError(request.full_url, 503, "Service Unavailable", {}, None)

    monkeypatch.setattr(gemini, "urlopen", busy)
    assert gemini.extract_image(b"image", "box") == []
    assert calls == [8]


@pytest.mark.parametrize(
    ("name", "brand", "strength", "form", "atc", "gtin", "expiry"),
    [
        ("nurofen_box", "Nurofen", "400 mg", "comprimate filmate", "M01AE01", "05949000000021", "2027-09-30"),
        ("sintrom_box_fara_cod", "Sintrom", "4 mg", "comprimate", "B01AA07", None, None),
        ("sintrom_expirat_box", "Sintrom", "4 mg", "comprimate", "B01AA07", "05949000000014", "2024-01-31"),
        ("fromilid_prescription", "Fromilid", "500 mg", "comprimate filmate", "J01FA09", None, None),
    ],
)
def test_iphone_ocr(client, caplog, monkeypatch, name, brand, strength, form, atc, gtin, expiry):
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    monkeypatch.setattr(match, "extract_image", lambda *_: pytest.fail("Scanarea OCR a apelat Gemini"))
    caplog.set_level("INFO")
    capture = json.loads((ROOT / "demo/ocr" / f"{name}.json").read_text())
    data = {**capture, "ocr_lines": json.dumps(capture["ocr_lines"])}
    response = client.post(SCAN, headers=HEADERS, data=data)
    assert response.status_code == 200, response.text
    result = response.json()
    assert not contracts.schema_errors("extraction", result)
    (candidate,) = result["candidates"]
    product = candidate["product"]
    assert (product["brand"], product["strength_text"], product["form"]) == (brand, strength, form)
    assert (product["gtin"], product["expiry"]) == (gtin, expiry)
    assert [sub["atc"] for sub in candidate["substances"]] == [atc]
    assert candidate["match"]["method"] == "exact_brand"
    assert candidate["match"]["needs_review"] is False
    assert candidate["photo_url"] is None
    assert "route=ocr_match" in caplog.text
    if name == "fromilid_prescription":
        assert candidate["dosage"]["pattern"] == {"morning": 1, "noon": 0, "evening": 1, "bedtime": 0}
        assert candidate["dosage"]["with_food"] == "after_meal"
        assert candidate["prescriber"]["specialty"] == "ORL"
    if name == "sintrom_box_fara_cod":
        fixture = json.loads((ROOT / "contracts/fixtures/demo_patient.json").read_text())
        sintrom = next(med["product"] for med in fixture["meds"] if med["id"] == "med_01")
        assert draft_key(product) == draft_key(sintrom) == "sintrom 4 mg"


def draft_key(product):
    name = product["brand"].strip(" \t")
    if not name:
        return ""
    text = unicodedata.normalize("NFD", f"{name} {product['strength_text'] or ''}".casefold())
    return " ".join("".join(ch for ch in text if not unicodedata.combining(ch)).split())


@pytest.mark.parametrize(
    ("raw", "error"),
    [
        ("]d20105949000000014\r\n", None),
        ("0105949000000014" + "99XYZ", "not_gs1"),
        ("010594900000001417281301", "invalid_expiry"),
    ],
)
def test_gs1_ios_extra_cases(raw, error):
    if error:
        with pytest.raises(ValueError, match=f"^{error}$"):
            parse_gs1(raw)
    else:
        assert parse_gs1(raw) == {"gtin": "05949000000014", "expiry": None, "batch": None, "serial": None}


def test_gtin_probe_miss(client, caplog):
    caplog.set_level("INFO")
    response = client.post(SCAN, headers=HEADERS, data={"kind": "box", "datamatrix": "0105949000000014"})
    assert response.status_code == 200
    assert response.json()["candidates"] == []
    assert response.json()["warnings"] == [match.MANUAL]
    assert "route=gtin_miss" in caplog.text


def test_scan_media(client, tmp_path):
    out = BytesIO()
    Image.new("RGB", (4, 4)).save(out, format="JPEG")
    picture = out.getvalue()
    url = f"/media/{sha256(picture).hexdigest()}.jpg"
    (candidate,) = post_scan(client, "Sintrom 4 mg", "Acenocumarol", picture=picture)["candidates"]
    assert candidate["photo_url"] == url
    response = client.get(url)
    assert response.status_code == 200
    assert response.headers["content-type"] == "image/jpeg"
    assert response.content == picture
    path = tmp_path / "media" / url.split("/")[-1]
    before = path.stat().st_mtime_ns
    (again,) = post_scan(client, "Sintrom 4 mg", "Acenocumarol", picture=picture)["candidates"]
    assert again["photo_url"] == url
    assert path.stat().st_mtime_ns == before
    assert list(path.parent.iterdir()) == [path]


def test_scan_rejects_large_media(client, tmp_path):
    response = client.post(
        SCAN,
        headers=HEADERS,
        data={"kind": "box"},
        files={"image": ("test.jpg", bytes(main.MAX_SCAN_IMAGE + 1), "image/jpeg")},
    )
    assert response.status_code == 413
    assert not (tmp_path / "media").exists()
