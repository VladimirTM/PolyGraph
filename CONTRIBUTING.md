# Cum lucrăm (varianta de hackathon)

Planul complet e în [`docs/PLAN.md`](docs/PLAN.md); fazele și sync point-urile sunt chiar la începutul lui.

## Pornire

```bash
make setup      # hook-urile git (.githooks) + mediul Python (uv)
make mock       # serverul mock pe 0.0.0.0:8000: pacient pat_demo, token demo-token
make check      # R1–R3: contracte, ruff, pytest (< 2 min)
make check-ios  # build + teste iOS pe simulator (doar pe Mac, după ce există app/PolyGraph.xcodeproj)
make models     # regenerează app/PolyGraph/Models/Contracts.swift din contracts/schema
```

## Git

1. **Niciodată direct pe `main`.** Un branch scurt per etapă: `feature/<etapa>-<descriere>` (ex. `feature/b2-engine`), `fix/qN-<id>` pentru constatările din review, `chore/…` pentru infrastructură. Dev A lucrează în `app/`, Dev B în `backend/`, `kb/`, `demo/`.
2. **Commit-uri mici.** Primul rând în engleză, la imperativ, ≤ 72 de caractere, fără punct final; linie goală; `Co-authored-by` = celălalt membru. **Fără co-author sau mențiuni AI** în commit-uri, PR-uri sau cod. Hook-ul `.githooks/commit-msg` verifică asta (`make setup` îl activează).

   | `git config user.name` | Linia de co-author |
   |---|---|
   | `VladimirTM` | `Co-authored-by: Remetan Mihnea-Florin <mihnearemetan@gmail.com>` |
   | `Remetan Mihnea-Florin` | `Co-authored-by: VladimirTM <vladimirghimpau@gmail.com>` |

3. **PR cu `make check` verde, merge imediat** (squash), fără să aștepți review, **cu excepția** schimbărilor în `contracts/`, care se anunță celuilalt înainte și se fac într-un commit separat, înaintea codului.
4. **Merge pe `main` cel puțin la fiecare sync point**; `main` trebuie să fie oricând demonstrabil.
5. Un bug găsit în demo primește întâi un test (sau o intrare în `expected_*.json`), apoi fix-ul.

## Contractele (`contracts/`) sunt sursa de adevăr

- `contracts/schema/*.schema.json`: modelele (JSON Schema 2020-12). Aplicația își generează modelele Swift din ele (`make models`); backend-ul le validează în teste.
- `contracts/api/openapi.yaml`: rutele HTTP.
- `contracts/fixtures/`: pacientul demo și răspunsurile așteptate (`expected_alerts.json`, `expected_schedule.json`, `checkin_demo.json`, `gs1_cases.json`). Sunt testul de acceptare comun: A construiește UI-ul pe ele (prin mock), B le folosește ca golden.
- `contracts/symptoms.md`: vocabularul fix de simptome.
- `contracts/validate.py`: verifică tot (rulat de `make check` și de CI).

## Gate-ul (`make check`, < 2 min)

| Nivel | Ce rulează | Când |
|---|---|---|
| R1 contracte | `contracts/validate.py` | fiecare PR (și CI) |
| R2 static | `ruff check`, `ruff format --check`; `xcodebuild build` | fiecare PR (iOS: local, `make check-ios`) |
| R3 unit | `pytest backend/`; `xcodebuild test` (Swift Testing, doar logică) | fiecare PR (iOS: local) |
| R4 demo e2e | `make demo-check` (din B7) | la fiecare sync point și înainte de pitch |
| R5 review pe simulator | `make review Q=QN` + raportul (etapa Q) | după S1, S2, S3, S4 |

## Reguli pentru agenții de cod

Sunt în [`AGENTS.md`](AGENTS.md) (Codex, Gemini) și [`CLAUDE.md`](CLAUDE.md) (Claude Code); spun același lucru.
