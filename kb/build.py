"""make kb: construiește kb/kb.sqlite (read-only la runtime) din kb/raw/ + fișierele curate, cu raport de acoperire."""

from __future__ import annotations

import json
import os
import shutil
import sqlite3
import sys
import tempfile
import time
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from common import DB_PATH, INN_ALIASES, ROOT  # noqa: E402
from ingest_ddinter import apply_curated_ddi, apply_curated_dfi, load_ddinter, write_ddi, write_drugs  # noqa: E402
from ingest_ro_catalog import load_catalog, load_extra, write_brands, write_products  # noqa: E402
from link_substances import link, write_product_substances, write_substances  # noqa: E402
from load_rules import FoodKeys, load_all, symptom_codes, write_rules  # noqa: E402

SCHEMA = """
CREATE TABLE kb_meta(key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE drug(ddinter_id TEXT PRIMARY KEY, name TEXT NOT NULL);
CREATE TABLE substance(
    id INTEGER PRIMARY KEY, inn TEXT NOT NULL, dci_ro TEXT, atc TEXT, ddinter_id TEXT REFERENCES drug(ddinter_id),
    synonyms TEXT NOT NULL DEFAULT '[]'
);
CREATE INDEX substance_inn ON substance(inn);
CREATE INDEX substance_dci ON substance(dci_ro);
CREATE INDEX substance_atc ON substance(atc);
CREATE TABLE product(
    id INTEGER PRIMARY KEY, brand TEXT NOT NULL, brand_norm TEXT NOT NULL, dci_raw TEXT, form TEXT, strength_text TEXT,
    atc TEXT, pack TEXT, gtin TEXT, cim TEXT, source TEXT NOT NULL CHECK (source IN ('catalog', 'extra'))
);
CREATE INDEX product_brand_norm ON product(brand_norm);
CREATE TABLE product_substance(
    product_id INTEGER NOT NULL REFERENCES product(id), substance_id INTEGER NOT NULL REFERENCES substance(id),
    PRIMARY KEY (product_id, substance_id)
);
CREATE INDEX product_substance_sub ON product_substance(substance_id);
-- a_id < b_id; nivelurile DDInter, inclusiv Unknown (regula de clasă din B2), plus Contraindicated din curated.
CREATE TABLE ddi(
    a_id INTEGER NOT NULL REFERENCES substance(id), b_id INTEGER NOT NULL REFERENCES substance(id),
    level TEXT NOT NULL CHECK (level IN ('Contraindicated', 'Major', 'Moderate', 'Minor', 'Unknown')),
    mechanism TEXT, management TEXT, ref TEXT,
    source TEXT NOT NULL CHECK (source IN ('ddinter', 'curated')),
    basis TEXT, analogy_via TEXT, source_url TEXT, ddinter_level TEXT, needs_check TEXT, checked_by TEXT,
    PRIMARY KEY (a_id, b_id), CHECK (a_id < b_id)
);
CREATE INDEX ddi_b ON ddi(b_id);
CREATE VIEW ddi_sym AS
    SELECT a_id AS a, b_id AS b, * FROM ddi UNION ALL SELECT b_id AS a, a_id AS b, * FROM ddi;
CREATE TABLE dfi(
    substance_id INTEGER NOT NULL REFERENCES substance(id), food TEXT NOT NULL REFERENCES food_alias(key), food_ro TEXT,
    level TEXT NOT NULL, description TEXT, management TEXT, basis TEXT, source TEXT NOT NULL, source_url TEXT, needs_check TEXT
);
-- Dublurile terapeutice nu sunt în fișierele DDInter descărcabile; B2 le calculează pe ATC.
-- Tabela rămâne pentru perechi adăugate de mână.
CREATE TABLE duplication(a_id INTEGER NOT NULL, b_id INTEGER NOT NULL, note TEXT, PRIMARY KEY (a_id, b_id));
CREATE TABLE elderly_rule(
    id TEXT PRIMARY KEY, severity TEXT NOT NULL, title TEXT, detail TEXT, recommendation TEXT, source TEXT NOT NULL,
    stopp_id TEXT, spec TEXT NOT NULL
);
CREATE TABLE acb(
    inn TEXT NOT NULL, substance_id INTEGER, score INTEGER NOT NULL CHECK (score BETWEEN 1 AND 3), source TEXT NOT NULL
);
CREATE TABLE timing_rule(
    inn TEXT NOT NULL, substance_id INTEGER, atc TEXT, with_food TEXT, preferred_time TEXT, instruction TEXT,
    source TEXT NOT NULL, verified INTEGER NOT NULL, spec TEXT NOT NULL
);
CREATE TABLE adverse_effect(
    inn TEXT NOT NULL, substance_id INTEGER, atc TEXT, symptom_code TEXT NOT NULL, source TEXT NOT NULL, verified INTEGER NOT NULL
);
CREATE TABLE food_alias(
    key TEXT PRIMARY KEY, label_ro TEXT NOT NULL, synonyms TEXT NOT NULL, ddinter TEXT NOT NULL, source TEXT NOT NULL
);
"""


def build(db_path: Path = DB_PATH, brands: bool = True) -> dict:
    t0 = time.perf_counter()
    rules = load_all()
    codes = symptom_codes()
    bad = sorted({c for a in rules["adverse_effects"].substances for c in a.effects} - codes)
    if bad:
        raise SystemExit(f"adverse_effects.yaml: coduri care nu sunt în contracts/symptoms.md: {bad}")

    ddinter = load_ddinter()
    catalog, catalog_rows = load_catalog()
    extra = load_extra()
    products = catalog + extra
    linked = link(ddinter.drugs, products)

    # Construită într-un director temporar și copiată la final: kb.sqlite nu rămâne niciodată pe jumătate scrisă.
    tmpdir = tempfile.TemporaryDirectory(prefix="polygraph-kb-")
    tmp = Path(tmpdir.name) / "kb.sqlite"
    conn = sqlite3.connect(tmp)
    conn.executescript(SCHEMA)
    write_drugs(conn, ddinter)
    write_substances(conn, linked)
    product_ids = write_products(conn, products)
    write_product_substances(conn, products, product_ids, linked)

    sub_by_ddinter = {s.ddinter_id: s.id for s in linked.substances if s.ddinter_id}
    sub_by_inn: dict[str, int] = {}
    for s in linked.substances:  # substanțele DDInter au prioritate la același INN
        if s.ddinter_id or s.inn not in sub_by_inn:
            sub_by_inn.setdefault(s.inn, s.id)
    for eu, us in INN_ALIASES.items():  # regulile pot folosi INN-ul european („chlorphenamine”)
        if us in sub_by_inn:
            sub_by_inn.setdefault(eu, sub_by_inn[us])
    write_ddi(conn, ddinter, sub_by_ddinter)
    n_cur_ddi = apply_curated_ddi(conn, sub_by_inn)
    n_dfi, dfi_skipped = apply_curated_dfi(conn, sub_by_inn, FoodKeys(rules["food_alias"]))
    missing_inn = write_rules(conn, rules, sub_by_inn)
    conn.execute("INSERT INTO kb_meta(key, value) VALUES ('built_at', datetime('now'))")
    conn.commit()
    conn.execute("VACUUM")
    conn.close()
    shutil.copyfile(tmp, db_path)
    tmpdir.cleanup()

    report = coverage(products, linked)
    report.update(
        seconds=time.perf_counter() - t0,
        catalog_rows=catalog_rows,
        products=len(products),
        extra=len(extra),
        ddinter_rows=ddinter.rows,
        ddinter_pairs=len(ddinter.pairs),
        ddinter_conflicts=ddinter.conflicts,
        ddinter_drugs=len(ddinter.drugs),
        curated_ddi=n_cur_ddi,
        dfi=n_dfi,
        dfi_skipped=dict(dfi_skipped),
        missing_inn=sorted(set(missing_inn)),
        substances=len(linked.substances),
    )
    if brands:
        report["brands"] = write_brands(products, pinned=demo_brands())
    return report


def demo_brands() -> list[str]:
    """Brandurile pacientului demo (contracts/fixtures), ca OCR-ul să le recunoască la scanarea live."""
    fix = ROOT / "contracts" / "fixtures"
    meds = json.loads((fix / "demo_patient.json").read_text(encoding="utf-8"))["meds"]
    meds.append(json.loads((fix / "med_09_fromilid.json").read_text(encoding="utf-8")))
    return [m["product"]["brand"] for m in meds]


def coverage(products, linked) -> dict:
    """% produse cu toate substanțele legate la DDInter; nelegatele sortate după frecvența DCI."""
    with_ddinter = {s.id for s in linked.substances if s.ddinter_id}
    single = [p for p in products if len(p.components) == 1]
    multi = [p for p in products if len(p.components) > 1]
    no_dci = [p for p in products if not p.components]

    def ok(p):
        return all(linked.by_dci[c] in with_ddinter for c in p.components)

    unlinked = Counter(c for p in products for c in p.components if linked.by_dci[c] not in with_ddinter)
    methods = Counter(linked.method.values())
    return {
        "single_total": len(single),
        "single_linked": sum(ok(p) for p in single),
        "multi_total": len(multi),
        "multi_linked": sum(ok(p) for p in multi),
        "no_dci": len(no_dci),
        "all_total": len(products) - len(no_dci),
        "all_linked": sum(ok(p) for p in products if p.components),
        "methods": dict(methods),
        "unlinked": unlinked.most_common(),
        "fuzzy": linked.fuzzy_log,
    }


def print_report(r: dict, top: int = 40) -> None:
    pct = lambda a, b: f"{100 * a / b:.1f}%" if b else "-"  # noqa: E731
    print(f"kb.sqlite construit în {r['seconds']:.1f} s")
    print(
        f"  DDInter: {r['ddinter_rows']} rânduri → {r['ddinter_pairs']} perechi unice, {r['ddinter_drugs']} substanțe"
        f" ({r['ddinter_conflicts']} rânduri cu nivel diferit între fișiere)"
    )
    print(
        f"  Catalog: {r['catalog_rows']} ambalaje → {r['products'] - r['extra']} produse;"
        f" + {r['extra']} din ro_products_extra.csv"
    )
    print(f"  Substanțe: {r['substances']}; legarea componentelor DCI: {r['methods']}")
    print(f"  Curated: {r['curated_ddi']} DDI, {r['dfi']} DFI (sărite: {r['dfi_skipped']})")
    print("Acoperire (produse cu toate substanțele legate la DDInter):")
    print(f"  o singură substanță: {r['single_linked']}/{r['single_total']} = {pct(r['single_linked'], r['single_total'])}")
    print(f"  combinații:          {r['multi_linked']}/{r['multi_total']} = {pct(r['multi_linked'], r['multi_total'])}")
    print(
        f"  toate (cu DCI):      {r['all_linked']}/{r['all_total']} = {pct(r['all_linked'], r['all_total'])};"
        f" {r['no_dci']} fără DCI („COMBINATII” fără listă)"
    )
    print(f"Nelegate la DDInter ({len(r['unlinked'])} DCI), primele {top} după frecvență:")
    for dci, n in r["unlinked"][:top]:
        print(f"  {n:4d}  {dci}")
    if r["missing_inn"]:
        print(f"INN-uri din reguli fără substanță în kb: {', '.join(r['missing_inn'])}")
    if "brands" in r:
        print(f"brands.txt: {r['brands']} denumiri")


if __name__ == "__main__":
    report = build()
    print_report(report, top=int(os.environ.get("KB_REPORT_TOP", "40")))
    if "-v" in sys.argv:
        print("Potriviri fuzzy:")
        for dci, name, score in sorted(report["fuzzy"], key=lambda t: t[2]):
            print(f"  {score:5.1f}  {dci} → {name}")
