# Reguli curate (kb/rules/)

| Fișier | Ce conține | Sursa |
|---|---|---|
| elderly.yaml | 13 reguli pentru medicamente potențial nepotrivite la ≥ 65 de ani, pe cod ATC | AGS Beers 2023 (STOPP v3 ca sursă secundară; ID-urile STOPP de completat) |
| acb.yaml | scorurile anticolinergice 1–3 pentru ~75 de substanțe | ACB Scale, actualizarea 2012 (Regenstrief; permisiune pentru uz comercial) |
| timing.yaml | regulile de orar (stomac gol, separări) | RCP-urile produselor (etapa 2d) |
| adverse_effects.yaml | efectele adverse frecvente ca coduri din `contracts/symptoms.md` (corelarea din B5) | RCP-urile, 4.8 (`verified: false`: de verificat) |
| food_alias.yaml | cheia alimentului din `dfi` → eticheta în română + sinonime | DDInter 2.0 (site) + `curated_dfi.csv` |

Pe pacientul demo: ibuprofen (AINS cronic + AINS cu anticoagulant), amitriptilină (triciclic), omeprazol (IPP > 8 săptămâni), ACB total = 3 (amitriptilină).

Toate fișierele sunt validate de modelele pydantic din `kb/load_rules.py` (`make kb` și `make test`); fiecare regulă are `source`, iar codurile din `adverse_effects.yaml` trebuie să existe în `contracts/symptoms.md`.
