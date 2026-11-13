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

from polygraph.extract.ocr_match import RawExtraction
from polygraph.kb import ROOT

CACHE = ROOT / "demo" / "llm_cache"
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
    # Un singur apel, fără reîncercare: o scanare așteaptă cel mult 8 s, apoi completare manuală.
    try:
        with urlopen(request, timeout=8) as response:
            body = json.load(response)
        parts = body["candidates"][0]["content"]["parts"]
        rows = ADAPTER.validate_json("".join(p.get("text", "") for p in parts), strict=True)
    except (OSError, ValueError, KeyError, IndexError, TypeError, AttributeError):
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


def warm_demo() -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    files = sorted((ROOT / "demo" / "photos").glob("*")) + sorted((ROOT / "demo" / "rx").glob("*"))
    images = [(p, mimetypes.guess_type(p)[0]) for p in files]
    images = [(p, mime) for p, mime in images if mime and mime.startswith("image/")]
    if not images:
        raise SystemExit("Nu există fotografii demo în demo/photos sau demo/rx.")
    failures = []
    for path, mime in images:
        image = path.read_bytes()
        rows = extract_image(image, "prescription" if path.parent.name == "rx" else "box", mime)
        if not rows:
            failures.append(path.name)
            continue
    if failures:
        raise SystemExit("Extracția a eșuat pentru: " + ", ".join(failures))


if __name__ == "__main__":
    warm_demo()
