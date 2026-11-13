# kb/: baza de cunoștințe (Dev B)

Reguli scrise de mână (`rules/*.yaml`), interacțiuni verificate (`curated_ddi.csv`, `curated_dfi.csv`), OTC-urile lipsă din catalog (`ro_products_extra.csv`), legările forțate (`overrides.csv`). Datele brute (DDInter, catalogul MS) stau în `kb/raw/` și **nu** intră în git (doar README-urile lor); fiecare le are local.

## `make kb` → `kb/kb.sqlite`

Read-only la runtime, reconstruită reproductibil în ~2 s. Scrie și `app/PolyGraph/Resources/brands.txt` (cele mai frecvente 300 de denumiri, cu brandurile pacientului demo primele), pentru `customWords` din OCR (A2) și `contextualStrings` din Listener (A5).

| Script | Ce face |
|---|---|
| `ingest_ddinter.py` | CSV-urile DDInter → `drug`, `ddi` (toate nivelurile, inclusiv `Unknown`, cu `a_id < b_id`); apoi `curated_ddi.csv` și `curated_dfi.csv`, cu prioritate (nivelul DDInter original rămâne în `ddi.ddinter_level`) |
| `ingest_ro_catalog.py` | catalogul + `ro_products_extra.csv` → `product` (deduplicat pe denumire + formă + concentrație; ambalajele în `pack`, codurile CIM în `cim`); `brands.txt` |
| `link_substances.py` | componentele DCI (latină) ↔ substanțele DDInter (engleză): `overrides.csv` → stem latin → englez, potrivire exactă pe forma „scheletică” → rapidfuzz WRatio ≥ 90 → ATC5 |
| `load_rules.py` | `rules/*.yaml`, validate cu pydantic → `elderly_rule`, `acb`, `timing_rule`, `adverse_effect`, `food_alias` |
| `build.py` | schema, ordinea pașilor, raportul de acoperire (`python kb/build.py -v` listează și potrivirile fuzzy) |

Interogări utile: `ddi_sym` (view) caută o pereche în ambele sensuri (`WHERE a = ? AND b = ?`); `substance.synonyms` (JSON) ține celelalte DCI-uri legate de aceeași substanță (ex. `LEVOTHYROXINUM` și `LEVOTHYROXINUM NATRIUM`). `duplication` e goală: dublurile nu sunt în DDInter descărcabil, iar B2 le calculează pe ATC.

## Acoperirea (13.11.2026)

| | legate la DDInter |
|---|---|
| produse cu o singură substanță | 3.454 / 4.253 = **81,2 %** |
| combinații | 404 / 574 = 70,4 % |
| pacientul demo (inclusiv med_09) | **100 %** (brand și DCI) |

Ținta din plan (≥ 90 % la produsele cu o singură substanță) **nu e atinsă din cauza datelor, nu a potrivirii**: DDInter 2.0 descărcabil acoperă doar grupele ATC A, B, D, H, L, P, R, V, iar multe substanțe uzuale în România nu apar deloc în cele 1.939 (candesartan, dabigatran, vildagliptină, metamizol, etoricoxib, betahistină, piracetam, lercanidipină, nimesulid, trimetazidină …), plus produsele biologice (factori de coagulare, vaccinuri, imunoglobuline). Aceste substanțe primesc totuși un rând în `substance` (fără `ddinter_id`), deci sunt găsite după brand și DCI, doar fără interacțiuni. Lista completă: `python kb/build.py` (secțiunea „Nelegate la DDInter”).
