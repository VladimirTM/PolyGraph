"""Extracție vizuală opțională, cu răspunsuri structurate și cache demo."""

import base64
import hashlib
import json
import mimetypes
import os
import re
from dataclasses import fields
from pathlib import Path
from tempfile import NamedTemporaryFile
from urllib.request import Request, urlopen

from dotenv import dotenv_values
from pydantic import TypeAdapter, ValidationError

from polygraph.deadline import within
from polygraph.extract.ocr_match import RawExtraction
from polygraph.kb import ROOT

CACHE = ROOT / "demo" / "llm_cache"
# Decis la 13.11.2026 (B3): o scanare așteaptă cel mult 8 s (B7 pomenea 12 s; a rămas valoarea mai strictă).
SCAN_DEADLINE = 8.0
ADAPTER = TypeAdapter(list[RawExtraction])
SCHEMA = {
    "type": "array",
    "items": {
        "type": "object",
        "properties": {
            field.name: {"type": ["integer" if field.name == "pack_size" else "string", "null"]}
            for field in fields(RawExtraction)
        },
        "required": [field.name for field in fields(RawExtraction)],
    },
}


def extract_image(image: bytes, kind: str, mime_type: str = "image/jpeg") -> list[RawExtraction]:
    path = CACHE / (hashlib.sha256(image).hexdigest() + ".json")
    try:
        return ADAPTER.validate_json(path.read_bytes(), strict=True)
    except (OSError, ValidationError):
        pass

    config = dotenv_values(ROOT / ".env") | dotenv_values(ROOT / "backend" / ".env") | dict(os.environ)
    key = config.get("GEMINI_API_KEY")
    model = config.get("GEMINI_MODEL") or "gemini-3.1-flash-lite"
    if not key or not re.fullmatch(r"[\w.-]+", model) or not mime_type.startswith("image/"):
        return []
    prompt = (
        "Copiază doar textul vizibil. Dacă un câmp nu e vizibil, null. Nu deduce substanța din numele comercial. "
        "Returnează "
        + ("un singur obiect pentru cutie." if kind == "box" else "câte un obiect pentru fiecare medicament de pe rețetă.")
    )
    payload = {
        "contents": [
            {"parts": [{"text": prompt}, {"inlineData": {"mimeType": mime_type, "data": base64.b64encode(image).decode()}}]}
        ],
        "generationConfig": {"temperature": 0, "responseMimeType": "application/json", "responseJsonSchema": SCHEMA},
    }
    request = Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": key},
    )
    # Un singur apel, fără reîncercare: o scanare așteaptă cel mult SCAN_DEADLINE, apoi completare manuală.
    rows = within(SCAN_DEADLINE, lambda: _fetch(request), "gemini scan")
    if rows is None:
        return []

    # Un răspuns gol nu se păstrează, ca aceeași poză să poată fi trimisă din nou.
    if not rows:
        return rows
    try:
        CACHE.mkdir(parents=True, exist_ok=True)
        with NamedTemporaryFile(dir=CACHE, delete=False) as out:
            temporary = Path(out.name)
            try:
                out.write(ADAPTER.dump_json(rows))
                out.flush()
                temporary.replace(path)
            finally:
                temporary.unlink(missing_ok=True)
    except OSError:
        pass
    return rows


def _fetch(request: Request) -> list[RawExtraction]:
    with urlopen(request, timeout=SCAN_DEADLINE) as response:
        body = json.load(response)
    parts = body["candidates"][0]["content"]["parts"]
    return ADAPTER.validate_json("".join(p.get("text", "") for p in parts), strict=True)


def warm_demo() -> None:
    """`make demo-warm` (cu internet, înainte de scenă): răspunsurile Gemini pentru fotografiile demo și pentru
    transcrierile pe care sinonimele nu le înțeleg ajung în demo/llm_cache, ca demo-ul să meargă și fără rețea."""
    from polygraph.voice.understand import CACHE as CHECKIN_CACHE
    from polygraph.voice.understand import understand

    CACHE.mkdir(parents=True, exist_ok=True)
    files = sorted((ROOT / "demo" / "photos").glob("*")) + sorted((ROOT / "demo" / "rx").glob("*"))
    images = [(p, mimetypes.guess_type(p)[0]) for p in files]
    images = [(p, mime) for p, mime in images if mime and mime.startswith("image/")]
    failures = []
    for path, mime in images:
        rows = extract_image(path.read_bytes(), "prescription" if path.parent.name == "rx" else "box", mime)
        print(f"  {'✓' if rows else '✗'} {path.relative_to(ROOT)}")
        if not rows:
            failures.append(path.name)
    if not images:
        print("  · nicio fotografie în demo/photos sau demo/rx (scanarea live merge pe OCR-ul telefonului)")

    checkin = json.loads((ROOT / "contracts" / "fixtures" / "checkin_demo.json").read_text(encoding="utf-8"))
    texts = [("checkin_demo.json", checkin["transcript"])] + [
        (p.name, p.read_text(encoding="utf-8")) for p in sorted((ROOT / "demo" / "transcripts").glob("*.txt"))
    ]
    for name, text in texts:
        # aceeași decizie ca la un check-in real: Gemini doar când sinonimele nu găsesc nimic
        u = understand(text)
        if u.used_llm:
            print(f"  ✓ {name}: răspunsul Gemini e în {CHECKIN_CACHE.relative_to(ROOT)}")
        elif u.symptoms:
            print(f"  ✓ {name}: sinonimele ajung, fără Gemini")
        else:
            print(f"  · {name}: fără simptome (intent {u.intent}); nimic de pus în cache")
    if failures:
        raise SystemExit("Extracția a eșuat pentru: " + ", ".join(failures))


if __name__ == "__main__":
    warm_demo()
