# PolyGraph

Pozezi cutiile de medicamente și rețetele bunicii; PolyGraph construiește graful ei terapeutic, găsește deterministic interacțiunile, dublurile și medicamentele nepotrivite vârstei, îi face un program zilnic simplu, o ascultă când spune cum se simte și ține familia, farmacistul și medicul de familie în aceeași buclă.

UniHack 2026 · The Bloom → Medical Renaissance · aplicație iOS nativă (SwiftUI) + backend Python (FastAPI).

> Prototip de hackathon. Nu pune diagnostice, nu schimbă și nu oprește medicamente, nu recomandă doze.

## Pornire

```bash
make setup     # hook-urile git + mediul Python (necesită uv)
make mock      # serverul mock pe :8000 (pacient pat_demo, token demo-token)
make check     # contracte + ruff + pytest
```

Aplicația iOS: `app/PolyGraph.xcodeproj` (vezi [`app/README.md`](app/README.md)); în setările ei, baseURL = IP-ul Mac-ului, port 8000.

## Structura

| Folder | Ce e | Cine |
|---|---|---|
| `app/` | proiectul Xcode (SwiftUI) | Dev A |
| `backend/` | FastAPI, mock-ul, testele | Dev B |
| `kb/` | reguli, interacțiuni verificate, ingestia | Dev B |
| `contracts/` | schemele, API-ul, fixture-urile demo: sursa de adevăr | amândoi |
| `demo/` | poze, rețeta, transcrieri | Dev B |
| `docs/` | [planul](docs/PLAN.md) (fazele sunt la început), [designul](docs/DESIGN.md), review-urile | amândoi |

Cum lucrăm: [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Date și licențe

DDInter 2.0 (CC BY-NC-SA 4.0, doar necomercial), Catalogul Public național al prețurilor maximale (Ministerul Sănătății), AGS Beers Criteria 2023, ACB Scale (Regenstrief), RCP-urile de pe anm.ro. Detalii în `kb/raw/*/README.md` și `kb/rules/README.md`.
