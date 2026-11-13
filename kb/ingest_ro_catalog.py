"""Catalogul public al prețurilor (MS) + kb/ro_products_extra.csv → produsele (tabela product) și brands.txt."""

from __future__ import annotations

import csv
import json
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

import openpyxl

from common import BRANDS_PATH, KB_DIR, RAW_DIR, brand_norm, norm_dci, split_dci

CATALOG_PATH = RAW_DIR / "ro" / "catalog_public_2026-08-04.xlsx"
EXTRA_PATH = KB_DIR / "ro_products_extra.csv"
COLUMNS = {
    "brand": "Denumire produs",
    "form": "Formă",
    "strength": "Concentrație",
    "dci": "DCI",
    "atc": "grupa ATC",
    "pack": "Ambalaj",
    "cim": "cod_cim",
}


@dataclass
class Product:
    brand: str
    form: str | None
    strength_text: str | None
    dci_raw: str | None
    atc: str | None
    source: str
    packs: list[str] = field(default_factory=list)
    cims: list[str] = field(default_factory=list)
    rows: int = 0

    @property
    def components(self) -> list[str]:
        return split_dci(self.dci_raw)

    @property
    def brand_norm(self) -> str:
        return brand_norm(self.brand)


def _clean(value) -> str | None:
    if value is None:
        return None
    text = " ".join(str(value).split())
    return text or None


def load_catalog(path: Path = CATALOG_PATH) -> tuple[list[Product], int]:
    if not path.exists():
        raise SystemExit(f"Lipsește {path} (vezi kb/raw/ro/README.md).")
    ws = openpyxl.load_workbook(path, read_only=True, data_only=True)["CP"]
    rows = ws.iter_rows(values_only=True)
    header = [str(h).strip() if h is not None else "" for h in next(rows)]
    idx = {key: header.index(col) for key, col in COLUMNS.items()}
    products: dict[tuple, Product] = {}
    n_rows = 0
    for row in rows:
        brand = _clean(row[idx["brand"]])
        if not brand:
            continue
        n_rows += 1
        form, strength = _clean(row[idx["form"]]), _clean(row[idx["strength"]])
        key = (brand.upper(), (form or "").upper(), (strength or "").replace(" ", "").upper())
        prod = products.get(key)
        if prod is None:
            prod = products[key] = Product(
                brand=brand,
                form=form,
                strength_text=strength,
                dci_raw=_clean(row[idx["dci"]]),
                atc=_clean(row[idx["atc"]]),
                source="catalog",
            )
        prod.rows += 1
        for attr, col in (("packs", "pack"), ("cims", "cim")):
            value = _clean(row[idx[col]])
            if value and value not in getattr(prod, attr):
                getattr(prod, attr).append(value)
    return list(products.values()), n_rows


def load_extra(path: Path = EXTRA_PATH) -> list[Product]:
    out = []
    with path.open(encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            strength = _clean(row["concentratie"])
            if strength and "completat" in strength:
                strength = None
            out.append(
                Product(
                    brand=row["denumire_produs"].strip(),
                    form=_clean(row["forma"]),
                    strength_text=strength,
                    dci_raw=norm_dci(row["dci"]),
                    atc=_clean(row["atc"]),
                    source="extra",
                    rows=1,
                )
            )
    return out


def write_products(conn, products: list[Product]) -> list[int]:
    ids = []
    for p in products:
        cur = conn.execute(
            "INSERT INTO product(brand, brand_norm, dci_raw, form, strength_text, atc, pack, gtin, cim, source)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?, ?)",
            (
                p.brand,
                p.brand_norm,
                p.dci_raw,
                p.form,
                p.strength_text,
                p.atc,
                " | ".join(p.packs) or None,
                json.dumps(p.cims) if p.cims else None,
                p.source,
            ),
        )
        ids.append(cur.lastrowid)
    return ids


def write_brands(products: list[Product], pinned: list[str] = (), path: Path = BRANDS_PATH, limit: int = 300) -> int:
    """Cele mai frecvente denumiri (fără concentrație), pentru customWords din OCR (A2) și Listener (A5).

    Frecvența = numărul de ambalaje din catalog. Intră mereu, primele: brandurile din `pinned` (cutiile pacientului
    demo, scanate live) și produsele din ro_products_extra.csv (OTC-urile).
    """
    freq: Counter = Counter()
    display: dict[str, str] = {}
    extra: list[str] = []
    for name in pinned:
        key = brand_norm(name)
        if key and key not in extra:
            extra.append(key)
            display.setdefault(key, name.strip())
    for p in products:
        key = p.brand_norm
        if not key or len(key) < 3:
            continue
        freq[key] += max(p.rows, 1)
        display.setdefault(key, _title(key))
        if p.source == "extra" and key not in extra:
            extra.append(key)
    chosen = extra + [k for k, _ in sorted(freq.items(), key=lambda kv: (-kv[1], kv[0])) if k not in extra]
    lines = [display[k] for k in chosen[:limit]]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return len(lines)


def _title(key: str) -> str:
    return " ".join(w.upper() if len(w) <= 2 and w.isalpha() and w not in ("de", "cu") else w.capitalize() for w in key.split())
