"""`make demo`: backend-ul real pentru scenă, într-o singură comandă (B7).

Pornește pe 0.0.0.0 cu DEMO_MODE=1, fără --reload (un fișier salvat în timpul pitch-ului nu repornește serverul),
afișează adresele locale și un QR cu baseURL-ul pentru setările aplicației, plus ce lipsește din pregătire (kb,
fotografii, cache-ul Gemini). Cu Wi-Fi-ul oprit și telefoanele pe hotspot-ul laptopului, adresa bună e cea de pe
interfața hotspot-ului (bridge100 pe macOS), afișată prima.
"""

from __future__ import annotations

import os
import re
import socket
import sqlite3
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path

import zxingcpp
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
PHOTO = re.compile(r"med_0[1-8]\.jpg")  # numele din demo_patient.json (photo_url = /media/med_0N.jpg)
# Sursele scrise de mână din care `make kb` construiește kb.sqlite; kb/raw/ se schimbă doar la o descărcare nouă.
KB_SOURCES = ("ro_products_extra.csv", "curated_ddi.csv", "curated_dfi.csv", "overrides.csv", "rules/*.yaml")


def local_ips() -> list[str]:
    """Adresele IPv4 ale laptopului; întâi hotspot-ul (bridge*), apoi Wi-Fi / Ethernet (en*), apoi restul."""
    found: list[tuple[int, str]] = []
    try:
        out = subprocess.run(["ifconfig"], capture_output=True, text=True, timeout=3).stdout
        iface = ""
        for line in out.splitlines():
            if line and not line[0].isspace():
                iface = line.split(":")[0]
            m = re.search(r"\binet (\d+\.\d+\.\d+\.\d+)", line)
            if m and not m[1].startswith("127."):
                found.append((0 if iface.startswith("bridge") else 1 if iface.startswith("en") else 2, m[1]))
    except (OSError, subprocess.SubprocessError):
        pass
    if not found:
        try:
            out = subprocess.run(["hostname", "-I"], capture_output=True, text=True, timeout=3).stdout
            found = [(1, ip) for ip in out.split() if re.fullmatch(r"\d+\.\d+\.\d+\.\d+", ip) and not ip.startswith("127.")]
        except (OSError, subprocess.SubprocessError):
            pass
    if not found:
        # fără nicio interfață parsabilă: adresa pe care ar ieși un pachet (merge și fără internet, nu trimite nimic)
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            try:
                s.connect(("10.255.255.255", 1))
                found = [(1, s.getsockname()[0])]
            except OSError:
                pass
    return [ip for _, ip in sorted(dict.fromkeys(found))] or ["127.0.0.1"]


def port_free(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        # ca uvicorn: conexiunile rămase în TIME_WAIT după un Ctrl+C nu înseamnă port ocupat
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            s.bind(("0.0.0.0", port))
        except OSError:
            return False
    return True


def qr_lines(text: str) -> list[str]:
    """QR-ul în terminal, cu semi-blocuri (2 module pe un rând), alb pe negru ca să meargă și pe teme închise."""
    barcode = zxingcpp.create_barcode(text, zxingcpp.BarcodeFormat.QRCode)
    img = Image.fromarray(zxingcpp.write_barcode_to_image(barcode, scale=1, add_quiet_zones=True)).convert("L")
    w, h = img.size
    dark = [[img.getpixel((x, y)) < 128 for x in range(w)] for y in range(h)] + [[False] * w]
    glyph = {(False, False): "█", (True, False): "▄", (False, True): "▀", (True, True): " "}
    return ["".join(glyph[(dark[y][x], dark[y + 1][x])] for x in range(w)) for y in range(0, h, 2)]


def kb_built_at(kb: Path) -> float:
    """Momentul build-ului (epoch), din kb_meta.built_at (UTC, scris de kb/build.py); altfel mtime-ul fișierului."""
    try:
        with sqlite3.connect(f"file:{kb}?mode=ro", uri=True) as conn:
            row = conn.execute("SELECT value FROM kb_meta WHERE key = 'built_at'").fetchone()
        if row:
            return datetime.fromisoformat(row[0]).replace(tzinfo=UTC).timestamp()
    except (sqlite3.Error, ValueError):
        pass
    return kb.stat().st_mtime


def kb_status(kb: Path, kb_dir: Path) -> str:
    """O linie pentru `make demo`: kb.sqlite lipsește, e mai vechi decât o sursă (Q3-01) sau e la zi."""
    if not kb.is_file():
        return "✗ kb.sqlite lipsește: rulați make kb"
    built = kb_built_at(kb)
    # built_at are precizie de o secundă: o sursă salvată în aceeași secundă cu build-ul nu e „mai nouă”
    newer = [p for pattern in KB_SOURCES for p in sorted(kb_dir.glob(pattern)) if p.stat().st_mtime >= built + 1]
    if newer:
        names = ", ".join(str(p.relative_to(kb_dir)) for p in newer)
        return f"✗ kb.sqlite e mai vechi decât {names}: rulați make kb"
    return "✓ kb.sqlite la zi"


def readiness() -> list[str]:
    notes = []
    kb = Path(os.environ.get("PG_KB") or ROOT / "kb" / "kb.sqlite")
    notes.append(kb_status(kb, ROOT / "kb"))
    photos = [p for p in (ROOT / "demo" / "photos").glob("*") if PHOTO.fullmatch(p.name)]
    notes.append(
        f"{'✓' if len(photos) >= 8 else '·'} fotografii demo: {len(photos)}/8 în demo/photos (med_01.jpg … med_08.jpg)"
        + ("" if photos else "; aplicația arată o imagine neutră")
    )
    cache = list((ROOT / "demo" / "llm_cache").glob("*.json"))
    notes.append(f"· cache Gemini: {len(cache)} răspunsuri (make demo-warm, cu internet, înainte de scenă)")
    return notes


def main() -> None:
    port = int(os.environ.get("PORT") or 8000)
    if not port_free(port):
        # altfel QR-ul de mai jos ar trimite telefoanele la alt server (de obicei un `make dev` uitat deschis)
        sys.exit(
            f"Portul {port} e ocupat: opriți serverul care îl folosește (make dev / make mock) sau porniți cu "
            f"make demo PORT={port + 1}.\nCe îl ține: lsof -nP -iTCP:{port} -sTCP:LISTEN"
        )
    os.environ["DEMO_MODE"] = "1"
    ips = local_ips()
    url = f"http://{ips[0]}:{port}"
    code = os.environ.get("PG_DOCTOR_CODE") or "medic-demo"
    print("\nPolyGraph · demo\n")
    for line in qr_lines(url):
        print("   " + line)
    if ips == ["127.0.0.1"]:
        print(
            "\n  ⚠ Laptopul nu e în nicio rețea: telefoanele nu pot ajunge la 127.0.0.1.\n"
            "    Porniți Wi-Fi-ul sau hotspot-ul (de exemplu Personal Hotspot de pe un iPhone, la care se conectează\n"
            "    laptopul și celălalt telefon), apoi reporniți make demo ca să apară adresa bună."
        )
    print(f"\n  Aplicația (Setări → adresa serverului): {url}")
    for ip in ips[1:]:
        print(f"                              sau: http://{ip}:{port}")
    print(f"  Portalul medicului:  {url}/portal   (cod: {code})")
    print(f"  Verificare:          make demo-check URL=http://127.0.0.1:{port}\n")
    for note in readiness():
        print("  " + note)
    print("\n  Logurile de mai jos arată fiecare scanare, alertă nouă și check-in (ce a decis și din ce sursă).\n")
    sys.stdout.flush()

    import uvicorn

    uvicorn.run("polygraph.api.main:app", host="0.0.0.0", port=port, log_level="info", access_log=False)


if __name__ == "__main__":
    main()
