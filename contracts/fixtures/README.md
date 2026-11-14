# Fixture-urile pacientului demo

Testul de acceptare comun: A construiește UI-ul pe ele (prin `make mock`), B le folosește ca golden (B2, B4, B5). „Azi” în fixture-uri = **2026-11-14**.

| Fișier | Ce conține |
|---|---|
| `demo_patient.json` | Maria (78 de ani, aparținător Ana), ancorele zilei și cele 8 medicamente (med_01–med_08, plan 5.8) |
| `med_09_fromilid.json` | rețeta ORL (claritromicină, 7 zile), adăugată în scenariul „medic nou” |
| `expected_alerts.json` | alertele complete (validează după `alert.schema.json`): `without_med_09` (27) și `added_with_med_09` (6). Golden-ul compară doar `kind`, `severity`, `med_ids` sortate și `basis`; textele sunt doar pentru UI |
| `expected_schedule.json` | programul zilei (5 momente) |
| `checkin_demo.json` | check-in-ul demo: amețeală la ridicare + vânătăi → escaladare |
| `gs1_cases.json` | 12 cazuri GS1 **sintetice** (GTIN-uri inventate, cu cifra de control corectă); codurile reale se adaugă cu `synthetic: false` după scanarea cutiilor |
| `date_words.json` | perechi dată → text („Azi, 14:00”, „joi, 12 nov., 14:00”) pentru `PgFormat.relativeDay` (app) și `relative_day` (portal); verificate de pytest și XCTest (Q3F4) |

## Decizii luate la P0 (confirmate la S0, 13.11.2026)

1. **Alertele de mâncare** vin toate din `kb/curated_dfi.csv` (8 fără med_09). Grepfrutul cu simvastatina e `Major` în DDInter, deci alerta e `major`; ca pe ecranul Anei să rămână 4 carduri grave, **alertele `food` se grupează într-un singur card „Mâncare și băutură”, indiferent de severitate** (regula e scrisă în plan, 5.3 și A3). **Confirmat.**
2. **Programul are 5 momente, nu 4.** Cu regulile din `kb/rules/timing.yaml`, Euthyrox-ul singur la trezire (07:00), omeprazolul înainte de micul dejun (07:30) și Nurofen-ul la masă (08:00) cer trei momente dimineața. Patru momente s-ar obține doar punând omeprazolul lângă Euthyrox la 07:00 (permis de reguli, dar contrazice „Euthyrox singur”). **Decis la S0: varianta A.** B4 adaugă în `kb/rules/timing.yaml` o regulă `alone: true` pentru levotiroxină (se ia singură, pe stomacul gol), deci rămân 5 momente, iar `expected_schedule.json` rămâne neschimbat. Textul de pitch se corectează la „5 momente” (plan, secțiunea 8).
3. **Perechile `Unknown` din DDInter fără rând curated** (ex. ibuprofen + simvastatină, amitriptilină + omeprazol, amlodipină + levotiroxină) nu au alertă în fixture. Regula de clasă (5.3, punctul 3) le poate da un nivel prin analogie; B1 le verifică pe datele reale și, dacă apar, le adaugă aici în același PR. **Confirmat:** cifrele 24 / 6 din `expected_alerts.json` rămân provizorii până la B1. **Verificat la B1 (13.11.2026):** regula de clasă dă încă 3 alerte pe datele reale (ibuprofen + omeprazol prin naproxen și ibuprofen + amitriptilină prin clomipramină, `moderate`; amlodipină + omeprazol prin nifedipină, `minor`), deci 27 / 6. Celelalte perechi `Unknown` nu au soră de clasă cu nivel.
4. **Beers „AINS + anticoagulant”** nu e alertă separată: e menționat în `detail`-ul alertei `al_ddi_med_01_med_02` (B2, punctul 2).
5. **Mock-ul:** `POST /demo/reset?live_scan=1` pornește fără Sintrom și Nurofen (scenariul din secțiunea 7, unde se scanează live); fără parametru, cu toate 8. Am adăugat `GET /v1/patients/{id}/meds` (lista) și `GET /media/{name}` (pozele), care lipseau din tabelul 5.7.
