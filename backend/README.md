# backend/: FastAPI, Python 3.12, uv (Dev B)

- `mock_server.py`: mock-ul P0, servește `contracts/fixtures/` pe toate rutele (`make mock`). Pacient `pat_demo`, token `demo-token`.
- `polygraph/`: backend-ul real (`make dev`), din B2:
  - `kb.py`: singurul acces (read-only) la `kb/kb.sqlite`;
  - `engine/`: `analyze(patient, meds, today)` → alertele, scorul ACB și graful; o verificare per modul (`ddi`, `food`, `duplicate`, `elderly`, `acb`, `expiry`), textele în `texts_ro.py`;
  - `graph/build.py`: graful Cytoscape (plan 5.6);
  - `store/`: `app.sqlite` (pacienți, medicamente, doze, check-in-uri, starea alertelor, link-uri, cache GTIN);
  - `api/main.py`: pacienți, `/meds`, `/analysis`, `/what-if`, `/kb/search`, `/demo/reset`. Restul rutelor (scan, schedule, checkins, feed, share) vin în B3–B6; până atunci, aplicația le ia de la mock.
- `tests/`: `make test`. Testele care au nevoie de `kb/kb.sqlite` (golden-ul B2, rutele reale, verificările B1) se sar dacă baza nu e construită, deci și în CI; regulile motorului rulează și acolo, pe o kb sintetică (`engine_helpers.mini_kb`).

Variabile de mediu pentru `make dev`: `PG_KB` (implicit `kb/kb.sqlite`), `PG_APP_DB` (implicit `backend/app.sqlite`), `PG_TODAY` (data „de azi”, ex. `2026-11-14` ca în fixture-uri), `DEMO_MODE=1` (creează `pat_demo` / `demo-token` și activează `POST /demo/reset`).

```bash
DEMO_MODE=1 PG_TODAY=2026-11-14 make dev
curl -H 'X-Patient-Token: demo-token' localhost:8000/v1/patients/pat_demo/analysis
```


## Scanarea B3

`POST /v1/patients/{id}/scan` primește `kind`, `ocr_lines`, `image` și `datamatrix` conform contractului. Ruta întoarce candidați de verificat. Confirmarea prin `POST /meds` poate memora un GTIN valid împreună cu produsul verificat în catalog.

Potrivirea OCR și DataMatrix funcționează local. Pentru rezerva Gemini, configurează `GEMINI_API_KEY` și, opțional, `GEMINI_MODEL` în mediu sau în `.env`. Cu această configurare, dacă potrivirea locală e insuficientă și cererea include o imagine, backend-ul poate trimite imaginea către Gemini. Rezultatul structurat este memorat local în `demo/llm_cache`. `make demo-warm` pregătește cache-ul din fotografiile demo din `demo/photos` și `demo/rx`.
