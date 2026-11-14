# PolyGraph: plan de development pentru hackathon (~30 h de lucru, 2 developeri, iOS nativ)

**Track:** The Bloom (Connected Communities, Mobility & Healthcare) → **Medical Renaissance**
**Platformă:** aplicație **iOS nativă (SwiftUI)**, backend Python. Fără Android: echipa are două MacBook-uri și două iPhone-uri, iar demo-ul se face pe iPhone.
**Repo:** [github.com/VladimirTM/PolyGraph](https://github.com/VladimirTM/PolyGraph) (local: `~/Git/PolyGraph`)

**Pitch într-o frază:** pozezi cutiile de medicamente și rețetele bunicii; PolyGraph construiește graful ei terapeutic, găsește deterministic interacțiunile, dublurile și medicamentele nepotrivite vârstei, îi face un program zilnic simplu, o ascultă când spune cum se simte și ține familia și medicul de familie în aceeași buclă.

---

## Fazele de lucru și sync point-urile (de aici vedeți unde suntem)

**Unde suntem (14.11.2026):** S0 e trecut: P0 e în `main` ([PR #1](https://github.com/VladimirTM/PolyGraph/pull/1), [PR #2](https://github.com/VladimirTM/PolyGraph/pull/2)), CI verde, aplicația goală rulează pe ambele iPhone-uri, iar deciziile din `contracts/fixtures/README.md` sunt luate. **B1 e în `main`:** `make kb` construiește `kb/kb.sqlite` în ~1,5 s, `make check` are 72 de teste, `expected_alerts.json` are acum 27 / 6 alerte (3 adăugate prin regula de clasă), iar `app/PolyGraph/Resources/brands.txt` e gata pentru A2. **B2 e în `main`** ([PR #7](https://github.com/VladimirTM/PolyGraph/pull/7)): `polygraph.engine.analyze` dă exact `expected_alerts.json` (27 fără med_09, 33 cu med_09, aceleași id-uri și același `basis`) în ~10 ms, graful Cytoscape validează după `graph.schema.json`, iar `make dev` pornește backend-ul real (pacienți, `/meds`, `/analysis`, `/what-if`, `/kb/search`, `/demo/reset` cu `DEMO_MODE=1`) pe `app.sqlite`. **B3 e închis** ([PR #9](https://github.com/VladimirTM/PolyGraph/pull/9) și completarea cu OCR-ul real din A2): toate cele patru capturi din `demo/ocr/` trec prin `ocr_match` fără Gemini. `make demo-b3` verifică fluxul cap-coadă pe date sintetice. **A1 e în `main`** ([PR #8](https://github.com/VladimirTM/PolyGraph/pull/8)): aplicația rulează pe mock pe ambele iPhone-uri și pe simulator (`make check-ios` verde, 18 teste). **B4 e în `main`** ([PR #13](https://github.com/VladimirTM/PolyGraph/pull/13)): `GET /schedule` real dă exact `expected_schedule.json` (5 momente, Euthyrox singur prin `alone: true` în `timing.yaml`) în ~4 ms, iar pe 200 de regimuri aleatoare nicio regulă dură nu e încălcată când `unsatisfied` e gol; regulile imposibile ies în `unsatisfied` și devin alerte `timing` (`ask_doctor`); `POST /doses` e idempotent pe `med_id` + `scheduled_at`. **A2 e gata** ([PR #15](https://github.com/VladimirTM/PolyGraph/pull/15)): cutie (DataMatrix + poză) și rețetă (camera de documente), OCR pe telefon, `/scan`, sheet-ul de confirmare cu câmpurile „verificați” și avertizări de expirare / duplicat, camera falsă `PG_FAKE_SCAN`; `make check-ios` verde, încercat pe iPhone cu cutiile de test din `demo/datamatrix/`; rămân cutiile fizice în sală (T-A2-03). **B5 e în `main`** ([PR #16](https://github.com/VladimirTM/PolyGraph/pull/16)) cu rutele reale `/checkins` și `/feed`. `make check` trece cu 247 de teste cu `kb.sqlite` construit. **A3 e gata** (modul aparținător: listă pe medici cu „Anulează”, alerte cu zoom, ACB, graf radial local, detaliu + editare). **B6 e gata** ([PR #21](https://github.com/VladimirTM/PolyGraph/pull/21), `feature/b6-doctor-portal`): portalul medicului de familie `/portal` (login prin cod, lista pacienților, fișa cu decizie + notă pe alertă, care apare pe alertă și în Noutăți), reconcilierea de tipărit (2 pagini A4), QR-ul care adaugă pacientul în lista medicului și graful pentru WKWebView (`/share/{token}/graph?embed=1`); `make check` are 266 de teste; T-B6-04 încercat pe 14.11.2026. **A4 e gata** ( „Acum” cu cronologia de puncte, cardurile cu poze, „AM LUAT” / „Mai târziu” / „Am sărit” cu guard de 1 s, bifa care zboară, „Anulează” 5 s, vocea `ro-RO`, notificările locale, cardul calm pentru alertele pacientului, „Ziua de azi” cu momentele deschise la atingere); `make check-ios` verde, încercat pe iPhone cu backend-ul real, inclusiv la textul maxim. **A5 e gata** (check-in vocal pe telefon, Noutăți cu polling și notificări; încercat pe două iPhone-uri). **B7 e gata** (`chore/b7-demo-hardening`): `make demo` (DEMO_MODE=1, fără reload, IP-ul local + QR), `make demo-check` verde în proces și pe serverul pornit (11 pași din secțiunea 7, ~1,2 s), istoricul demo recreat la reset (7 zile, 2 doze ratate, un check-in vechi), `/demo/missed-dose` real, alertele grave noi în Noutăți, termen total pentru Gemini, loguri lizibile; `make check` are 282 de teste; T-B7-06 (Wi-Fi-ul laptopului oprit) și T-B6-04 încercate pe 14.11.2026. **A6 e gata** ([PR #25](https://github.com/VladimirTM/PolyGraph/pull/25)). **X1 e în `main`** ([PR #30](https://github.com/VladimirTM/PolyGraph/pull/30)): „Pot să iau…?” pe severități, grav și „fără date” în Noutăți, întrebarea și răspunsul în fișa din portal; `make check` are 292 de teste, `make demo-check` verde cu pasul X1. **Q0 e în `main`** ([PR #31](https://github.com/VladimirTM/PolyGraph/pull/31)), iar **Q3 e rulat** ([PR #32](https://github.com/VladimirTM/PolyGraph/pull/32)): 41 de constatări pe aplicație, cu planul de reparații în secțiunea „Q3 · Turul agresiv pe aplicație”, aliniat cu QA (web și backend). **Q3F0 e gata** (`fix/q3f0-kb-freshness`): `kb.sqlite` reconstruit pe Mac-ul de demo, iar `make demo` afișează ✗ când o sursă din `kb/` e mai nouă decât build-ul; `make check` are 302 teste, `make demo-check` verde cu pasul X1. **Q3F2 e gata** (`fix/q3f2-voice-scan`): simptomele în cuvinte obișnuite și pe cuvinte întregi, rețetele scrise pe DCI, avertizările cu rândul și posologia necitite, textele de check-in corectate, `/what-if` cu același produs ca check-in-ul, întrebarea X1 o singură dată pe zi în Noutăți; `make check` are 328 de teste. **Q3F1 e în `main`** ([PR #36](https://github.com/VladimirTM/PolyGraph/pull/36)): modul senior cu „Încearcă din nou”, `dayDone` adevărat, coada de confirmări persistată, reîncărcarea la revenire și la miezul nopții. **Q3F4 e implementat** (`fix/q3f4-caregiver-consistency`): datele „Azi, 14:00” / „joi, 12 nov., 14:00” în Noutăți și în portal (`date_words.json`), „Încearcă din nou” în graf și banda „Nu am putut actualiza” în Medicamente / Noutăți, ACB ultimul și portocaliu, alertele noi numărate ca în portal, butoanele demo dezactivate sincron, o singură notificare pentru loturi mari, „Arată medicului” la ambii; `make check` are 341 de teste; `make check-ios` și turul de review rămân de rulat pe Mac. **Urmează:** Q3F3 (Dev B: robustețea API-ului) în paralel cu QA1–QA4; materialele, pitch-ul și pregătirea Q1 (Dev B, lista de mai jos); apoi S4 (feature freeze), D1 și D2. Actualizați coloana „Status” la fiecare sync point.

**Ce face Dev B cât Dev A lucrează la Q0, Q1 și fix-urile din app (14.11.2026)**, nimic nu depinde de app:
1. ✅ **X1 pe backend** (`feature/x1-can-i-take`, [PR #30](https://github.com/VladimirTM/PolyGraph/pull/30), 14.11.2026; `polygraph/voice/can_i_take.py`, 9 teste + 1 în `test_share.py`, pas nou în `make demo-check`): „Pot să iau…?” rulat ca what-if pe regimul Mariei, cu răspunsul pe severități decis la 1.3 (grav și „fără date” ajung în Noutăți). Aplicația trimite deja textul și citește `reply_text` cu voce, deci X1 merge fără nicio schimbare în app. De spus lui Dev A: în Noutăți apar acum și evenimente `checkin` neescaladate (întrebările, cu `severity` major sau null); `FeedModel.isSerious` notifică pentru toate, inclusiv „fără date”, iar comentariul „doar când sunt escaladate” nu mai e adevărat (decizie: păstrăm notificarea pentru „fără date” sau `severity != nil`).
2. **Materialele:** Nurofen se cumpără fără rețetă; Sintrom e pe rețetă, deci se tipărește cutia de test `demo/datamatrix/test_sintrom.png`; rețeta ORL tipărită (`demo/rx/reteta_demo_fromilid.pdf`, A4, scala 100%).
3. **Pitch-ul:** slide-ul 5 („Cum e construit”: diagrama din 2.1, „LLM doar la margini”, o captură cu logurile `SCAN` / `ALERTĂ` din `make demo`); cifrele de pe slide-ul 1 verificate în sursele originale înainte să intre pe slide; câte 2 fraze pentru fiecare întrebare probabilă a juriului (secțiunea 8).
4. **Pregătirea pentru Q1** (rulează diseară pe Mac-ul lui Dev B): `make check-ios` verde pe Mac-ul lui, laptopul la priză și fără sleep (`caffeinate`).
5. **Deschise după X1 (14.11.2026):**
   - al doilea iPhone nu se conectează din aplicație (`-1009`, „offline”), deși Safari ajunge la `/health` și Local Network e pornit: de aflat cauza din linia completă `unsatisfied (…)` din consola Xcode înainte de D1; rezerva sigură pentru scenă e hotspot-ul Mac-ului (`make demo` afișează primul `bridge100`);
   - ✅ `.claude/skills/apple-design/SKILL.md` lipsea din repo, deși `CLAUDE.md`, `AGENTS.md` și `docs/DESIGN.md` trimit la el: readus neschimbat (commit `4061b67` din emilkowalski/skills, cu `LICENSE`, MIT) în `chore/restante-dupa-x1`.
6. ✅ **Paginile web refăcute (14.11.2026, `chore/restante-dupa-x1`, `backend/polygraph/share/`):**
   - **fișa pacientului** (`templates/page.html`, `view.py`, `static/share.css`, `static/share.js`): rezumatul în 4 cifre mari, posologia în cuvinte (`plain_posology`: „1-0-1” → „1 dimineața, 1 seara”), detaliile tehnice (DCI, ATC, mecanism, sursa completă, analogia de clasă) după butonul „i” și cele 22 de alerte moderate strânse sub „Arată cele 22 de alerte”;
   - **pagina de prezentare** la `/` (`templates/home.html`, în locul răspunsului text simplu): cum funcționează, rolurile (pacienți, familii, medici de familie), ce verificăm, „inteligența artificială doar la margini” și adresa serverului pentru aplicație, pe care o deschide QR-ul din `make demo`;
   - **logo-ul și favicon-ul** (`static/logo.svg`): iconița din `app/PolyGraph/Assets.xcassets/AppIcon` redesenată vectorial, cu varianta dark;
   - **portalul medicului** (`templates/portal.html`, `templates/login.html`, `portal_summary` în `view.py`): data, 4 cifre pentru toți pacienții, grupurile „De revizuit” / „Fără nimic urgent”, cardul „Adăugați un pacient” și autentificarea ca un card centrat cu logo-ul.

Legendă: ⬜ neînceput · 🔄 în lucru · ✅ gata · ⚠️ blocat / tăiat

### Fazele, în ordine

| Faza | Cine | Ore de lucru | Ceas (orientativ) | Status | Ce iese |
|---|---|---|---|---|---|
| Pregătirea (secțiunea 10) | amândoi | înainte de start | până vineri | 🔄 | date, reguli YAML, conturi; rămân cutiile, rețeta tipărită, transcrierile, cablurile |
| **P0** repo, contracte, mock | amândoi | W0–W1.5 | V 18:00–19:30 | ✅ | `contracts/`, mock server, Makefile, CI, proiectul Xcode pe ambele iPhone-uri |
| **S0** | amândoi | W1.5 | V 19:30 | ✅ | contracte în `main`, mock pornit, Xcode pe ambele telefoane |
| A1 schelet iOS, tokeni, client API | Dev A | W1.5–W4 | V 19:30–22:00 | ✅ | app pe mock, pe ambele iPhone-uri (`make check-ios` verde, 18 teste) |
| B1 ingestia `kb.sqlite` + potrivirea | Dev B | W1.5–W8 | V 19:30–02:00 | ✅ | `make kb`, substanțele demo găsite |
| Q0 infrastructura de review | agent (worktree) | în paralel cu A2 | V seara | ✅ | `make review Q=…` ([PR #31](https://github.com/VladimirTM/PolyGraph/pull/31)); `TOUR=EdgeCaseTour` din Q3 |
| A2 scanarea (DataMatrix, poză, rețetă, confirmare) | Dev A | W4–W8 | V 22:00–02:00 | 🟡 | `make check-ios` verde, merge pe iPhone cu cutiile de test; rămân cutiile fizice în sală (T-A2-03) |
| B2 motorul de interacțiuni + graful | Dev B | W4–W12 | V 22:00–S 13:00 | ✅ | golden test = `expected_alerts.json` |
| **S1** | amândoi | W8 | S 02:00 | ✅ | trecut de facto (14.11.2026), fără review Q |
| Q1 review (noaptea) | agent | somn | S 02:00–09:00 | ⬜ | `docs/reviews/Q1.md`, triere 10 min |
| A3 medicamente, alerte, graf | Dev A | W8–W12 (+ integrare W12–W14) | S 09:00–16:00 | ✅ | modul aparținător; `make check-ios` verde, graful pe iPhone fără internet în 427 ms; „Arată medicului” (QR) rămâne pentru A6 |
| B3 extracția (OCR → catalog, GS1, cache) | Dev B | W12–W14 | S 14:00–16:00 | ✅ | `/scan` real |
| **S2** + Q2 | amândoi | W14 | S 16:00 | ✅ | fluxul real cap-coadă; trecut de facto (14.11.2026), fără review Q |
| A4 modul senior | Dev A | W14–W19 | S 16:00–21:30 | ✅ | Acum, Ziua de azi, „Am luat”, TTS, notificări; `make check-ios` verde, încercat pe iPhone; „Spuneți-mi cum vă simțiți” vine cu A5 |
| B4 solverul de program + B5 simptomele | Dev B | W14–W19 | S 16:00–21:30 | ✅ | `/schedule`, `/checkins` reale; B4 gata (`/schedule`, `/doses`), B5 gata (`/checkins`, `/feed`); X1 gata (PR #30); Whisper rămâne condițional |
| **S3** (MVP complet) | amândoi | W19 | S 21:30 | ✅ | trecut de facto (14.11.2026), fără review Q |
| A5 check-in vocal + Noutăți | Dev A | W19–W23 | S 21:30–D 02:00 | ✅ | `make check-ios` verde, încercat pe două iPhone-uri; X1 merge fără card (backend, PR #30), `reply_text` e citit cu voce |
| B6 portalul medicului de familie + tipărire | Dev B | W19–W23 | S 21:30–D 02:00 | ✅ | portalul real (`/portal`): login cu cod, lista pacienților, fișa cu decizie + notă → alertă + Noutăți, tipărire în 2 pagini A4, QR care adaugă pacientul; `/graph?embed=1`; T-B6-04 încercat pe iPhone și la zoom 200% (14.11.2026) |
| Q3 review (noaptea) | agent | somn | D 02:00–08:00 | ✅ | rulat ziua, pe 14.11.2026 ([PR #32](https://github.com/VladimirTM/PolyGraph/pull/32), `docs/reviews/Q3.md`): 1 blocker, 12 major, 15 minor, 13 polish; reparațiile în etapele Q3F0–Q3F6 (după QA) |
| A6 QR, modul demo · B7 demo hardening | A · B | W23–W24.5 | D 08:00–09:30 | 🔄 | B7 gata: `make demo`, `make demo-check` verde, istoricul demo, `/demo/missed-dose`. A6 gata (PR #25): QR pentru medic (aparținător + pacient), rețeta ORL și doza ratată în modul demo, iconița, trecerea de accesibilitate, T-A6-01/02 verzi. T-B7-06 (Wi-Fi oprit) încercat pe 14.11.2026. Q3F0, Q3F2 și Q3F1 gata (14.11.2026); Q3F4 implementat (de verificat pe simulator); rămâne Q3F3 înainte de S4 |
| **S4** feature freeze + Q4 | amândoi | W24.5 | D 09:30 | ⬜ | după S4 nu se mai scrie cod nou |
| D1 integrare, repetiții, video de rezervă | amândoi | W24.5–W27.5 | D 09:30–12:30 | ⬜ | |
| D2 pitch, submit | amândoi | W27.5–W30 | D 12:30–15:00 | ⬜ | |

### Sync point-urile

| Sync point | Când | Condiție de trecere | Dacă pică | Status |
|---|---|---|---|---|
| **S0** | W1.5 | contractele în `main`, `validate.py` verde, mock-ul răspunde la toate rutele, proiectul Xcode rulează pe ambele iPhone-uri | nimeni nu începe A1 / B1 până nu e gata | ✅ (13.11.2026) |
| **S1** | W8 | app-ul pe iPhone, pe mock: lista, alertele, citirea unui DataMatrix; `kb.sqlite` construit, toate substanțele demo găsite cu ATC | B scoate catalogul RO și lucrează doar cu lista curată a pacientului demo + DDInter | ✅ (14.11.2026, trecut de facto, fără review Q: Q0 nu e gata) |
| **S2** | W14 | fluxul real: poză cutie → confirmare → salvat → alertele pacientului demo = `expected_alerts.json` (R4) | extracția rămâne pe cache pentru cutiile demo | ✅ (14.11.2026, trecut de facto, fără review Q: Q0 nu e gata) |
| **S3** | W19 | programul real pe telefon, „Am luat” salvat, un check-in transcris pe telefon cu simptomele corelate | se taie bonusurile; A5 se reduce la check-in prin text + Noutăți | ✅ (14.11.2026, trecut de facto, fără review Q: Q0 nu e gata) |
| **S4** | W24.5 | toate feature-urile MVP rulează în scenariul demo de 3 ori la rând; Q4 fără blocker deschis | se taie din demo ce nu e stabil; nu se mai scrie cod nou | ⬜ |

Un sync point nu e trecut cât timp raportul Q aferent are un blocker cu decizia „acum” încă deschis. La fiecare sync point: merge pe `main`, `make demo-check` (R4), rulat pe iPhone.

### Calendarul pe ore, pe developer

**30 de ore de lucru**, numărate W0–W30 (ore de lucru efectiv, fără somn și mese lungi). Ceasul presupune start vineri 18:00 și se ajustează după agenda oficială; somnul e în același timp pentru amândoi (altfel unul îl blochează pe celălalt).

| Ore de lucru | Ceas (orientativ) | Dev A (aplicația iOS) | Dev B (date, motor, backend) |
|---|---|---|---|
| W0–W1.5 | V 18:00–19:30 | **P0 împreună:** repo, contracte, fixture-uri, proiectul Xcode | **P0 împreună:** contracte, mock server |
| W1.5–W4 | V 19:30–22:00 | A1 schelet + tokeni + modele + client API pe mock | B1 ingestia: catalog RO + DDInter → `kb.sqlite` |
| W4–W8 | V 22:00–02:00 | A2 scanarea: DataMatrix + poză, rețetă, sheet-ul de confirmare | B1 potrivirea; B2 motorul (DDI, dubluri) |
| **W8** | **S 02:00** | **S1** | **S1** |
| – | S 02:00–09:00 | 😴 · **Q1 rulează pe Mac-ul lui Dev A** | 😴 |
| W8–W8.2 | S 09:00 | **triere Q1 (împreună, 10 min)**; blocker-ele intră primele în blocul următor | |
| W8–W12 | S 09:00–13:00 | A3 medicamente, alerte (zoom), graf (WKWebView) | B2 motorul: food, Beers/STOPP, ACB, graful, rutele reale |
| W12–W14 | S 14:00–16:00 | integrarea scanării cu backend-ul real | B3 extracția: OCR → catalog + GS1 + cache demo |
| **W14** | **S 16:00** | **S2** | **S2** · pornește **Q2** pe Mac-ul lui Dev B (rulează în paralel ~45 min); triere la ~W15 |
| W14–W19 | S 16:00–21:30 | A4 modul senior: Acum, Ziua de azi, „Am luat”, TTS, notificări | B4 solverul de program; B5 simptome + corelare |
| **W19** | **S 21:30** | **S3 (MVP complet)** | **S3** |
| W19–W23 | S 21:30–02:00 | A5 check-in vocal (pe telefon) + Noutăți | B6 portalul medicului de familie + versiunea de tipărit |
| – | D 02:00–08:00 | 😴 · **Q3 rulează pe Mac-ul lui Dev A** | 😴 |
| W23–W24.5 | D 08:00–09:30 | triere Q3 (15 min); A6 QR, modul demo; fix-urile blocker din Q3 | B7 demo hardening; fix-urile blocker din Q3 pe backend |
| **W24.5** | **D 09:30** | **S4 feature freeze** | **S4 feature freeze** |
| W24.5–W27.5 | D 09:30–12:30 | **D1 împreună:** Q4 (primele 45 min, pe Mac-ul lui Dev B) în paralel cu repetițiile pe iPhone; blocker-ele din Q4; video de rezervă | **D1** |
| W27.5–W30 | D 12:30–15:00 | **D2:** slide-uri, submit, buffer | **D2** |

---

Planul are cinci părți:

- **Fazele și sync point-urile (secțiunea de mai sus):** ce urmează și unde suntem.
- **Ce construim (secțiunile 1–2):** feature-urile, cu ce intră sigur în demo (MVP) și ce e bonus; arhitectura, sursele de date și designul (2.4, după skill-ul `apple-design`).
- **Cum lucrăm în paralel (secțiunile 3 și 5):** împărțirea muncii și contractele comune (sursa de adevăr dintre cei doi). Secțiunea 4 a fost mutată sus.
- **Etapele cu prompturi de implementare (secțiunea 6):** fiecare etapă are responsabil, durată, checklist, un prompt care se dă ca atare unui agent de cod și teste de verificare. După fiecare milestone, un agent separat verifică aplicația pe simulator și raportează bug-uri și probleme de UI/UX (etapa Q).
- **Demo, pitch, riscuri, pregătirea dinainte (secțiunile 7–10).**

> **Regula de aur a produsului:** în fluxul normal nu rulează niciun LLM: textul îl citește OCR-ul de pe telefon, vocea o transcrie telefonul, iar potrivirea în catalog, simptomele, interacțiunile și programul sunt deterministe. Un LLM (Gemini, tier gratuit) intervine doar ca rezervă, când potrivirea eșuează, și rezultatul lui trece prin aceleași verificări. **Dacă există o interacțiune, cât de gravă e și ce se recomandă vin exclusiv din baze de date și reguli deterministe**, cu sursa afișată lângă fiecare alertă. Asta e argumentul tehnic principal la juriu: „fără halucinații în decizia medicală”.

> **Regula de aur a siguranței:** aplicația nu spune niciodată „opriți medicamentul X” și nu schimbă doze. Spune „discutați cu medicul de familie”, iar alertele grave merg la aparținător și la medicul de familie (portalul), nu doar la pacient.

---

## 0. Cum se folosește documentul

- Etapele au prefixele **P** (împreună), **A** (Dev A: aplicația mobilă), **B** (Dev B: date, motor, backend), **Q** (agentul de review pe simulator, după fiecare milestone), **D** (împreună, demo).
- **Contractele (secțiunea 5) sunt sursa de adevăr.** Se scriu în `contracts/` la P0 și se schimbă doar cu acordul amândurora (un mesaj pe chat ajunge; la hackathon nu așteptăm review formal, dar schimbarea de contract se face într-un commit separat, înaintea codului).
- **Fixture-ul pacientului demo** (`contracts/fixtures/demo_patient.json` + `expected_alerts.json`) e testul de acceptare comun: A construiește UI-ul pe el din prima oră (prin serverul mock), B îl folosește ca test golden pentru motor.
- **W0** = începutul lucrului. Calendarul numără **ore de lucru** (W0–W30), nu ore de ceas; orele de ceas din tabel presupun start vineri 18:00 și se ajustează după agenda oficială.

### Git workflow (variantă de hackathon)

Aceleași reguli ca la NeuroTrack, cu pașii lenți scoși:

1. **Niciodată direct pe `main`.** Branch scurt per etapă: `feature/<etapa>-<descriere>` (ex. `feature/b2-engine`, `feature/a3-alerts`). Cei doi lucrează în foldere diferite (`app/` vs `backend/`), deci conflictele sunt rare.
2. **Commit-uri mici**, un rând în engleză la imperativ, ≤ 72 caractere, fără punct final, linie goală, `Co-authored-by` = celălalt membru. **Fără co-author sau mențiuni AI** în commit-uri, PR-uri sau cod.

   | `git config user.name` | Linia de co-author |
   |---|---|
   | `VladimirTM` | `Co-authored-by: Remetan Mihnea-Florin <mihnearemetan@gmail.com>` |
   | Mihnea (`Remetan Mihnea-Florin`) | `Co-authored-by: VladimirTM <vladimirghimpau@gmail.com>` |

   (Dacă echipa diferă de NeuroTrack, se actualizează tabelul și hook-ul la P0.)
3. **PR cu `make check` verde, merge imediat** (squash), fără să aștepți review, **cu excepția** schimbărilor în `contracts/`, care se anunță celuilalt înainte.
4. **Merge pe `main` cel puțin la fiecare sync point**; `main` trebuie să fie oricând demonstrabil.

### Gate-ul rapid (`make check`, < 2 min)

| Nivel | Ce rulează | Când |
|---|---|---|
| **R1** contracte | `python contracts/validate.py` (exemplele și fixture-urile trec schemele; `openapi.yaml` valid) | fiecare PR |
| **R2** static | `ruff check`, `ruff format --check`; build-ul iOS fără erori (`xcodebuild build`) | fiecare PR |
| **R3** unit | `pytest backend/` (inclusiv golden-ul motorului pe pacientul demo); `make check-ios` = `xcodebuild test` pe simulator (Swift Testing, doar logică: GS1, momentul curent, guard, decodarea contractelor) | fiecare PR (iOS: local, pe Mac; CI rulează doar contractele și Python) |
| **R4** demo e2e | `make demo-check`: backend pornit, scenariul demo rulat prin API (scan cu răspunsuri cache, analiză, program, check-in) și comparat cu `expected_*.json` | la fiecare sync point și înainte de pitch |
| **R5** review pe simulator | `make review Q=QN` + raportul agentului de review (etapa Q) | după S1, S2, S3, S4 |

Regulă: un bug găsit în demo primește întâi un test (sau o intrare în `expected_*.json`), apoi fix-ul.

### Cum lucrați cu agenții (nimeni nu scrie Swift de mână)

- **Bucla de verificare a agentului:** după fiecare modificare, agentul rulează `xcodebuild build` (și `make check-ios` pentru teste) și repară singur erorile de compilare. Nu predă niciodată cod care nu compilează. Un task se dă în bucăți mici (un ecran, o funcție), nu „fă tot A3”.
- **Verificarea după milestone:** după S1–S4, o sesiune nouă de agent rulează aplicația pe simulator, trece prin toate ecranele în 5 variante de afișare și scrie un raport cu bug-uri, inconsistențe și îmbunătățiri (etapa Q). Q1 și Q3 rulează peste noapte, cât dormiți.
- **Ce agentul nu poate verifica:** camera și scanerul (VisionKit), microfonul și recunoașterea vocală, citirea vocală, notificările, haptic-ul și animațiile reale nu merg pe simulator (pe simulator, etapa Q le înlocuiește cu intrări simulate, deci verifică tot ce e după ele). Le verifică omul, rulând din Xcode pe iPhone (⌘R), apoi dă agentului ce a văzut: text, o captură de ecran sau eroarea din consola Xcode. De aceea fiecare sync point include „rulat pe iPhone”.
- **Ce rămâne manual:** semnarea (Team-ul, Developer Mode pe telefon, „Trust” la prima rulare) și instalarea pe telefon. Se fac în prima oră (P0), nu la S1.
- **Reguli în `AGENTS.md` / `CLAUDE.md`:** nu edita `project.pbxproj`; fără dependențe externe (nici SPM); la o eroare repetată de două ori, schimbă abordarea (componentă de sistem mai simplă), nu insista; nu scrie animații proprii unde există componentă de sistem (2.4).
- **Conturile și cine le folosește** (niciun API plătit; abonamentele sunt doar pentru agenții de cod):

  | Agent | Cont | Folosit pentru |
  |---|---|---|
  | Claude Code | Claude Pro, câte unul fiecare | agentul principal: Dev A pe aplicația iOS, Dev B pe motor, potrivire și backend |
  | Codex CLI | ChatGPT Plus | rezerva lui Dev A când Claude atinge limita de 5 h; task-uri iOS mici și bine delimitate |
  | Gemini CLI | Google AI Pro | rezerva lui Dev B (scripturi de date, teste Python, CSS-ul portalului) și **agentul de review** din etapa Q (alt furnizor = verificare cu adevărat independentă, iar limitele Claude rămân pentru cod) |
  | Gemini API, tier gratuit | cheie din Google AI Studio | în aplicație, doar ca rezervă la scanare și la simptome |

  Regulile: (1) conturile ChatGPT Plus și Google AI Pro le ține pe Mac-ul lui fiecare cel care le deține, dar oricine le poate folosi când îi expiră fereastra Claude; (2) când un agent atinge limita, task-ul continuă pe celălalt agent cu același prompt din plan și cu `git diff` ca punct de pornire, nu se așteaptă resetarea; (3) task-urile mari (A3, A4, B2) se încep cu Claude la începutul unei ferestre noi de 5 h; (4) nimeni nu pune o cheie de API în variabilele de mediu ale Claude Code (`ANTHROPIC_API_KEY`), ca să nu se factureze pe API.
- **Ce trebuie să înțelegeți totuși:** structura folderelor, ce face fiecare ecran și unde sunt tokenii de design. Atât ca să puteți spune agentului „schimbă X în Y” cu precizie și ca să răspundeți la întrebări la pitch.


---

## 1. Ce face aplicația: feature-urile

### 1.1 Persoane și roluri

| Rol | Cine e | Ce vede |
|---|---|---|
| **Pacientul** | vârstnic cu 5–10 medicamente de la medici diferiți | „Modul senior”: doar programul de azi, poza cutiei la fiecare doză, buton mare „Am luat”, asistent vocal |
| **Aparținătorul** | fiica / fiul, adesea în alt oraș | tot: lista, graful, alertele detaliate, aderența, check-in-urile vocale; primește alertele grave |
| **Medicul de familie** | cabinetul | portal web cu lista pacienților care i-au partajat tratamentul (prin QR); pe fiecare alertă decide „Menține / Modific la consultație / Trimit la specialist” + notă, care ajung la familie; „Reconcilierea medicației” de tipărit |

**Cum circulă datele între roluri (clarificat pe 14.11.2026; de spus la fel în pitch și la întrebările juriului):**
- **Cine folosește ce.** Pacientul și familia folosesc aplicația iOS. Medicul de familie nu instalează nimic: portalul e o pagină web (`/portal`), deschisă în browser pe calculatorul din cabinet sau pe telefon. Aplicația și portalul vorbesc cu același server; la hackathon, serverul e laptopul care rulează `make demo` (pe el portalul e la `http://localhost:8000/portal`, pe celelalte dispozitive din același Wi-Fi la adresa afișată de `make demo`). Într-un produs real, serverul ar avea o adresă publică.
- **Datele ajung pe server din aplicație, nu prin QR.** Scanarea cutiilor și rețetelor, „Am luat” și check-in-urile vocale se salvează imediat pe server.
- **Codul QR e o invitație, nu un transfer de date.** Familia (sau pacientul) îl generează din aplicație cu „Arată medicului”; conține doar linkul `/share/{token}`. Medicul îl scanează cât timp e autentificat în portal (altfel i se cere întâi codul de acces), iar pacientul intră în lista lui și rămâne acolo.
- **Expirarea.** Tokenul din QR e valabil 72 de ore (`SHARE_TTL`): după aceea nu mai poate adăuga pacientul la nimeni, dar medicul care l-a scanat deja îl păstrează. Fiecare medic vede doar pacienții adăugați de el.
- **După adăugare, medicul vede mereu datele la zi** (medicamente noi, alerte, check-in-uri), fără un QR nou. Decizia și nota lui pe o alertă ajung înapoi la familie, pe alertă și în Noutăți.
- **Autentificarea medicului: cod de acces, fără cont.** În prototip există un singur medic, „dr. Elena Popa” (`doc_demo`), creat de server la pornire cu codul `medic-demo` (sau `PG_DOCTOR_CODE`); sesiunea ține 12 ore (`SESSION_TTL`). Conturile pe medic (înregistrare, parolă, eventual verificarea parafei) sunt pasul de după hackathon.

### 1.2 Feature-uri MVP (intră sigur în demo)

| # | Feature | Ce face concret | Owner |
|---|---|---|---|
| F1 | **Scanare cutie / rețetă** | Poză → OCR-ul Apple citește textul pe telefon → potrivire deterministă cu nomenclatorul românesc (nume comercial, concentrație, DCI) și parserul de posologie („1-0-1”) → ecran de confirmare cu câmpurile editabile și un indicator de încredere; Gemini (gratuit) doar când potrivirea eșuează | A (OCR, UI), B (potrivirea) |
| F2 | **Codul DataMatrix de pe cutie** | Codul 2D obligatoriu în UE (GS1): GTIN, lot, **data expirării**, serie. Citit pe telefon; a doua scanare a aceleiași cutii e instantă (GTIN → produs memorat); alertă la medicament expirat | A (scanner), B (parser GS1) |
| F3 | **Graful terapeutic** | Pacient → medicamente → substanțe active → clase ATC → alimente / simptome, cu muchii roșii / portocalii pentru conflicte; vizualizare interactivă (Cytoscape.js) | B (graf + pagina), A (îl afișează în app) |
| F4 | **Motorul de interacțiuni (determinist)** | Drug–drug (cu severitate), drug–food, **dubluri terapeutice** (aceeași substanță sub două nume comerciale, două AINS de la medici diferiți), cu sursa fiecărei alerte | B |
| F5 | **Verificările specifice vârstnicilor** | Subset de criterii Beers 2023 / STOPP v3 (benzodiazepine, AINS cronic, amitriptilină, IPP > 8 săptămâni etc.) și **scorul anticolinergic (ACB)** cu prag de risc (confuzie, căderi) | B |
| F6 | **Programul zilnic optimizat** | Solver de constrângeri: pe stomacul gol / cu masa / seara, separări minime (levotiroxină ↔ calciu 4 h), minimizează numărul de „momente” pe zi; fiecare doză are motivul afișat | B (solver), A (calendar) |
| F7 | **Modul senior** | Ecranul „Acum”: ce pastilă, cu poza cutiei, câte bucăți, instrucțiunea („pe stomacul gol”); „Am luat” / „Am sărit”; citire cu voce (TTS, română) | A |
| F8 | **Check-in vocal zilnic** | „Cum vă simțiți azi?” → transcriere pe telefon (recunoașterea vocală iOS, română), cu textul afișat în timp ce vorbește → simptome dintr-un vocabular fix → corelare deterministă cu efectele adverse și interacțiunile existente → escaladare la aparținător dacă e cazul | A (UI audio), B (pipeline) |
| F9 | **Aparținătorul** | Feed: alerte noi, doze ratate, check-in-uri cu simptome legate de medicamente; în demo rulează pe al doilea telefon | A |
| F10 | **Portalul medicului de familie** | login cu cod; lista pacienților (cei cu alerte nerevizuite și semnalele familiei sus); fișa cu medicamentele, graful, alertele, aderența, check-in-urile; decizie + notă pe alertă → alertă + Noutăți; QR cu token de 72 h care adaugă pacientul în listă; „Reconcilierea medicației” de tipărit | B (portalul), A (QR) |

### 1.3 Bonus (doar dacă sync point-ul S3 e atins la timp; la 30 h, realist doar X2, ca scenariu din modul demo)

| # | Feature | De ce e bun în pitch |
|---|---|---|
| X1 | **„Pot să iau…?”** prin voce („Pot să iau un Algocalmin?”) → același motor rulat ca „what-if” pe regimul curent → răspuns vocal | arată că motorul e reutilizabil; foarte natural pentru vârstnici |
| X2 | **Scenariul „medic nou”**: rețetă nouă scanată → alerta critică apare live pe telefonul aparținătorului și în portalul medicului de familie | momentul „wow” din demo (se pregătește oricum ca script, X2 e doar varianta live, fără refresh) |
| X3 | Expirări și stoc („mai aveți pastile pentru 3 zile”) din numărul de comprimate de pe cutie | utilitate zilnică |
| X4 | Explicația în limbaj simplu, reformulată de LLM **strict din câmpurile alertei** (cu sursa) | accesibilitate |

**Decizii pentru bonusuri (14.11.2026, cu o zi de lucru rămasă):**
- **X1: da, varianta prudentă, întâi pe backend, cu răspunsul pe severități (revizuit pe 14.11.2026).** Răspunsul nu spune niciodată „puteți lua”: motorul vede doar interacțiunile din baza de date, iar lipsa unei alerte nu înseamnă că medicamentul e sigur (ar contrazice și 1.4: nu diagnosticăm, nu schimbăm doze). Prima variantă trimitea aproape orice întrebare la medic: cu 8 medicamente, aproape orice medicament nou are o interacțiune moderată, deci oboseală de alerte. Varianta nouă diferă după cea mai gravă alertă nouă din what-if (fără alimente). Farmacistul nu mai apare (pagina lui a ieșit din produs la B6, PR #23); actorii sunt pacientul, aparținătorul și medicul de familie:
  - **grav** (critical / major): „Aspirin și Sintrom împreună cresc riscul de sângerare. Nu luați Aspirin până nu vă răspunde medicul de familie. I-am trimis întrebarea lui și Anei.” (numele reale, motivul din alertă, aparținătorul la dativ) + eveniment în Noutăți;
  - **moderat** (și minor): „Paracetamol are o interacțiune moderată cu Sintrom. Am notat întrebarea; Ana și medicul de familie o văd în fișa dumneavoastră.”; fără eveniment;
  - **nimic găsit** (toate substanțele legate la DDInter): „Nu am găsit o interacțiune cunoscută cu medicamentele dumneavoastră.”; fără eveniment;
  - **fără date** (o substanță fără `ddinter_id`, ex. Algocalmin / metamizol): „Nu am date despre Algocalmin. I-am trimis întrebarea medicului de familie.” + eveniment în Noutăți;
  - medicamentul de pe listă și cel necunoscut își păstrează răspunsurile.
  Regula de siguranță: nimic despre tratamentele existente („opriți”, „nu mai luați”, doze); „Nu luați X până nu vă răspunde medicul” e permis doar pentru medicamentul NOU întrebat. **Bucla:** pentru grav și „fără date”, `POST /checkins` adaugă un `FeedEvent` `type = "checkin"`, `checkin_id` = check-in-ul, `med_ids` = medicamentele implicate de pe listă, `severity` = a alertei (null pentru „fără date”), titlu „Maria a întrebat dacă poate lua Aspirin” (fără „: ”, ca aplicația să nu-l despartă în chip-uri), corpul cu interacțiunea și sursa. `escalate` rămâne false (o întrebare nu e un simptom). Medicul vede întrebarea și răspunsul dat în fișa din portal, la check-in-uri, cu „semnalat familiei” la cele trimise în Noutăți (roșu doar la grav). Pentru pitch: „Pot să iau o aspirină?” → grav, apare în Noutăți. Aspirin 500 mg (OTC) e în `kb/ro_products_extra.csv`.
- **X2: acoperit.** Din B7, alertele grave noi după o rețetă (Fromilid) ajung în Noutăți pe telefonul aparținătorului și în portalul medicului; rămâne doar să fie arătat în scenariu (2:10).
- **X3 (stocul de pastile): sărit.** Cere ecrane noi în app, iar app-ul e ocupat cu fix-urile din Q.
- **X4 (explicații reformulate de LLM): sărit.** Ar contrazice mesajul din pitch, „LLM doar la margini”.

### 1.4 Ce NU face (scris explicit în pitch și în aplicație)

- Nu pune diagnostice, nu schimbă și nu oprește medicamente, nu recomandă doze.
- Nu înlocuiește medicul de familie; îi aduce informația pe care altfel n-o vede (OTC-uri, rețete de la 5 specialiști).
- Nu e dispozitiv medical certificat (prototip; poziționarea de reglementare e în secțiunea 9).

---

## 2. Arhitectura și sursele de date

### 2.1 Arhitectura

```text
┌──────────────────────────── App iOS (SwiftUI, iOS 18+) ───────────────────────┐
│ Mod senior: Acum · Ziua de azi · Check-in vocal                               │
│ Mod aparținător: Medicamente · Alerte · Graf (WKWebView) · Noutăți · Scanare  │
│ VisionKit (DataMatrix + poză) · VNDocumentCamera (rețetă) · Vision (OCR)      │
│ Speech (ro-RO)                                                                │
│ AVSpeechSynthesizer (ro-RO) · notificări locale · QR (CoreImage)              │
└───────────────┬───────────────────────────────────────────────────────────────┘
                │ HTTP JSON (contracts/api/openapi.yaml)
┌───────────────▼──────────────────────── FastAPI (Python 3.12) ─────────────────┐
│ extract/   text OCR (de pe telefon) → potrivire în nomenclator (rapidfuzz) +    │
│            posologie; Gemini (tier gratuit) doar dacă potrivirea eșuează       │
│            DataMatrix: parser GS1; zxing-cpp pe server ca fallback              │
│ engine/    DDI · DFI · dubluri · Beers/STOPP · ACB · expirare → Alert[]          │
│ graph/     NetworkX → JSON Cytoscape                                            │
│ schedule/  solver cu constrângeri (backtracking)                                │
│ voice/     text transcris pe telefon → potrivire pe sinonime (vocabular fix)    │
│            → corelare; Gemini doar ca rezervă                                  │
│ share/     portalul medicului (Jinja + Cytoscape.js), decizii, tipărire        │
│ store      SQLite (app.sqlite: pacienți, medicamente, doze, check-in-uri)        │
│ kb         SQLite read-only (kb.sqlite: produse RO, substanțe, interacțiuni, reguli) │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**De ce iOS nativ:** tot ce are nevoie aplicația vine din SDK (scanarea codurilor și a documentelor, recunoașterea și sinteza vocală în română, notificări, WebView, QR), deci zero pachete externe și zero cod de legătură; skill-ul de design se aplică aproape direct (2.4); recunoașterea vocală pe telefon scoate Whisper de pe drumul critic și e un argument de confidențialitate în pitch.

**De ce așa:** NetworkX în memorie în loc de Neo4j (zero infrastructură, graful unui pacient are zeci de noduri; Neo4j nu aduce nimic la scara asta și costă ore de setup). Graful se exportă oricum în format Cytoscape, deci vizualizarea e aceeași. Neo4j rămâne o linie în „next steps” din pitch, pentru graful populațional.

### 2.2 Sursele de date

| Sursă | Ce luăm | Licență / observații |
|---|---|---|
| **DDInter 2.0** (ddinter2.scbdd.com) | fișierele descărcabile (8 CSV-uri, pe grupe ATC; descărcate în `kb/raw/ddinter/`, vezi README-ul de acolo): 160.235 de perechi unice între 1.939 de substanțe, **doar cu nivelul** (Major / Moderate / Minor / Unknown), fără mecanism și fără recomandări. Interacțiunile cu alimentele, dublurile și textele explicative se iau de pe site, doar pentru substanțele folosite, în `kb/curated_ddi.csv` și `kb/curated_dfi.csv`. **Atenție:** acenocumarolul (Sintrom) are toate cele 116 interacțiuni cu nivelul `Unknown` | Datele descărcabile sunt CC BY-NC-SA 4.0: OK pentru hackathon, **nu** pentru produs comercial (vezi riscurile) |
| **Catalogul Public național al prețurilor maximale ale medicamentelor** (Ministerul Sănătății, Excel din 04.08.2026, descărcat în `kb/raw/ro/`, vezi README-ul de acolo) | 6.485 de produse, 4.736 de denumiri, 1.294 de DCI-uri, cu denumire, formă, concentrație, DCI (latină) și cod ATC (lipsă doar la 6). **Nu conține OTC-urile și suplimentele** (Nurofen, Calciu + D3): acestea se adaugă de mână în `kb/ro_products_extra.csv` | public; dicționarul pentru potrivirea textului de pe cutii |
| **AGS Beers Criteria 2023** și **STOPP/START v3** | ~25 de reguli pentru medicamentele uzuale în România, scrise de mână în `kb/rules/elderly.yaml` | se citează sursa în fiecare regulă |
| **Anticholinergic Burden (ACB) scale** | scorul 1–3 pentru ~50 de substanțe, în `kb/rules/acb.yaml` | prag de afișare: total ≥ 3 |
| **RCP-urile (SmPC) produselor demo** | regulile de orar (stomac gol, separări) și efectele adverse frecvente, în `kb/rules/timing.yaml` și `kb/rules/adverse_effects.yaml` | curate manual doar pentru substanțele din demo + cele mai comune ~30 |

**Nu folosim** API-ul de interacțiuni RxNav / RxNorm: NLM l-a oprit pe 2 ianuarie 2024 (restul RxNorm funcționează, dar e centrat pe SUA). **Nu folosim** DrugBank complet: licența academică cere aprobare și nu se poate redistribui; nu e ceva de obținut într-un weekend.

**Cheia de legătură:** codul **ATC nivel 5** (ex. `C08CA01` amlodipină) e prezent și în catalogul românesc, și în DDInter. Combinațiile fixe (un singur ATC pentru două substanțe) se despart după DCI-ul compus („LOSARTANUM + HYDROCHLOROTHIAZIDUM”) și potrivire fuzzy latină → engleză, cu override-uri manuale în `kb/overrides.csv`.

### 2.3 Unde intră LLM-ul și unde nu

| Pas | LLM? | Garda |
|---|---|---|
| Poză → text | **nu**: OCR-ul Apple, pe telefon | – |
| Text → produs, concentrație, posologie | **nu** (potrivire în catalog + parser); Gemini doar ca rezervă, când potrivirea eșuează | și rezultatul Gemini trebuie să se potrivească în nomenclator; altfel `needs_review = true` și utilizatorul confirmă |
| Câmpuri → substanțe active | **nu** | potrivire în `kb.sqlite` (exact → fuzzy cu prag → override) |
| Există interacțiune? Ce severitate? | **nu** | DDInter + reguli YAML |
| Programul zilei | **nu** | solver determinist |
| Transcriere voce | recunoașterea vocală iOS, pe telefon (Whisper doar ca rezervă) | – |
| Transcriere → simptome / intenție | **nu** în mod normal (potrivire pe sinonimele din `contracts/symptoms.md`); Gemini doar ca rezervă, constrâns la același vocabular | coduri necunoscute sunt respinse |
| Simptom ↔ medicament | **nu** | `adverse_effects.yaml` + alertele existente |
| Text simplu pentru pacient (X4) | da, opțional | primește doar câmpurile alertei; textul are mereu sursa și butonul „Vezi detaliile” |

### 2.4 Designul: skill-ul `apple-design`, aplicat în SwiftUI

**Unde stă skill-ul.** `.claude/skills/apple-design/SKILL.md`, copiat neschimbat din [emilkowalski/skills](https://github.com/emilkowalski/skills/blob/main/skills/apple-design/SKILL.md) (commit `4061b67`, licență MIT, cu fișierul `LICENSE` lângă el). `AGENTS.md` și `CLAUDE.md` cer ca **orice etapă care atinge UI-ul** să citească întâi skill-ul și apoi `docs/DESIGN.md` (secțiunea aceasta).

**Skill-ul e scris pentru web; SwiftUI are nativ aproape tot ce descrie.** Portalul medicului de familie (B6) aplică skill-ul direct, în CSS. În aplicație, regula e: **folosește componenta de sistem care face deja ce cere skill-ul și scrie cod propriu doar unde nu există**. Tabelul de mai jos e traducerea; ce e în coloana a doua nu se reimplementează de mână.

| Skill | Ce folosim în SwiftUI (iOS 18+) |
|---|---|
| §1 răspuns la apăsare | `ButtonStyle` propriu: `configuration.isPressed` e `true` din momentul atingerii → `scaleEffect(0.97)` instant |
| §3 animații întreruptibile | animațiile SwiftUI se pot redirecționa oricând și păstrează viteza la schimbarea țintei; nu folosim animații cu durată fixă pe elemente atinse |
| §4 spring-uri cu damping + response | `Animation.spring(response:dampingFraction:)`: exact parametrii lui Apple, fără conversie |
| §5–§6 viteza și proiecția impulsului | sheet-urile de sistem cu `.presentationDetents`; pentru gesturi proprii, `DragGesture.Value.velocity` și `predictedEndTranslation` (proiecția e deja calculată de sistem) |
| §7 consistență spațială | `.matchedTransitionSource` + `.navigationTransition(.zoom(sourceID:in:))`: ecranul de detaliu crește din card și se întoarce în el, inclusiv la swipe interactiv |
| §9 rubber-band | `ScrollView` / `List` de sistem |
| §12 materiale | barele de navigare, tab bar-ul, toolbar-urile și sheet-urile de sistem primesc automat materialul versiunii curente de iOS și efectul de margine la scroll; pentru suprafețe proprii, `.background(.regularMaterial)` |
| §13 haptic sincronizat | `.sensoryFeedback(_:trigger:)` pe aceeași stare care schimbă vizualul |
| §14 Reduce Motion / Transparency / Contrast | `@Environment(\.accessibilityReduceMotion)`, `\.accessibilityReduceTransparency`, `\.colorSchemeContrast`; materialele de sistem se adaptează singure |
| §15 tipografie | stilurile de text de sistem (`.largeTitle`, `.title2`, `.body`…) au deja Dynamic Type și tracking pe dimensiune; dimensiunile proprii prin `@ScaledMetric` + `.font(.system(size:weight:))` |

#### 2.4.1 Cele opt principii, aplicate la PolyGraph

| Principiu (skill §16) | Ce înseamnă concret aici |
|---|---|
| **Purpose** | Pacientul are **un singur ecran principal** („Acum”). Graful, sursele și severitățile există doar în modul aparținător și în portalul medicului de familie. |
| **Agency** | Fără dialoguri de confirmare pentru acțiuni reversibile: „Am luat” se poate anula 5 s. Confirmarea apare doar la ștergerea unui medicament. |
| **Responsibility** | Nicio formulare de tip „opriți”; microfonul și camera se cer la primul gest care are nevoie de ele, cu motivul spus în cuvinte; fiecare alertă își arată sursa; vocea se transcrie pe telefon. |
| **Familiarity** | Tipare iOS standard: titluri mari, sheet-uri, swipe-to-delete cu undo, înapoi din stânga, tab bar. Nimic inventat acolo unde iOS are deja un tipar. |
| **Flexibility** | Două moduri pentru două persoane; Dynamic Type până la mărimile de accesibilitate; VoiceOver; Reduce Motion; Increase Contrast; Bold Text. |
| **Simplicity** | Calea comună prima: în modul senior, trei acțiuni (Am luat / Mai târziu / Spuneți-mi cum vă simțiți). Detaliile (mecanism, sursă, ATC) sunt un nivel mai jos. |
| **Craft** | Spring-urile, spațierile și culorile vin din `Design/` (tokeni), nu sunt scrise de mână în ecrane. |
| **Delight** | Emoția țintă e **liniștea**: pentru Maria, „știu exact ce iau”; pentru Ana, „sunt la curent fără să fiu acolo”. Momentul de satisfacție e bifa care zboară în cronologia zilei după „Am luat”. |

#### 2.4.2 Deciziile specifice pentru vârstnici (unde ne abatem conștient de skill)

- **Fără acțiuni doar prin gest în modul senior.** Tremorul face swipe-urile și long-press-urile nesigure: totul e buton mare (≥ 72 pt înălțime, pe toată lățimea). Gesturile (swipe-to-delete, sheet-uri glisabile) există doar în modul aparținător.
- **Feedback instant, commit protejat.** Butonul se micșorează imediat la atingere (§1); acțiunea pornește la ridicarea degetului, iar a doua apăsare pe aceeași doză în următoarea secundă e ignorată (și backend-ul e idempotent pe doză).
- **Microfonul: atingere ca să pornească, atingere sau liniște ca să se oprească**, nu „țineți apăsat”. Oprire automată după 2 s de liniște sau 60 s.
- **Suprafețe opace în modul senior.** Materialele translucide rămân doar în chrome-ul de sistem al modului aparținător.
- **Fără roșu de alarmă pentru pacient.** Alertele grave se văd la Ana și la medicul de familie; Maria vede un card liniștit cu „Am anunțat-o pe Ana”.

#### 2.4.3 Tokenii (`app/PolyGraph/Design/`)

```swift
extension Animation {
    static let pgStandard = Animation.spring(response: 0.35, dampingFraction: 1.0) // apariții, layout, feed
    static let pgQuick    = Animation.spring(response: 0.25, dampingFraction: 1.0) // revenirea după apăsare
    static let pgMove     = Animation.spring(response: 0.40, dampingFraction: 1.0) // bifa care zboară
    static let pgFlick    = Animation.spring(response: 0.30, dampingFraction: 0.8) // doar după un gest cu impuls
}
```

- **Implicit fără overshoot** (`pgStandard`); bounce (`pgFlick`) doar după un gest cu impuls. Cu Reduce Motion, helper-ul `withPgAnimation(_:)` înlocuiește orice spring cu `.easeInOut(duration: 0.2)` și transformă tranzițiile spațiale în `.opacity`.
- **Spațieri:** 4 / 8 / 12 / 16 / 24 / 32; raze 12 (carduri) și 20 (carduri mari în modul senior); butonul senior 72 pt, cel de aparținător 50 pt.
- **Culori** în Asset Catalog, cu variante light / dark / contrast mare: fundal, suprafață, text primar / secundar, accent (teal liniștit), severitățile pentru aparținător (`critical` / `major` roșu de sistem, `moderate` portocaliu, `minor` gri, `info` albastru), `calmCard` pentru pacient (nisip cald). Severitatea e mereu însoțită de text, nu doar de culoare.
- **Tipografie:** stilurile de sistem peste tot. Excepții, cu `@ScaledMetric`: ora din „Acum” (64 pt, semibold, `.monospacedDigit()`), numele medicamentului în modul senior (28 pt, semibold), instrucțiunile în modul senior (22 pt). Fără `letterSpacing` manual: fontul de sistem aplică singur tracking-ul pe dimensiune.

#### 2.4.4 Consistență spațială și direcție (skill §7–§8)

- **Cardul de alertă → detaliul**: tranziție zoom din card (`.navigationTransition(.zoom)`), cu închidere interactivă înapoi în card.
- **Scanare → confirmare**: sheet de sistem (detent `.large`, cu fundalul întunecat de sistem, pentru că e sarcină blocantă). Ecranele împinse în stivă intră și ies pe dreapta (`NavigationStack`).
- **„Am luat”**: bifa se micșorează și se mișcă (`pgMove`, `matchedGeometryEffect`) spre punctul momentului din cronologia de sus, care se umple; cardurile ies în aceeași direcție.
- **Tab-ul Noutăți**: elementele noi apar sus cu `pgStandard` numai dacă lista e la început; altfel, o pastilă „3 noutăți ↑” (lista nu se mișcă sub degetul cuiva).

#### 2.4.5 Feedback multimodal (skill §13)

| Eveniment | Vizual | Haptic (`.sensoryFeedback`) | Sunet / voce |
|---|---|---|---|
| Atingere pe orice buton | scale 0.97 instant | – | – |
| DataMatrix citit | contur verde pe cod | `.impact(weight: .medium)` | – |
| „Am luat” confirmat | bifa zboară în cronologie | `.success` | TTS: următorul moment |
| Alertă nouă `critical` / `major` (la Ana) | card nou sus | `.warning` | notificarea sistemului |
| Eroare (scanare nereușită) | mesaj inline, sub buton | `.error` | – |

Vizualul, haptica și vocea pornesc din aceeași schimbare de stare. Fără haptic pe navigare sau pe scroll.

#### 2.4.6 Accesibilitate și orientare

- Ecranele se verifică în Xcode Previews la `dynamicTypeSize` `.large`, `.xxxLarge` și `.accessibility3`, în light și dark: nimic tăiat (cardurile cresc pe verticală).
- VoiceOver: fiecare card de doză e un singur element (`.accessibilityElement(children: .combine)`); butoanele au etichete de acțiune („Confirmă că ați luat Euthyrox, o pastilă”).
- **Patru tipuri de feedback** (skill §16): status („Citesc cutia…”), finalizare („Am salvat. 2 alerte noi”), avertizare (cutie expirată, înainte de salvare), eroare (inline, lângă câmpul greșit).
- **Etichete specifice**: tab-urile aparținătorului sunt „Medicamente”, „Alerte”, „Graf”, „Noutăți”. Modul senior nu are tab-uri: „Acum”, cu „Ziua de azi” un nivel mai jos.

#### 2.4.7 Bugetul de design la 30 h

Doar **tokenii + 3 interacțiuni lucrate**: butonul cu răspuns instant și guard, „Am luat” cu bifa care zboară, inelul de ascultare la microfon. Restul (sheet-uri, zoom, materiale, liste, rubber-band) sunt componente de sistem folosite corect, fără cod de animație propriu. Orice altă animație se adaugă doar dacă S3 a fost atins la timp.

---

## 3. Împărțirea muncii

| | **Dev A: aplicația mobilă** | **Dev B: date, motor, backend** |
|---|---|---|
| Deține | `app/` (proiectul Xcode) | `backend/`, `kb/`, `demo/` |
| Construiește | proiectul iOS, tokenii de design (2.4, `docs/DESIGN.md`), clientul API, scanarea (DataMatrix + poză + rețetă), confirmarea, medicamentele și alertele, graful în WKWebView, modul senior (Acum, program, TTS, notificări), check-in-ul vocal pe telefon, Noutăți, QR, modul demo | ingestia datelor, potrivirea în nomenclator, motorul de interacțiuni, verificările pentru vârstnici, graful, solverul de program, pipeline-ul de extracție, înțelegerea simptomelor + corelarea, portalul medicului de familie (și versiunea de tipărit), cache-ul pentru demo |
| Împreună | P0 (contractele), D1 (integrare, repetiții), D2 (pitch) | idem |

Granița dintre cei doi e formată din trei lucruri, toate în `contracts/`:
1. **API-ul HTTP** (`openapi.yaml`) și schemele JSON (`MedicationItem`, `Alert`, `Schedule`, `CheckIn`, `Graph`).
2. **Fixture-urile pacientului demo** și răspunsurile așteptate (`expected_alerts.json`, `expected_schedule.json`).
3. **Serverul mock** (`backend/mock_server.py`, scris de B la P0): servește fixture-urile pe toate endpoint-urile, ca A să nu aștepte nimic.

---

## 4. Calendar și sync points

Mutat la începutul documentului, în „Fazele de lucru și sync point-urile”, ca statusul să se vadă din prima.

---

## 5. Contracte v1 (se scriu în `contracts/` la P0)

### 5.1 Structura repo-ului

```text
polygraph/
  app/                    proiectul Xcode, SwiftUI (Dev A)
  backend/                FastAPI, uv (Dev B)
    polygraph/{api,extract,engine,graph,schedule,voice,share,store}/
    mock_server.py
    tests/
  kb/                     scripturile de ingestie + reguli YAML (Dev B); datele brute în kb/raw/ (gitignored)
    rules/{elderly,acb,timing,adverse_effects,food_aliases}.yaml
    overrides.csv
  contracts/
    api/openapi.yaml
    schema/{medication_item,alert,schedule,checkin,graph,extraction}.schema.json
    symptoms.md           vocabularul fix de simptome
    examples/
    fixtures/{demo_patient.json,expected_alerts.json,expected_schedule.json,checkin_demo.json}
    validate.py
  demo/                   pozele cutiilor demo, rețeta tipărită, răspunsurile LLM cache-uite, scriptul de demo
  docs/{PLAN.md,DESIGN.md,reviews/,pitch/}
  tools/review/            turul de review pe simulator (etapa Q)
  .claude/skills/apple-design/{SKILL.md,LICENSE}
  Makefile
```

### 5.2 `MedicationItem`

```json
{
  "id": "med_01",
  "source": "photo_box",
  "product": {
    "brand": "Sintrom",
    "strength_text": "4 mg",
    "form": "comprimat",
    "gtin": "05949...",
    "pack_size": 30,
    "expiry": "2027-05-31",
    "batch": "AB123"
  },
  "substances": [
    { "dci": "ACENOCUMAROLUM", "inn": "acenocoumarol", "atc": "B01AA07", "strength_mg": 4.0 }
  ],
  "dosage": {
    "raw": "1/2 cp seara",
    "pattern": { "morning": 0, "noon": 0, "evening": 0.5, "bedtime": 0 },
    "as_needed": false,
    "with_food": "any"
  },
  "prescriber": { "name": null, "specialty": "cardiologie" },
  "start_date": "2026-09-01",
  "end_date": null,
  "photo_url": "/media/med_01.jpg",
  "match": { "method": "exact_brand", "confidence": 0.98, "needs_review": false }
}
```

Reguli:
- `source` ∈ `photo_box`, `photo_rx`, `datamatrix`, `manual`, `voice`.
- `dosage.pattern` urmează notația românească „dimineața-prânz-seara(-culcare)”: „1-0-1” → `morning: 1, evening: 1`. Fracțiile (½, ¼) sunt permise.
- `with_food` ∈ `empty_stomach`, `before_meal`, `with_meal`, `after_meal`, `any`.
- `match.method` ∈ `gtin_cache`, `exact_brand`, `exact_dci`, `fuzzy`, `override`, `manual`. `needs_review = true` dacă `confidence < 0.85` sau orice substanță nu are `atc`.
- `end_date` setat pentru cure scurte (antibiotic 7 zile); după `end_date` medicamentul iese din analiză, dar rămâne în istoric.

### 5.3 `Alert`

```json
{
  "id": "al_ddi_med_01_med_02",
  "kind": "ddi",
  "severity": "major",
  "med_ids": ["med_01", "med_02"],
  "title": "Risc crescut de sângerare",
  "patient_text": "Două dintre pastile, luate împreună, pot crește riscul de sângerare. Am anunțat-o pe Ana.",
  "detail": "Acenocumarol + ibuprofen: AINS cresc riscul de hemoragie la pacienții anticoagulați.",
  "recommendation": "Discutați cu medicul cardiolog înainte de următoarea doză de ibuprofen. Nu opriți anticoagulantul fără acordul medicului.",
  "action": "contact_doctor",
  "route_to": ["caregiver", "doctor"],
  "source": { "db": "ddinter", "ref": "<id DDInter substanța A> – <id DDInter substanța B>", "url": null },
  "basis": "direct",
  "analogy": null,
  "status": "open",
  "resolution": null
}
```

Reguli:
- `kind` ∈ `ddi`, `food`, `duplicate`, `elderly_pim`, `anticholinergic`, `timing`, `expired`, `symptom`.
- `severity` ∈ `critical`, `major`, `moderate`, `minor`, `info`. Sursele, în ordinea priorității: (1) `kb/curated_ddi.csv` (verificat de mână pe site-ul DDInter / în RCP; aici se marchează și perechile „contraindicat” → `critical`, ex. simvastatină + claritromicină); (2) nivelul DDInter: `Major` → `major`, `Moderate` → `moderate`, `Minor` → `minor`; (3) **regula de clasă** pentru `Unknown`: dacă o substanță din aceeași clasă ATC nivel 4 are nivel pentru aceeași pereche (ex. acenocumarol `B01AA07` → warfarină `B01AA03`), alerta preia nivelul, cu `basis = "class_analogy"`, `analogy = { "via": "warfarină", "atc4": "B01AA" }` și textul „evaluat prin analogie cu warfarina (aceeași clasă); de confirmat de medicul de familie”; (4) altfel, perechea `Unknown` nu produce alertă (doar o muchie gri în graf).
- `basis` ∈ `direct`, `curated`, `class_analogy`; se afișează în detaliul alertei și în portalul medicului.
- Afișarea pentru aparținător: `critical` și `major` sus, una câte una; `moderate` **grupate și restrânse** într-un singur card („6 interacțiuni moderate, de discutat cu medicul de familie la următoarea vizită”); `minor` ascunse (vizibile doar în portalul medicului de familie). **Alertele `food` nu intră printre cardurile grave, indiferent de severitate:** se grupează într-un singur card „Mâncare și băutură” (ex. grepfrutul cu simvastatina, care în DDInter e `Major`), sub cardurile grave.
- `action` ∈ `contact_doctor`, `ask_doctor`, `separate_times`, `avoid_food`, `monitor`, `replace_box`.
- `route_to` ⊆ `patient`, `caregiver`, `doctor`. Regula: `critical` și `major` (în afară de `food`) → `caregiver` + `doctor`; pacientul vede doar `patient_text`, fără termeni tehnici.
- `id` e determinist (tip + id-urile sortate), ca re-analiza să nu dubleze alertele.
- `status` ∈ `open`, `acknowledged`, `reviewed_by_doctor`; `resolution` = `{ "by": "doctor", "decision": "keep" | "change_at_visit" | "refer_specialist", "note": "...", "at": "..." }`.

### 5.4 `Schedule`

```json
{
  "date": "2026-11-14",
  "anchors": { "wake": "07:00", "breakfast": "08:00", "lunch": "13:00", "dinner": "19:00", "bed": "22:30" },
  "moments": [
    {
      "time": "07:00",
      "label": "Imediat după trezire",
      "doses": [
        { "med_id": "med_05", "qty": 1, "instruction": "pe stomacul gol, cu un pahar de apă",
          "reasons": ["Levotiroxina se ia cu 30–60 min înainte de micul dejun"] }
      ]
    }
  ],
  "unsatisfied": [],
  "solver": { "moments_count": 5, "version": "1.0.0" }
}
```

Reguli:
- Maximum 5 momente pe zi; solverul minimizează numărul de momente, apoi distanța față de ancore.
- `unsatisfied` listează constrângerile imposibile (cu medicamentele implicate); fiecare intrare generează o alertă `timing` cu `action: ask_doctor`.

### 5.5 `CheckIn`

```json
{
  "id": "ci_01",
  "at": "2026-11-14T09:12:00+02:00",
  "transcript": "Dimineața, când mă ridic din pat, mi se învârte capul și am observat niște vânătăi pe mână.",
  "intent": "symptom_report",
  "symptoms": [
    { "code": "dizziness_orthostatic", "label": "amețeală la ridicare", "severity": "moderate" },
    { "code": "bruising", "label": "vânătăi", "severity": "moderate" }
  ],
  "correlations": [
    { "symptom": "bruising", "med_ids": ["med_01", "med_02"], "basis": "alert:al_ddi_med_01_med_02" },
    { "symptom": "dizziness_orthostatic", "med_ids": ["med_04", "med_08"], "basis": "adverse_effects.yaml" }
  ],
  "escalate": true,
  "reply_text": "Mulțumesc. I-am trimis Anei ce mi-ați spus. Vă rog să nu vă ridicați brusc din pat."
}
```

Reguli:
- `intent` ∈ `symptom_report`, `can_i_take` (X1), `which_pill_now`, `other`.
- `transcript` vine de pe telefon (recunoașterea vocală iOS); audio se trimite doar în varianta de rezervă cu Whisper.
- `symptoms[].code` doar din `contracts/symptoms.md` (~30 de coduri: `dizziness_orthostatic`, `bruising`, `bleeding_gums`, `black_stool`, `muscle_pain`, `confusion`, `fall`, `nausea`, `palpitations`, `swollen_ankles`, `dry_mouth`, `constipation`, `insomnia`, `drowsiness`, `rash`, `shortness_of_breath`…), fiecare cu sinonime în română și un flag `red_flag` (ex. `black_stool`, `fall`, `confusion` → `escalate = true` imediat).
- `reply_text` e template, nu text liber de LLM.

### 5.6 `Graph` (format Cytoscape)

```json
{
  "nodes": [
    { "data": { "id": "p", "type": "patient", "label": "Maria" } },
    { "data": { "id": "med_01", "type": "product", "label": "Sintrom 4 mg", "prescriber": "cardiologie" } },
    { "data": { "id": "s:B01AA07", "type": "substance", "label": "acenocumarol" } },
    { "data": { "id": "c:B01AA", "type": "atc_class", "label": "antagoniști vitamina K" } },
    { "data": { "id": "f:leafy_greens", "type": "food", "label": "legume cu frunze verzi" } }
  ],
  "edges": [
    { "data": { "source": "p", "target": "med_01", "type": "takes" } },
    { "data": { "source": "med_01", "target": "s:B01AA07", "type": "contains" } },
    { "data": { "source": "s:B01AA07", "target": "s:M01AE01", "type": "interacts", "severity": "major", "alert_id": "al_ddi_med_01_med_02" } }
  ]
}
```

### 5.7 API v1 (`contracts/api/openapi.yaml`)

Autentificare: un `patient_token` simplu în header (`X-Patient-Token`), creat la onboarding; pagina partajată folosește un `share_token` separat, cu expirare. (La hackathon nu facem conturi; pitch-ul spune ce ar urma.)

| Metodă | Rută | Ce face | Cine o cheamă |
|---|---|---|---|
| GET | `/health` | `{ ok: true }`; scriptul de review așteaptă după el | Q |
| POST | `/v1/patients` | creează pacientul (nume, an naștere, ancore) → `{id, patient_token}` | A |
| GET / PATCH | `/v1/patients/{id}` | profil + ancorele orarului | A |
| POST | `/v1/patients/{id}/scan` | multipart: `ocr_lines` (JSON: liniile de text de la OCR-ul Apple, în ordinea de citire, cu înălțimea relativă), `image` (opțional, pentru rezerva Gemini și pentru poza din listă), `datamatrix` (string, opțional), `kind` = `box` / `prescription` → `ExtractionResult { candidates: MedicationItem[], warnings[] }` (nu salvează) | A |
| POST | `/v1/patients/{id}/meds` | salvează un `MedicationItem` confirmat → reanaliză | A |
| PATCH / DELETE | `/v1/patients/{id}/meds/{mid}` | editare / ștergere → reanaliză | A |
| GET | `/v1/patients/{id}/analysis` | `{ alerts: Alert[], acb_total, graph: Graph, analyzed_at }` | A |
| POST | `/v1/patients/{id}/what-if` | `{ query: "algocalmin" }` sau `{ med: MedicationItem }` → alertele noi pe care le-ar produce (X1) | A |
| GET | `/v1/patients/{id}/schedule?date=` | `Schedule` | A |
| POST | `/v1/patients/{id}/doses` | `{ med_id, scheduled_at, status: taken / skipped / pending }` (idempotent pe `med_id` + `scheduled_at`; `pending` = anularea din snackbar) | A |
| POST | `/v1/patients/{id}/checkins` | JSON `{ text }` (transcrierea de pe telefon) sau, doar în varianta de rezervă, multipart `audio` (m4a) → `CheckIn` | A |
| GET | `/v1/patients/{id}/feed?since=` | evenimente pentru aparținător: alerte noi, doze ratate, check-in-uri escaladate | A (polling la 10 s) |
| POST | `/v1/patients/{id}/share` | → `{ share_token, url, expires_at }` (implicit 72 h) | A |
| GET | `/share/{token}` | linkul din QR: cu sesiunea portalului îl adaugă pe pacient în lista medicului (303 → fișa); altfel autentificarea | browser |
| GET | `/portal`, `/portal/patients/{id}` (+ `/print`, `/graph`) | portalul medicului de familie (HTML, sesiune prin cookie după `POST /portal/login`) | browser |
| POST | `/portal/patients/{id}/alerts/{alert_id}/review` | `{ decision, note }` → `status: reviewed_by_doctor` + eveniment `doctor_reviewed` | portalul |
| GET | `/v1/kb/search?q=` | autocomplete pentru adăugarea manuală | A |
| GET | `/share/{token}/graph?embed=1` | doar graful, pe tot ecranul, pentru WKWebView-ul din app (B6, A3) | A |
| POST | `/demo/reset` | doar cu `DEMO_MODE=1`: recreează pacientul demo din fixture (B7, A6, Q0) | A, Q |
| POST | `/demo/missed-dose` | doar cu `DEMO_MODE=1`: simulează o doză ratată (B7, A6) | A |

### 5.8 Pacientul demo (`contracts/fixtures/demo_patient.json`)

**Maria, 78 de ani, Timișoara; fiica, Ana, în Cluj.** 5 medici, niciunul nu vede lista completă.

| id | Produs (cutie) | Substanță | Prescris de | Posologie |
|---|---|---|---|---|
| med_01 | Sintrom 4 mg, 20 comprimate | acenocumarol | cardiolog | ½ seara |
| med_02 | Nurofen Express Forte 400 mg, capsule moi (din `ro_products_extra.csv`, OTC) | ibuprofen | OTC (durere de genunchi) | 1-0-1 |
| med_03 | Simvastatin LPH 40 mg (din `ro_products_extra.csv`) | simvastatină | medic de familie | 0-0-1 |
| med_04 | Amlodipină Actavis 10 mg (din `ro_products_extra.csv`) | amlodipină | medic de familie | 1-0-0 |
| med_05 | Euthyrox 75 mcg | levotiroxină | endocrinolog | dimineața, pe stomacul gol |
| med_06 | Calcium + Vitamin D, Dr.Max (supliment, din `ro_products_extra.csv`) | carbonat de calciu + colecalciferol | medic de familie | 0-1-0 |
| med_07 | Omeprazol Zentiva 20 mg | omeprazol | gastroenterolog (de 2 ani) | 1-0-0 înainte de masă |
| med_08 | Amitriptilin 25 mg (ambalaj din Republica Moldova, doar pentru poză; în România: Amitriptilina Arena) | amitriptilină | neurolog | 0-0-1 |
| med_09 *(scenariul „medic nou”)* | Fromilid 500 mg (sau Klabax 500 mg; Klacid 500 mg există doar ca SR, o dată pe zi) | claritromicină | ORL, 7 zile | 1-0-1 |

*(14.11.2026)* Numele comerciale urmează cutiile din fotografiile demo (`demo/photos/med_0N.jpg`). Substanțele, dozele și posologiile nu s-au schimbat, deci nici alertele (`expected_alerts.json`) și nici programul. Cutiile care lipsesc din catalogul public sunt în `kb/ro_products_extra.csv`, cu motivul scris.

Alertele așteptate, **verificate pe fișierele DDInter descărcate** (12.11.2026; `kb/raw/ddinter/demo_pairs_report.csv`) și pe `kb/curated_ddi.csv` / `kb/curated_dfi.csv`. Lista exactă, cu `id` și `med_ids`, e în `contracts/fixtures/expected_alerts.json` (P0, 13.11.2026).

| Alertă | Tip | Severitate | De unde |
|---|---|---|---|
| acenocumarol + ibuprofen → sângerare | ddi | major | DDInter `Unknown` → curated (site / RCP Sintrom); altfel analogie cu warfarina (`Major`) |
| simvastatină + claritromicină → rabdomioliză (doar după med_09) | ddi | critical | DDInter `Major` → curated „contraindicat” (RCP) |
| acenocumarol + claritromicină → sângerare (doar după med_09) | ddi | major | DDInter `Unknown` → curated; altfel analogie cu warfarina (`Major`) |
| simvastatină + amlodipină → doza de simvastatină peste limita recomandată | ddi | major | DDInter `Major` |
| levotiroxină + calciu → absorbție scăzută (se rezolvă prin orar) | ddi + timing | moderate | DDInter `Moderate` |
| levotiroxină + omeprazol → absorbție scăzută | ddi | moderate | DDInter `Moderate` |
| ibuprofen + amlodipină | ddi | moderate | DDInter `Moderate` |
| simvastatină + omeprazol | ddi | moderate | DDInter `Moderate` |
| amlodipină + carbonat de calciu | ddi | moderate | DDInter `Moderate` |
| levotiroxină + amitriptilină | ddi | moderate | DDInter `Moderate` |
| acenocumarol + levotiroxină; acenocumarol + omeprazol | ddi | moderate | DDInter `Unknown` → analogie cu warfarina (`Moderate`) |
| amitriptilină + claritromicină; amlodipină + claritromicină (doar după med_09) | ddi | moderate | DDInter `Moderate` |
| simvastatină + levotiroxină; omeprazol + claritromicină; acenocumarol + simvastatină | ddi | minor | DDInter `Minor` (ultima prin analogie) |
| simvastatină + grepfrut | food | major | `kb/curated_dfi.csv` (DDInter `Major`); afișată în cardul „Mâncare și băutură”, nu printre cardurile grave |
| acenocumarol + vitamina K (legume cu frunze verzi, aport constant); alcool cu acenocumarol, simvastatină, ibuprofen, amitriptilină; levotiroxină + soia, + fibre | food | moderate | `kb/curated_dfi.csv` |
| claritromicină + grepfrut (doar după med_09) | food | minor | `kb/curated_dfi.csv` |
| ibuprofen cronic la > 65 de ani | elderly_pim (Beers) | major | `elderly.yaml` |
| amitriptilină la vârstnic | elderly_pim (Beers) | major | `elderly.yaml` |
| IPP > 8 săptămâni | elderly_pim (Beers) | moderate | `elderly.yaml` |
| ACB total = 3 (amitriptilină) | anticholinergic | moderate | `acb.yaml` |

Pe ecranul Anei, fără med_09: 4 carduri grave (Sintrom + Nurofen, simvastatină + amlodipină, ibuprofen la vârstnic, amitriptilină la vârstnic) + un card restrâns cu interacțiunile moderate + cardul „Mâncare și băutură” + cardul ACB.

Check-in-ul demo (`checkin_demo.json`): „Dimineața, când mă ridic din pat, mi se învârte capul și am observat niște vânătăi pe mână” → `dizziness_orthostatic` (amlodipină, amitriptilină) + `bruising` (alerta acenocumarol + ibuprofen) → `escalate = true`.

---

## 6. Etapele, cu prompturi de implementare

Fiecare prompt începe cu aceeași linie de workflow (prescurtată mai jos ca `[WORKFLOW]`):

~~~text
[WORKFLOW] Lucrezi în monorepo-ul polygraph. Citește întâi CONTRIBUTING.md și tot folderul contracts/ (sursa de adevăr; nu le schimba în acest task). Aplicația e iOS nativă (SwiftUI, iOS 18+, fără dependențe externe). Creezi un branch nou din main actualizat (numele e dat mai jos), nu lucrezi pe main. Commit-uri mici, un rând în engleză la imperativ, apoi Co-authored-by pentru celălalt membru (după git config user.name), FĂRĂ co-author sau mențiuni AI. Comentarii doar unde explică de ce. La final rulezi make check, apoi push și gh pr create --base main.
~~~

### P0 · Repo, contracte, fixture-uri, mock server

**Responsabil:** amândoi (B scrie contractele și mock-ul, A scrie scheletul Makefile / CI și face review la contracte) · **Depinde de:** pregătirea din secțiunea 10 · **Durată:** 2 h · **Se termină cu:** S0

**Checklist**
- [x] Repo `polygraph` pe GitHub, `README.md` cu pitch-ul într-o frază și cum se pornește
- [x] Structura de foldere din 5.1, cu un README scurt în fiecare
- [x] `contracts/schema/*.schema.json` (2020-12, `additionalProperties: false`, enum-uri) pentru 5.2–5.6 + `extraction.schema.json`
- [x] `contracts/api/openapi.yaml` (5.7)
- [x] `contracts/symptoms.md` (vocabularul de simptome, sinonime RO, `red_flag`)
- [x] `contracts/fixtures/` (5.8) + `contracts/examples/`
- [x] `contracts/validate.py`
- [x] `backend/mock_server.py` care servește fixture-urile pe toate rutele
- [x] `Makefile` (`setup`, `check`, `mock`, `dev`, `kb`, `demo-check`), `.githooks/commit-msg`, `CONTRIBUTING.md`, `AGENTS.md`, `CLAUDE.md`
- [x] *(adăugat de mână: agentul nu are voie să scrie în `.claude/`)* `.claude/skills/apple-design/SKILL.md` + `LICENSE` (MIT, Emil Kowalski), copiate neschimbat din `emilkowalski/skills` (commit `4061b67`); `docs/PLAN.md` = acest plan
- [x] `.github/workflows/ci.yml` (contracts, python; iOS rulează local prin `make check-ios`)
- [x] Proiectul Xcode gol creat **de om, din Xcode** (New Project → iOS App, SwiftUI, în `app/`, cu folderele sincronizate) și rulat pe ambele iPhone-uri (Vladimir ✅, Mihnea ✅); agenții nu creează proiectul, doar adaugă fișiere în el

~~~text
[WORKFLOW] Branch: chore/p0-repo-contracts.

Obiectiv: monorepo-ul și contractele v1 pentru PolyGraph, ca doi oameni să poată lucra în paralel din ora 2. Nu scrie încă logică de aplicație sau de backend, cu excepția serverului mock.

1. Structura din „5.1 Structura repo-ului” (copiată în docs/PLAN.md). Fiecare folder are un README de 3 rânduri: ce conține, cine îl deține.
2. contracts/schema/: medication_item, alert, schedule, checkin, graph, extraction (ExtractionResult = { candidates: MedicationItem[], warnings: string[], raw_text: string|null }). JSON Schema 2020-12, additionalProperties false, enum-uri exact ca în secțiunile 5.2–5.6, format date / date-time / time unde e cazul, câmpurile nullable declarate explicit.
3. contracts/api/openapi.yaml (OpenAPI 3.1) cu toate rutele din 5.7, $ref către contracts/schema/, securitate apiKey pe header X-Patient-Token.
4. contracts/symptoms.md: tabel cod | etichetă RO | sinonime RO (minimum 3 per cod, limbaj de vârstnic: „mă ia cu amețeală”, „mi se învârte capul”) | red_flag. ~30 de coduri.
5. contracts/fixtures/: demo_patient.json (cele 8 medicamente din 5.8, fără med_09) + med_09_fromilid.json separat; expected_alerts.json (lista din 5.8, câmpurile kind / severity / med_ids; textele nu se compară); expected_schedule.json (momentele și dozele, fără texte); checkin_demo.json; gs1_cases.json: la P0, 10–12 cazuri **sintetice** (cu și fără prefix ]d2, cu și fără separator GS, AI-uri de lungime variabilă, ziua 00 în data de expirare, GTIN cu zero la început); codurile reale ale cutiilor demo nu există încă (se scanează la hackathon) și se adaugă în același fișier, cu GTIN / expirare / lot / serie, când sunt citite. Pozele din photo_url lipsesc la P0: mock-ul servește un placeholder pentru /media/*.
6. contracts/validate.py (Python 3.12; jsonschema, pyyaml, openapi-spec-validator): validează exemplele și fixture-urile față de scheme și openapi.yaml; exit ≠ 0 la orice eroare.
7. backend/mock_server.py (FastAPI): toate rutele din openapi.yaml, răspunsuri din fixture-uri; POST /scan întoarce candidatul din fixture care corespunde câmpului `datamatrix` sau, fără el, primul medicament încă nesalvat; POST /meds adaugă în memorie și GET /analysis întoarce expected_alerts filtrate pe medicamentele prezente; POST /checkins întoarce checkin_demo.json. Pornește cu `make mock` pe 0.0.0.0:8000.
8. Makefile: setup (hooks + uv sync + npm pentru quicktype), check (R1–R3 pentru contracte și Python), check-ios (xcodebuild test pe simulator), models (quicktype → Swift), mock, dev, kb, demo-check (deocamdată no-op). CI apelează make check.
9. .claude/skills/apple-design/: SKILL.md și LICENSE copiate neschimbat din https://github.com/emilkowalski/skills (skills/apple-design/SKILL.md și LICENSE din rădăcina repo-ului, commit 4061b67); docs/PLAN.md = planul.
10. CONTRIBUTING.md cu regulile din „Git workflow (variantă de hackathon)”, AGENTS.md și CLAUDE.md scurte care trimit la el și spun: „pentru orice modificare de UI (app/ sau paginile din backend/polygraph/share/) citește întâi .claude/skills/apple-design/SKILL.md și docs/DESIGN.md”; .githooks/commit-msg respinge mesajele fără Co-authored-by-ul celuilalt membru sau cu „Claude”, „Generated with”, „anthropic”. În .claude/settings.json (comun) se golește atribuirea automată a Claude Code (attribution.commit și attribution.pr = ""; în versiunile mai vechi includeCoAuthoredBy: false), ca agentul să nu adauge linii care pică în hook.

Criterii de acceptare: make check verde; validate.py pică dacă un fixture are un `kind` inexistent; curl pe fiecare rută a mock-ului întoarce JSON valid după schemă.

Nu face: ecranele aplicației, ingestia datelor, motorul.
~~~

**Teste**
- [x] T-P0-01 `validate.py` trece pe toate exemplele și fixture-urile; pică pe o mutație (enum invalid, câmp în plus, câmp obligatoriu lipsă).
- [x] T-P0-02 `pytest backend/tests/test_mock.py`: fiecare rută din `openapi.yaml` răspunde, iar răspunsul validează după schemă.
- [x] T-P0-03 Hook-ul `commit-msg` respinge un mesaj fără co-author și unul cu mențiune AI.

---

### A1 · Proiectul iOS, tokenii, modelele și clientul API

**Responsabil:** Dev A · **Depinde de:** P0 · **Durată:** 2.5 h · **Branch:** `feature/a1-app-skeleton`

**Checklist**
- [x] Proiect Xcode `app/PolyGraph.xcodeproj`, SwiftUI, iOS 18.0+, doar iPhone, portret; **fără dependențe externe** (`PolyGraph.xcconfig` legat din Xcode, `Config/Info.plist` cu cheile de cameră / microfon / vorbire / rețea locală / ATS)
- [x] Semnarea din `app/Signing.local.xcconfig` (gitignored: Team ID + sufixul bundle id-ului), ca fiecare să ruleze pe iPhone-ul lui fără conflicte (`Signing.local.xcconfig.example` în git)
- [x] Modele `Codable` generate din schemele contractelor (`make models`, quicktype)
- [x] `APIClient` (URLSession, async/await) cu `baseURL` din setări
- [x] Două moduri: **Senior** (`NavigationStack`, fără tab-uri) și **Aparținător** (`TabView`: Medicamente, Alerte, Graf, Noutăți)
- [x] Tokenii din 2.4.3 în `Design/` + `PressableButtonStyle` + `withPgAnimation`
- [x] Onboarding minimal → `POST /v1/patients`
- [x] Hook-urile de test doar în Debug (`PG_*` din tabelul Q0) și `accessibilityIdentifier` pe toate elementele interactive

~~~text
[WORKFLOW] Branch: feature/a1-app-skeleton.

Citește întâi .claude/skills/apple-design/SKILL.md și docs/DESIGN.md (secțiunea 2.4 din plan). Regula: componenta de sistem care face deja ce cere skill-ul are prioritate față de cod propriu; abaterile pentru vârstnici din 2.4.2 au prioritate față de skill.

Obiectiv: aplicația iOS nativă PolyGraph, cap-coadă pe serverul mock (make mock), cu tokenii de design pe care îi folosesc toate ecranele.

1. Proiectul: app/PolyGraph.xcodeproj, SwiftUI App lifecycle, iOS 18.0, iPhone, portret, Swift language mode 5 (nu 6: strict concurrency produce erori care costă ore fără câștig la hackathon). Proiectul există deja (creat de om din Xcode la P0, cu foldere sincronizate; fișierele noi din app/PolyGraph/ intră automat în țintă): nu-l recrea și nu edita niciodată project.pbxproj de mână. Dacă setarea de țintă e alta decât mai jos (iOS 18.0, Swift 5), spune-i omului să o schimbe din Xcode. Fără pachete SPM. Signing din Signing.local.xcconfig (DEVELOPMENT_TEAM, PRODUCT_BUNDLE_IDENTIFIER = ro.polygraph.$(PG_BUNDLE_SUFFIX)); un Signing.local.xcconfig.example în git. Info.plist: NSCameraUsageDescription, NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription (în română), NSLocalNetworkUsageDescription, NSAppTransportSecurity cu NSAllowsLocalNetworking.
2. Foldere: App/, Design/, Models/, API/, Onboarding/, Senior/, Caregiver/, Scan/, Meds/, Alerts/, Graph/, Voice/, Share/, Settings/; țintă de teste PolyGraphTests (Swift Testing).
3. make models: npx quicktype --src-lang schema --lang swift pe contracts/schema/*.json → app/PolyGraph/Models/Contracts.swift (struct-uri Codable, snake_case mapat prin CodingKeys). Enum necunoscut → eroare de decodare, nu valoare implicită.
4. API/APIClient.swift: o metodă async throws per rută din contracts/api/openapi.yaml; header X-Patient-Token din UserDefaults; JSONDecoder cu date ISO 8601; timeout 30 s pentru /scan și /checkins, 10 s în rest; erorile devin APIError cu mesaj în română. Upload multipart scris de mână (un helper mic).
5. State: @Observable AppStore (pacientul, medicamentele, analiza, programul) injectat cu .environment; reîncărcarea analizei după orice schimbare.
6. Design/: Animation.pgStandard / pgQuick / pgMove / pgFlick (2.4.3); withPgAnimation(_:_:) care citește accessibilityReduceMotion și cade pe .easeInOut(0.2); Spacing, Radius; culorile în Assets.xcassets (light / dark / high contrast) cu un enum PgColor; Severity → (culoare, etichetă în cuvinte); PressableButtonStyle: scaleEffect(isPressed ? 0.97 : 1) cu .pgQuick, highlight instant; GuardedAction(interval:) care ignoră al doilea apel în interval (1 s în modul senior); SeniorButton (72 pt, lățime completă, text 22 pt prin @ScaledMetric).
7. Navigare: RootView alege Onboarding / SeniorRoot / CaregiverRoot după UserDefaults. SeniorRoot = NavigationStack cu NowView (placeholder) și DayView. CaregiverRoot = TabView cu patru tab-uri, fiecare cu NavigationStack și titlu mare (.navigationBarTitleDisplayMode(.large)). Settings (din toolbar): baseURL, rolul, „Mod demo”.
8. Onboarding: un pas pe ecran (nume; an naștere; ora de trezire, mese, culcare cu DatePicker .hourAndMinute, wheel); butonul principal jos; progres „2 din 4” sus → POST /v1/patients → token salvat.

9. Hook-uri pentru verificarea pe simulator (etapa Q), compilate doar în Debug (#if DEBUG): App/DebugEnvironment.swift citește variabilele PG_* din tabelul Q0 (PG_BASE_URL, PG_ROLE, PG_SKIP_ONBOARDING, PG_RESET_DEMO, PG_FAKE_SCAN, PG_FAKE_TRANSCRIPT, PG_NOW, PG_REDUCE_MOTION) și le expune printr-un singur obiect; ceasul aplicației trece printr-un protocol AppClock (real sau fix din PG_NOW); withPgAnimation respectă și PG_REDUCE_MOTION. Folderul DebugAssets/ (doar în Debug) primește pozele din demo/photos/. Convenție: .accessibilityIdentifier("<ecran>.<element>") pe fiecare buton, câmp, card și tab (ex. now.takenButton, alerts.card.<id>, scan.shutter), scrisă în docs/DESIGN.md. Logurile aplicației prin Logger(subsystem: "ro.polygraph", category: <modul>).

Criterii de acceptare: rulează pe ambele iPhone-uri; onboarding-ul creează pacientul pe mock; în modul Aparținător, lista din fixture apare sub bara de navigare de sistem; cu Reduce Motion pornit, nicio tranziție spațială.

Nu face: camera, audio, TTS, graful, ecranele de alerte (doar placeholder-ele lor).
~~~

**Teste**
- [x] T-A1-01 Decodare + encodare pentru fiecare fișier din `contracts/examples/` și `contracts/fixtures/` (citite direct din repo prin `#filePath`, fără folder reference, deci fără `project.pbxproj` atins).
- [x] T-A1-02 `GuardedAction`: două apeluri la 300 ms → o execuție; la 1.2 s → două.
- [x] T-A1-03 `withPgAnimation` cu Reduce Motion → animația de rezervă.
- [x] T-A1-04 Manual: pe ambele iPhone-uri, onboarding → lista cu 8 medicamente din mock. *(13.11.2026: ambele iPhone-uri + simulatorul)*

---

### A2 · Scanarea: DataMatrix, poza cutiei, rețeta, confirmarea

**Responsabil:** Dev A · **Depinde de:** A1 · **Durată:** 4 h · **Branch:** `feature/a2-scan`

**Checklist**
- [x] Mod **Cutie**: VisionKit `DataScannerViewController` (DataMatrix) + `capturePhoto()` pentru fața cutiei, într-un singur ecran
- [x] Mod **Rețetă**: `VNDocumentCameraViewController` (decupează și îndreaptă foaia)
- [x] Parser GS1 în Swift
- [x] Upload multipart către `/scan`, cu stări de progres în cuvinte
- [x] Sheet-ul de confirmare (detent `.large`), câmpurile nesigure marcate, „Salvează” → `POST /meds`
- [x] Rețetă cu mai multe medicamente → pași „1 din 3” în același sheet

~~~text
[WORKFLOW] Branch: feature/a2-scan.

Citește .claude/skills/apple-design/SKILL.md (§1, §7, §13, §16) și docs/DESIGN.md (2.4.2–2.4.6).

Obiectiv: adăugarea unui medicament prin cameră, contra mock-ului (după S2 contra backend-ului real, fără schimbări de cod).

1. Scan/GS1.swift: parse(_ raw: String) -> GS1Data { gtin, expiry (ultima zi a lunii dacă ziua e 00), batch, serial }; acceptă prefixul ]d2, separatorul GS (\u{1D}) și AI-uri de lungime variabilă. Teste pe contracts/fixtures/gs1_cases.json.
2. Scan/BoxScannerView: UIViewControllerRepresentable peste DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.dataMatrix])], qualityLevel: .accurate, isHighlightingEnabled: true). Verifică DataScannerViewController.isSupported / isAvailable; altfel mesaj clar. La primul cod valid: starea scanned = true (care declanșează în același cadru conturul verde și .sensoryFeedback(.impact(weight: .medium))), ghidajul devine „Am citit codul. Acum fotografiați fața cutiei.”, iar butonul de declanșare (76 pt, PressableButtonStyle) apelează capturePhoto().
3. Scan/PrescriptionScannerView: VNDocumentCameraViewController; se trimite prima pagină.
4. ScanView: control segmentat Cutie / Rețetă sus (în toolbar), camera pe tot ecranul, ghidajul într-o pastilă cu .regularMaterial („Arătați codul pătrat de pe cutie”).
5. OCR pe telefon (Scan/OCR.swift): VNRecognizeTextRequest pe imaginea capturată, recognitionLevel .accurate, usesLanguageCorrection = true, recognitionLanguages din supportedRecognitionLanguages() care include ro-RO dacă există (altfel automaticallyDetectsLanguage = true), customWords = numele comerciale din pacientul demo + cele mai frecvente 300 de branduri (fișier text din bundle, generat de B1). Rezultat: liniile în ordinea de citire, cu înălțimea relativă a fiecărei linii. În Debug, butonul „Salvează OCR” scrie rezultatul în demo/ocr/<nume>.json (prin share sheet), ca B3 să aibă date reale de test.
   Upload: ocr_lines + imaginea redimensionată la ≤ 1600 px, JPEG 0.8, + datamatrix + kind → POST /scan. Stările de status în pastilă, cu tranziție .opacity: „Citesc cutia…” → „Caut substanța activă…”. Timeout → eroare inline cu „Încearcă din nou” și „Completez manual”. Dacă răspunsul are match.method = gtin_cache, se sare peste poză („Am recunoscut cutia: Sintrom 4 mg”).
6. ConfirmSheet (.sheet, .presentationDetents([.large]), .interactiveDismissDisabled(hasEdits)): Form de sistem cu poza decupată sus; brand + concentrație ca titlu; substanțele cu ATC ca text secundar; posologia ca patru Stepper-e etichetate (Dimineața / Prânz / Seara / Culcare, pas 0.5); Picker segmentat pentru masă (Pe stomacul gol / Înainte / La masă / Oricând); medicul / specialitatea; expirarea. Câmpurile cu needs_review au fundal galben deschis și eticheta „verificați”. Substanță negăsită → .searchable cu sugestii din /v1/kb/search. Cutie expirată → avertizare deasupra butonului, înainte de salvare.
7. „Salvează” (buton lățime completă în .safeAreaInset(edge: .bottom)) → POST /meds → sheet-ul se închide; lista primește medicamentul cu .pgStandard; mesaj de finalizare „Am salvat. 2 alerte noi” cu „Vezi” (trece pe tab-ul Alerte).
8. Rețetă cu mai mulți candidați: același sheet, TabView(.page) cu „1 din 3” în titlu.

Criterii de acceptare: pe iPhone, cu mock-ul: o cutie demo (DataMatrix + poză) ajunge în listă; o rețetă cu 2 medicamente produce 2 pași; conturul și haptic-ul apar împreună.

Nu face: lista și alertele (A3), modul senior.
~~~

**Teste**
- [x] T-A2-01 `GS1Tests` pe `contracts/fixtures/gs1_cases.json` (aceleași cazuri ca în Python, T-B3-04). *(13.11.2026: `make check-ios` verde)*
- [x] T-A2-02 Unit: din `ExtractionResult`-ul fixture, modelul de confirmare marchează exact câmpurile cu `needs_review`, iar „Salvează” produce `MedicationItem`-ul editat. *(13.11.2026: `make check-ios` verde)*
- [ ] T-A2-03 Manual: 3 cutii demo + rețeta tipărită, pe iPhone, în lumina sălii. *(13.11.2026: pe iPhone, cu cutiile de test din `demo/datamatrix/test_*.png` și `demo/rx/reteta_demo_fromilid.pdf` afișate pe ecran: cod citit, poză, OCR, confirmare, salvare; OCR-ul salvat în `demo/ocr/`. Rămân cutiile fizice în lumina sălii.)*

---

### A3 · Medicamente, alerte, graf (modul aparținător)

**Responsabil:** Dev A · **Depinde de:** A1 (A2 în paralel) · **Durată:** 4 h + 2 h integrarea cu backend-ul real · **Branch:** `feature/a3-meds-alerts-graph`

**Checklist**
- [x] Medicamente: `List` grupată pe medic, swipe-to-delete cu undo
- [x] Alerte: carduri pe severitate; detaliul cu tranziție zoom din card
- [x] Cardul ACB
- [x] Graful în `WKWebView` (pagina lui B6; până atunci un HTML local cu Cytoscape)
- [x] Detaliul unui medicament
- [x] „Arată medicului” (QR) în toolbar-ul listei (făcut la A6: `meds.shareButton`)

~~~text
[WORKFLOW] Branch: feature/a3-meds-alerts-graph.

Citește .claude/skills/apple-design/SKILL.md (§3, §7, §12, §16) și docs/DESIGN.md (2.4.3–2.4.6). Aici nu scrii animații proprii: folosești List, NavigationStack, zoom transition și sheet-urile de sistem.

Obiectiv: modul Aparținător arată lista, alertele și graful pacientului.

1. MedsView: List(.insetGrouped) cu secțiuni pe prescriber.specialty („Cardiologie”, „Fără rețetă”); rând: AsyncImage cu poza cutiei (48 pt, rază 8), brand + concentrație, posologia în cuvinte („½ seara”), un punct de severitate + eticheta celei mai grave alerte. .swipeActions → Șterge: dispare imediat, apare un banner „Anulează” 5 s (agency, fără dialog), apoi DELETE. Toolbar: „+” → ScanView (fullScreenCover), „Arată medicului” → ShareSheet (A6). .refreshable.
2. AlertsView: ScrollView; sus, cardurile critical și major, câte unul pe alertă (fără alertele food); dedesubt, un singur card restrâns pentru toate alertele moderate („6 interacțiuni moderate, de discutat cu medicul de familie la următoarea vizită”, DisclosureGroup); apoi un card restrâns „Mâncare și băutură” cu toate alertele food, indiferent de severitate; minor nu apar în aplicație (doar în portalul medicului de familie). Card: punct + eticheta severității în cuvinte („Grav”), titlul, medicamentele ca chip-uri, o linie de recomandare; alertele cu basis = class_analogy au eticheta mică „prin analogie”. Fiecare card e .matchedTransitionSource(id: alert.id, in: ns) într-un NavigationLink.
3. AlertDetailView cu .navigationTransition(.zoom(sourceID: alert.id, in: ns)): „Ce înseamnă” (detail), „Ce puteți face” (recommendation), medicamentele (link la detaliu), sursa în .footnote („Sursa: DDInter 2.0”), statusul și decizia medicului de familie (cu nota), buton „Am înțeles”. Închiderea interactivă (swipe în jos) și întoarcerea în card le face sistemul.
4. AcbCard deasupra alertelor dacă acb_total ≥ 1: scorul mare, o propoziție (≥ 3: „risc crescut de confuzie și căderi”), medicamentele care contribuie.
5. GraphView: UIViewRepresentable cu WKWebView care încarcă {baseURL}/share/{token}/graph?embed=1 (token creat o dată și ținut în AppStore). Până la B6: Graph/graph.html din bundle, cu cytoscape.min.js local, primind JSON-ul prin evaluateJavaScript. Tap pe muchie → WKScriptMessageHandler → deschide AlertDetailView. Fundal transparent, ca să se vadă fundalul aplicației.
6. MedDetailView (push): poza mare, substanțe, momentele din program, alertele lui, „Editează” (refolosește ConfirmSheet din A2).
7. Toate inserările / ștergerile din liste se fac în withPgAnimation(.pgStandard).

Criterii de acceptare: pe mock, alertele din expected_alerts.json (fără med_09) apar în ordinea corectă (4 carduri grave, sus); cardul se extinde în detaliu și se întoarce în el la swipe; tap pe o muchie din graf deschide alerta corectă.

Nu face: modul senior, vocea.
~~~

**Teste**
- [x] T-A3-01 Unit: sortarea alertelor critical → minor și gruparea pe specialitate pe fixture-ul demo (6 grupuri). *(13.11.2026: `PolyGraphTests/CaregiverTests.swift`, `make check-ios` verde)*
- [x] T-A3-02 Unit: ștergerea + „Anulează” în 5 s nu trimite DELETE. *(13.11.2026: `DeleteUndoQueueTests`, `make check-ios` verde)*
- [x] T-A3-03 Manual: graful pe iPhone, fără internet (doar rețeaua locală), se încarcă în < 2 s. *(13.11.2026: mod avion + Wi-Fi local, „graf desenat în 427 ms”)*

---

### A4 · Modul senior: Acum, Ziua de azi, „Am luat”, TTS, notificări

**Responsabil:** Dev A · **Depinde de:** A1; B4 pentru programul real (până atunci `expected_schedule.json` din mock) · **Durată:** 5 h · **Branch:** `feature/a4-senior-mode`

**Checklist**
- [x] `NowView`: ora mare, momentul, dozele cu pozele cutiilor; suprafețe opace *(13.11.2026: `Senior/NowView.swift`, `SeniorComponents.swift`)*
- [x] Trei `SeniorButton`: „Am luat” / „Mai târziu” / „Am sărit”, cu guard de 1 s *(„Mai târziu” = reamintire peste 15 min, doar pe telefon)*
- [x] **„Am luat” cu bifa care zboară în cronologie** + `.sensoryFeedback(.success)` + anulare 5 s *(`DoseLog`; cu Reduce Motion doar `.opacity`)*
- [x] `DayView`: cronologia momentelor *(atingerea unui rând deschide `NowView(pinnedTime:)`)*
- [x] TTS `AVSpeechSynthesizer` cu vocea `ro-RO` *(`Voice/Speaker.swift`: Enhanced/Premium dacă există, rate 0.45, `.duckOthers`; citire la deschidere dezactivabilă din Setări)*
- [x] Notificări locale (`UNCalendarNotificationTrigger`) la fiecare moment *(`Senior/Reminders.swift`: azi + mâine, refăcute la orice schimbare a programului sau a confirmărilor; permisiunea cerută din „Acum”, cu motivul pe card)*
- [x] Card calm pentru alertele cu `route_to` ∋ `patient` („Am înțeles” le ascunde până la o alertă nouă)
- [x] Previews pentru `NowView` la `.large`, `.xxxLarge`, `.accessibility3`, light și dark *(`Senior/SeniorPreviews.swift`)*
- [x] SeniorButton „Spuneți-mi cum vă simțiți” *(adăugat cu A5: deschide `VoiceCheckInView`)*

~~~text
[WORKFLOW] Branch: feature/a4-senior-mode.

Citește .claude/skills/apple-design/SKILL.md (§1, §8, §13, §14, §16) și docs/DESIGN.md, cu atenție la 2.4.2 (abaterile pentru vârstnici au prioritate față de skill).

Obiectiv: ce vede pacientul. Emoția țintă: liniște. Un singur lucru pe ecran, text mare, fără jargon, fără roșu de alarmă, fără acțiuni doar prin gest.

1. NowView (fundal opac):
   - momentul curent = primul moment cu doze neconfirmate a cărui oră e în ultimele 2 h sau, altfel, următorul moment;
   - sus: un rând de puncte, unul per moment al zilei (cronologia), apoi ora (64 pt, semibold, monospacedDigit, @ScaledMetric) și eticheta („Imediat după trezire”);
   - pentru fiecare doză, un card: poza cutiei pe toată lățimea (4:3, rază 20), numele comercial (28 pt semibold), cantitatea în cuvinte și ca pictogramă („o pastilă”, „jumătate de pastilă”), instrucțiunea (22 pt: „pe stomacul gol, cu un pahar de apă”); cardul e un singur element VoiceOver;
   - jos, în .safeAreaInset(edge: .bottom): „AM LUAT” (SeniorButton accent), dedesubt „Mai târziu” și „Am sărit” (SeniorButton secundare); toate prin GuardedAction(1 s);
   - un buton de difuzor lângă oră (repetă TTS) și un SeniorButton „Spuneți-mi cum vă simțiți” (deschide A5).
2. „Am luat”, totul dintr-o singură schimbare de stare:
   - POST /doses per doză (idempotent pe med_id + scheduled_at);
   - o bifă mare apare peste carduri, apoi (matchedGeometryEffect cu punctul momentului din cronologie, .pgMove) se micșorează și ajunge în punct, care se umple;
   - cardurile ies cu .opacity + .move(edge: .top) (în direcția cronologiei), următorul moment intră de jos;
   - .sensoryFeedback(.success, trigger: takenCount); TTS „Foarte bine. Următoarele pastile sunt la ora 13.”, pornit în același timp cu animația;
   - banner mare „Am notat. Anulează” 5 s; „Anulează” trimite POST /doses cu status pending și inversează starea (animația pornește de unde e);
   - cu Reduce Motion: fără zbor, doar schimbarea de stare cu .opacity.
3. DayView (push, „înapoi” cu eticheta „Acum”): cronologie verticală, câte un rând pe moment (ora, eticheta, pozele mici ale cutiilor, starea în cuvinte și cu pictogramă). Tap → aceleași detalii ca NowView pentru momentul acela.
4. Voice/Speaker.swift: AVSpeechSynthesizer cu AVSpeechSynthesisVoice(language: "ro-RO") (preferă vocea Enhanced / Premium dacă e instalată), rate 0.45; AVAudioSession .playback cu .duckOthers; citire automată la deschiderea NowView (dezactivabilă din setări).
5. Notificări: UNUserNotificationCenter, permisiunea cerută după onboarding cu o propoziție de motiv; un UNCalendarNotificationTrigger per moment (repeats: false, pentru azi și mâine), reprogramate după orice schimbare a programului; textul = eticheta momentului + numele comerciale.
6. Alertă nouă cu route_to care conține patient: card calm (PgColor.calmCard) sus: „Am observat ceva la pastile și am anunțat-o pe Ana. Nu schimbați nimic până vă sună.”; fără roșu, fără pictogramă de avertizare.
7. Previews pentru NowView la dynamicTypeSize .large, .xxxLarge, .accessibility3, light și dark.

Criterii de acceptare: pe iPhone, momentul de dimineață se confirmă doar cu degetul mare și se aude ce urmează; două apăsări rapide pe „Am luat” produc un singur POST per doză; cu Reduce Motion nu există mișcare; notificarea apare la ora momentului.

Nu face: microfonul (A5), modul aparținător.
~~~

**Teste**
- [x] T-A4-01 Unit: alegerea „momentului curent” pentru 6 ore ale zilei (înainte de trezire, între momente, după culcare). *(`PolyGraphTests/SeniorTests.swift`, `CurrentMomentTests`; 13.11.2026: `make check-ios` verde)*
- [x] T-A4-02 Unit: „Am luat” apelat de două ori în 300 ms → un singur set de `POST /doses`; „Anulează” trimite `pending`. *(`DoseLogTests`; 13.11.2026: `make check-ios` verde)*
- [x] T-A4-03 Manual: Previews la `.accessibility3` fără text tăiat; o persoană care nu a văzut aplicația confirmă momentul fără explicații. *(13.11.2026: pe iPhone cu `DEMO_MODE=1 make dev`; dubla apăsare → 2 `POST /doses` pentru 2 doze, „Anulează” → încă 2; „Ziua de azi” tăiată la textul maxim, reparată)*

---

### A5 · Check-in vocal (pe telefon) și Noutăți

**Responsabil:** Dev A · **Depinde de:** A4; B5 pentru înțelegerea și corelarea simptomelor · **Durată:** 4 h · **Branch:** `feature/a5-voice-caregiver`

**Checklist**
- [x] `VoiceCheckInView`: transcriere pe telefon cu `SFSpeechRecognizer(locale: ro-RO)`, textul apare în timp ce vorbește *(13.11.2026: `Voice/Listener.swift`, pe telefon dacă e suportat; `contextualStrings` = brandurile și DCI-urile pacientului + primele 100 din `brands.txt`; `PG_FAKE_TRANSCRIPT` în Debug)*
- [x] Atingere ca să pornească; se oprește la atingere, după 2 s de liniște sau la 60 s *(`Voice/SilenceDetector.swift`; în plus, după 4 s fără cuvinte noi, pentru zgomotul din sală)*
- [x] Inelul de ascultare care urmează nivelul vocii; static cu Reduce Motion
- [x] Transcrierea → `POST /checkins` (text) → `reply_text` citit cu TTS
- [x] Fallback: câmp text dacă recunoașterea vocală nu e disponibilă sau e refuzată
- [x] Tab-ul Noutăți: polling la 10 s, inserare sus fără să miște lista sub deget, notificare locală la evenimente grave *(`Feed/`: pastila „3 noutăți ↑”, badge pe tab, `.sensoryFeedback(.warning)`, detaliul check-in-ului; polling-ul merge pe orice tab cât aplicația e deschisă)*
- [ ] Bonus X1: cardul „Puteți lua” / „Întrebați întâi medicul” pentru `intent = can_i_take` (doar dacă S3 a fost atins la timp)

~~~text
[WORKFLOW] Branch: feature/a5-voice-caregiver.

Citește .claude/skills/apple-design/SKILL.md (§1, §3, §13, §14) și docs/DESIGN.md (2.4.2, 2.4.4, 2.4.5).

Obiectiv: Maria spune cum se simte; Ana află în câteva secunde, pe alt telefon.

1. Voice/Listener.swift (@Observable): SFSpeechRecognizer(locale: Locale(identifier: "ro-RO")); requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition; SFSpeechAudioBufferRecognitionRequest cu shouldReportPartialResults = true și contextualStrings = numele comerciale și DCI-urile din lista pacientului + cele mai frecvente ~100 de branduri din brands.txt (la testul de pregătire, „Sintrom” a ieșit „sindrom”); AVAudioEngine cu tap pe input, din care calculezi și nivelul (RMS) pentru inel. Stop la a doua atingere, după 2 s cu nivel sub prag (după ce s-a vorbit ceva) sau la 60 s. Permisiunile (microfon + recunoaștere vocală) se cer la prima atingere, după o propoziție de motiv.
2. VoiceCheckInView (fundal opac): la deschidere, TTS „Cum vă simțiți azi? Apăsați butonul și spuneți-mi.”; buton circular de 160 pt (PressableButtonStyle); sub el, transcrierea parțială apare pe măsură ce Maria vorbește (feedback continuu, §1) și eticheta de stare („Vă ascult…”, „Am înțeles, mă gândesc…”).
3. Inelul: un cerc a cărui scară urmează nivelul netezit, actualizat cu withAnimation(.pgQuick) la fiecare valoare nouă (springul pornește de la valoarea curentă, deci nu sare). Cu Reduce Motion: inel static + textul de stare.
4. La oprire: POST /checkins cu { text: transcrierea finală } → reply_text mare (22 pt) + citit cu TTS; transcrierea mică, sub el. Dacă recunoașterea vocală nu e disponibilă sau e refuzată: TextField mare + „Trimite”. (Doar dacă testul de la pregătire a arătat că recunoașterea pe telefon e slabă în română: se trimite și înregistrarea audio, iar backend-ul folosește Whisper, vezi B5.)
5. intent = can_i_take (bonus X1, doar dacă S3 a fost atins la timp): card verde liniștit („Puteți lua”) sau nisip („Întrebați întâi medicul”), textul = reply_text. *(Decizia din 14.11.2026, la 1.3: fără cardul „Puteți lua”; X1 merge și fără card, pentru că reply_text e deja citit cu voce. Dacă rămâne timp: un singur card nisip, cu reply_text.)*
6. FeedView (tab-ul Noutăți): polling GET /feed?since= la 10 s cât timp scenePhase == .active; elementele noi se inserează sus cu .pgStandard numai dacă lista e la început (ScrollPosition / onScrollGeometryChange); altfel apare o pastilă cu .regularMaterial „3 noutăți ↑” care derulează la început. Carduri pe tip: alertă nouă, doză ratată, check-in (transcriere, chip-uri cu simptome, „posibil legat de: Sintrom + Nurofen”), decizia medicului de familie (cu nota). Tap → AlertDetailView sau detaliul check-in-ului.
7. Eveniment nou cu severity critical / major sau escalate: notificare locală imediată (UNTimeIntervalNotificationTrigger 1 s) și, dacă aplicația e deschisă, .sensoryFeedback(.warning) pe același trigger cu inserarea cardului.

Criterii de acceptare: două iPhone-uri pe aceeași rețea; check-in-ul demo rostit pe telefonul 1 apare ca notificare pe telefonul 2 în < 15 s; textul apare pe ecran în timp ce Maria vorbește; înregistrarea se oprește singură când tace.

Nu face: push prin server (APNs); polling-ul ajunge pentru demo.
~~~

**Teste**
- [x] T-A5-01 Unit: detectorul de liniște oprește după 2 s sub prag și nu oprește la o pauză de 1 s sau înainte să se fi vorbit. *(`PolyGraphTests/VoiceFeedTests.swift`, `SilenceDetectorTests`; 13.11.2026: `make check-ios` verde)*
- [x] T-A5-02 Unit: feed-ul deduplică evenimentele la polling repetat (același `id`). *(`FeedModelTests`; 13.11.2026: `make check-ios` verde)*
- [x] T-A5-03 Manual: check-in-ul demo pe două telefoane, de 3 ori la rând, în zgomotul sălii; timpul până la notificare notat. *(13.11.2026: merge pe două iPhone-uri cu `DEMO_MODE=1 make dev`, notificarea sub 15 s; de repetat în zgomotul sălii)*

---

### A6 · QR de partajare, modul demo, trecerea de accesibilitate

**Responsabil:** Dev A · **Depinde de:** A3–A5, B6 · **Durată:** 1.5 h · **Branch:** `feature/a6-share-demo`

~~~text
[WORKFLOW] Branch: feature/a6-share-demo.

Citește .claude/skills/apple-design/SKILL.md (§14, §16, §17) și docs/DESIGN.md.

Obiectiv: aplicația e gata de scenă.

1. ShareSheet (.sheet, detents [.medium]): POST /share → QR generat cu CIFilter.qrCodeGenerator() (scalat fără interpolare, 260 pt, pe fundal alb și în dark mode), „Valabil până duminică, 15:00”, ShareLink cu url-ul. În modul senior: doar QR-ul și „Arătați acest cod medicului de familie”, butonul în DayView. Scanat de medicul autentificat în portal, codul îl adaugă pe pacient în lista lui.
2. Settings → Mod demo: „Resetează pacientul demo” (POST /demo/reset), „Adaugă rețeta ORL” (POST /meds cu med_09_fromilid.json din bundle), „Simulează doză ratată” (POST /demo/missed-dose).
3. Stări goale (ContentUnavailableView) cu o propoziție și o acțiune; erorile ca text inline în română, cu „Încearcă din nou”.
4. Icon și nume „PolyGraph”.
5. Trecerea finală, notată în docs/DESIGN.md: Reduce Motion (nicio mișcare spațială în fluxul demo), Increase Contrast, Reduce Transparency, Bold Text, Dynamic Type .accessibility3 în modul senior, VoiceOver pe „Acum → Am luat → Spuneți-mi cum vă simțiți”, dark mode; nicio valoare de animație / culoare scrisă de mână în afara Design/ (grep după `.spring(`, `Color(red:`, `.animation(.easeInOut`).

Criterii de acceptare: scenariul din secțiunea 7 rulează de 3 ori la rând, cu resetare între rulări, fără să atingi laptopul.
~~~

**Teste**
- [x] T-A6-01 Test static în `make check-ios`: nicio apariție de `.spring(`, `Color(red:` sau `Animation.easeInOut(` în `app/PolyGraph/` în afara `Design/`.
- [x] T-A6-02 Manual: QR-ul scanat de medic (autentificat în portal) îl adaugă pe pacient în lista lui.

---

### B1 · Ingestia datelor: `kb.sqlite`

**Status:** ✅ Integrat în `main` ([PR #4](https://github.com/VladimirTM/PolyGraph/pull/4)).

**Responsabil:** Dev B · **Depinde de:** P0, datele descărcate la pregătire · **Durată:** 5 h · **Branch:** `feature/b1-kb-ingest`

**Checklist**
- [x] `kb/ingest_ddinter.py`: CSV-urile DDInter → tabele `drug`, `ddi`, `dfi`, `duplication`
- [x] `kb/ingest_ro_catalog.py`: catalogul românesc → `product` (brand, DCI, formă, concentrație, ATC, ambalaj)
- [x] `substance` legată pe ATC5; combinațiile despărțite; `kb/overrides.csv`
- [x] Reguli YAML încărcate în tabele: `elderly_rule`, `acb`, `timing_rule`, `adverse_effect`, `food_alias`
- [x] `kb/build.py` → `kb/kb.sqlite` (comanda `make kb`), cu raport de acoperire (81,2 % din produsele cu o singură substanță legate la DDInter, sub ținta de 90 %: substanțele lipsesc din DDInter descărcabil, vezi `kb/README.md`)
- [x] Verificarea pe pacientul demo: toate substanțele găsite, perechile din 5.8 căutate în DDInter (toate nivelurile coincid cu planul), `expected_alerts.json` ajustat la realitate (regula de clasă dă încă 3 alerte: ibuprofen + omeprazol și ibuprofen + amitriptilină `moderate`, amlodipină + omeprazol `minor`; acum 27 / 6)

~~~text
[WORKFLOW] Branch: feature/b1-kb-ingest.

Obiectiv: baza de cunoștințe read-only kb/kb.sqlite, construită reproductibil din kb/raw/ (gitignored) cu make kb.

1. Schema kb.sqlite:
   - substance(id INTEGER PK, inn TEXT, dci_ro TEXT, atc TEXT, ddinter_id TEXT NULL, synonyms TEXT JSON)
   - product(id PK, brand TEXT, brand_norm TEXT, dci_raw TEXT, form TEXT, strength_text TEXT, atc TEXT, pack TEXT, gtin TEXT NULL)
   - product_substance(product_id, substance_id)
   - ddi(a_id, b_id, level TEXT CHECK in (Major, Moderate, Minor), mechanism TEXT, management TEXT, ref TEXT), cu a_id < b_id
   - dfi(substance_id, food TEXT, level, description, management)
   - duplication(a_id, b_id, note)
   - elderly_rule, acb, timing_rule, adverse_effect, food_alias: din kb/rules/*.yaml
   - gtin_cache(gtin PK, product_id) (populat la runtime de B3, în app.sqlite, nu aici)
2. ingest_ddinter.py: citește kb/raw/ddinter/ddinter_downloads_code_*.csv (coloanele: DDInterID_A, Drug_A, DDInterID_B, Drug_B, Level; vezi kb/raw/ddinter/README.md); deduplică perechile (apar în mai multe fișiere); importă **toate** nivelurile, inclusiv Unknown (necesar pentru regula de clasă); importă kb/curated_ddi.csv și kb/curated_dfi.csv cu prioritate față de DDInter. ATC-urile substanțelor DDInter nu sunt în fișiere: se iau din catalogul românesc prin potrivirea numelui (B1.4) și, pentru substanțele demo, din overrides.csv.
3. ingest_ro_catalog.py: citește kb/raw/ro/catalog_public_2026-08-04.xlsx (foaia „CP”; coloanele în kb/raw/ro/README.md: „Denumire produs”, „Formă”, „Concentrație”, „DCI”, „grupa ATC”, „Ambalaj”, „cod_cim”) și kb/ro_products_extra.csv; deduplică pe (denumire, formă, concentrație), ambalajele diferite ale aceluiași produs devin un singur produs; normalizează brand_norm (litere mici, fără diacritice, fără concentrație și formă); despică DCI-urile compuse după „+” și scoate prefixul „COMBINATII (…)”. Generează și app/PolyGraph/Resources/brands.txt (singurul fișier din app/ pe care îl atinge Dev B; îl comite într-un PR separat și îl anunță pe Dev A) (cele mai frecvente ~300 de denumiri, fără concentrație) pentru customWords din OCR (A2).
4. Legarea substanțelor: (a) ATC5 identic și substanță unică → legare directă; (b) combinații: fiecare componentă DCI latină → stem (fără -um, -inum → -in, „acidum X-icum” → „X-ic acid”) → rapidfuzz WRatio pe numele DDInter ≥ 90; (c) kb/overrides.csv (dci_ro, inn, atc, ddinter_id) are prioritate. Raport: % produse cu toate substanțele legate, lista celor nelegate, sortate după frecvența DCI.
5. Reguli YAML (deja scrise la pregătire, în kb/rules/, fiecare cu source; vezi kb/rules/README.md): elderly.yaml (13 reguli Beers 2023, potrivite pe cod ATC: atc / atc_prefix, exclude_atc, with_atc_prefix pentru combinații, count_classes_min pentru „≥ 3 medicamente active pe SNC”, condition cu duration_days_min sau strength_mg_gt), acb.yaml (substanță → scor 1–3), timing.yaml (substanță: with_food, preferred_time, min_separation: [{other: atc_prefix sau inn, hours, direction: before / after / either}], source: RCP), adverse_effects.yaml (substanță → [cod simptom din contracts/symptoms.md]), food_alias.yaml (food DDInter → etichetă RO + sinonime).
6. tests/test_kb.py: fiecare substanță din contracts/fixtures/demo_patient.json + med_09 se găsește după brand și după DCI; pentru fiecare pereche din „5.8 alertele așteptate”, testul afișează nivelul găsit în DDInter. Dacă un nivel diferă de ce scrie în plan, se actualizează contracts/fixtures/expected_alerts.json în același PR (anunțat lui Dev A), nu se modifică datele.

Criterii de acceptare: make kb < 3 min; ≥ 90% din produsele cu o singură substanță legate; pacientul demo 100%.

Nu face: motorul de alerte (B2).
~~~

> **Abatere asumată (13.11.2026):** criteriul de 90 % nu se poate atinge cu DDInter 2.0 descărcabil (doar grupele ATC A, B, D, H, L, P, R, V; substanțe uzuale ca candesartan, dabigatran, metamizol sau etoricoxib lipsesc complet din cele 1.939). Rezultatul e 81,2 %. Produsele nelegate se găsesc după brand și DCI, doar fără interacțiuni; pacientul demo e acoperit 100 %. Detalii în `kb/README.md`; ținta ar cere altă sursă de interacțiuni, în afara hackathonului.

**Teste**
- [x] T-B1-01 Toate substanțele demo legate (brand și DCI), inclusiv combinația Calciu + D3.
- [x] T-B1-02 `ddi` simetric: căutarea (a, b) și (b, a) dă același rând.
- [x] T-B1-03 Fiecare YAML validează după un schema pydantic; fiecare regulă are `source`.
- [x] T-B1-04 Coduri de simptom din `adverse_effects.yaml` ⊆ `contracts/symptoms.md`.

---

### B2 · Motorul de interacțiuni și graful

**Status:** ✅ Integrat în `main` ([PR #7](https://github.com/VladimirTM/PolyGraph/pull/7)).

**Responsabil:** Dev B · **Depinde de:** B1 · **Durată:** 5 h · **Branch:** `feature/b2-engine`

**Checklist**
- [x] `engine.analyze(patient, meds, today) → AnalysisResult` (pur, fără I/O în afară de `kb`; `backend/polygraph/kb.py` e singurul acces la `kb.sqlite`)
- [x] Verificări: DDI (curated → DDInter → regula de clasă: sora cea mai gravă din clasa ATC4 a oricăreia dintre substanțe, apoi după INN), DFI, dubluri (aceeași substanță; aceeași clasă ATC4 dintre AINS / benzodiazepine / IPP / anticoagulante; tabela `duplication`), Beers / STOPP (AINS + anticoagulant doar ca mențiune în alerta ddi), ACB, expirare
- [x] Textele RO din template-uri per `kind` (fără LLM), `engine/texts_ro.py`; `safe_recommendation` înlocuiește orice recomandare cu „opri…”, „nu mai luați” sau doze
- [x] `graph.build(...)` → JSON Cytoscape (5.6), cu muchii gri `unknown` pentru perechile fără nivel și simptomele din ultimele 7 zile (construit direct în dict-uri, fără NetworkX: nu aducea nimic în plus și ar fi fost o dependență nouă)
- [x] Rutele reale `/meds`, `/analysis`, `/what-if` în backend (SQLite `app.sqlite`), plus pacienții, `/kb/search` și `/demo/reset` (`DEMO_MODE=1`); `make dev`
- [x] Golden test: pacientul demo → exact `expected_alerts.json`

~~~text
[WORKFLOW] Branch: feature/b2-engine.

Obiectiv: inima produsului, deterministă și testată.

1. polygraph/engine/analyze.py: analyze(patient: Patient, meds: list[MedicationItem], today: date) -> AnalysisResult { alerts: list[Alert], acb_total: int, graph: Graph }. Medicamentele cu end_date < today sunt ignorate.
2. Verificări, fiecare într-un modul separat cu funcția check(ctx) -> list[Alert]:
   - ddi.py: toate perechile de substanțe din medicamente diferite; nivelul după ordinea din 5.3 (curated → DDInter direct → regula de clasă pentru Unknown, cu basis și analogy completate → nicio alertă); textul alertelor din curated_ddi.csv dacă există, altfel template-ul generic per nivel.
   - food.py: dfi pentru fiecare substanță; o singură alertă per (substanță, aliment), cu eticheta RO din food_alias.
   - duplicate.py: (a) aceeași substanță în ≥ 2 produse active → major („Același medicament sub două nume”); (b) aceeași clasă ATC4 dintr-o listă albă de clase cu risc la dublare (M01A, N05BA, N05CD, A02BC, B01AA, B01AC, C03C) → major; (c) rânduri din kb.duplication.
   - elderly.py: regulile din elderly.yaml aplicate dacă vârsta ≥ age_min; regula beers-nsaid-with-anticoagulant nu produce o alertă separată când aceeași pereche de medicamente are deja o alertă ddi (acenocumarol + ibuprofen): se pune doar o mențiune „și criteriul Beers” în detail-ul alertei ddi, ca pe ecranul Anei să rămână 4 carduri grave; duration_days_min folosește start_date (lipsă → regula se aplică cu textul „dacă îl luați de mai mult de …”).
   - acb.py: suma scorurilor; ≥ 3 → alertă anticholinergic moderate; ≥ 1 → doar acb_total.
   - expiry.py: product.expiry < today → expired, major, action replace_box.
3. Textele: polygraph/engine/texts_ro.py, template-uri per kind cu câmpurile kb (mecanism și management din DDInter rămân în engleză în detail, dar title, patient_text și recommendation sunt RO din template-uri cu numele comerciale ale pacientului). Recommendation nu conține niciodată „opriți”, „nu mai luați”, doze.
4. route_to și id-urile alertelor ca în 5.3. Rezultatul e sortat: severitate, apoi kind, apoi id.
5. polygraph/graph/build.py: NetworkX DiGraph cu nodurile și muchiile din 5.6 (pacient, produse, substanțe, clase ATC4, alimente pentru DFI, simptome raportate în ultimele 7 zile legate de substanțe); export JSON Cytoscape.
6. Persistență: polygraph/store (SQLite app.sqlite, tabele patients, meds, doses, checkins, alert_state pentru status / resolution, share_tokens, gtin_cache). Analiza se recalculează la fiecare GET /analysis (e rapidă) și se îmbină cu alert_state.
7. Rutele /meds (POST, PATCH, DELETE), /analysis, /what-if (rulează analyze cu medicamentul în plus și întoarce doar alertele noi), /kb/search.

Criterii de acceptare: tests/test_engine_golden.py: demo_patient → alertele, comparate pe (kind, severity, sorted(med_ids)), sunt exact expected_alerts.json; cu med_09 apare în plus alerta critical simvastatină + claritromicină. analyze pe 15 medicamente < 200 ms.

Nu face: extracția din poze, programul, vocea.
~~~

**Teste**
- [x] T-B2-01 Golden pe pacientul demo (fără și cu med_09), inclusiv câmpul `basis` al fiecărei alerte.
- [x] T-B2-06 Regula de clasă: o pereche `Unknown` cu o soră de clasă cu nivel → alertă cu `basis = class_analogy`; fără soră de clasă → nicio alertă; o pereche din `curated_ddi.csv` are prioritate față de analogie.
- [x] T-B2-02 Dublura „Nurofen + Ibuprofen generic” → `duplicate`, `major`.
- [x] T-B2-03 Nicio `recommendation` generată nu conține „opri”, „nu mai luați”, „mg” (test pe toate alertele posibile din pacientul demo + 20 de perechi aleatoare din DDInter).
- [x] T-B2-04 `id`-urile alertelor sunt stabile între două rulări.
- [x] T-B2-05 Graful validează după `graph.schema.json`; fiecare muchie `interacts` are `alert_id` existent.

---

### B3 · Extracția: text de pe telefon → `MedicationItem`

**Responsabil:** Dev B · **Depinde de:** B1, B2 (store) · **Durată:** 3 h · **Branch:** `feature/b3-extract`

Telefonul citește textul de pe cutie / rețetă cu OCR-ul Apple (A2) și trimite textul (plus poza). Backend-ul îl potrivește **determinist** în catalog. Gemini (tier-ul gratuit) intervine doar când potrivirea eșuează, iar răspunsurile lui se păstrează în cache.

**Checklist**
- [x] Potrivirea pe text OCR: nume comercial + concentrație + DCI, în `kb`
- [x] Parserul de posologie (notația românească „1-0-1”, „1 cp/zi”, „D.S.”, „Rp./”)
- [x] Ordinea: GTIN cache → potrivire pe text → Gemini (doar dacă e nevoie) → completare manuală
- [x] DataMatrix: parser GS1 în Python; decodare pe server cu `zxing-cpp` dacă telefonul n-a trimis codul
- [x] Client Gemini (cheie gratuită din Google AI Studio), cu cache pe hash-ul imaginii și timeout
- [x] Ruta reală `/scan`

~~~text
[WORKFLOW] Branch: feature/b3-extract.

Obiectiv: POST /v1/patients/{id}/scan întoarce candidați corecți pentru cutiile și rețeta demo, în < 3 s pe calea deterministă, și funcționează fără internet.

1. polygraph/extract/ocr_match.py (determinist, calea principală): primește ocr_lines (liniile de text în ordinea de citire, cu înălțimea relativă a fiecărei linii) și kind.
   - Cutie: normalizează (litere mici, fără diacritice, fără „®/™”); candidații de nume comercial = liniile cele mai mari + toate n-gramele de 1–3 cuvinte; potrivire rapidfuzz (WRatio ≥ 88) pe product.brand_norm; concentrația cu regex (\d+([.,]\d+)?\s?(mg|mcg|µg|g|ml|ui|UI)); dacă există mai multe produse cu același brand, alege-l pe cel cu concentrația găsită; DCI-ul scris pe cutie (liniile care se potrivesc pe substance.dci_ro) confirmă potrivirea și ridică încrederea.
   - Rețetă: segmentează pe liniile care încep cu un nume de medicament (brand sau DCI din kb); pentru fiecare segment, aceeași potrivire + posology.py pe restul liniilor până la următorul medicament; medicul / specialitatea din antet (regex pe „Dr.”, „medic”, specialitățile uzuale).
   - Rezultatul: RawExtraction (brand, strength_text, form, dci_text, pack_size, posology_text, prescriber_text, specialty) + confidence.
2. polygraph/extract/posology.py (determinist): posology_text → pattern + with_food + as_needed: „1-0-1”, „1-1-1”, „0-0-1”, „1/2 seara”, „1 cp/zi dimineața”, „de 2 ori pe zi”, „la nevoie”, „înainte de masă”, „pe stomacul gol”. Ce nu se parsează → pattern gol și needs_review.
3. polygraph/extract/match.py: ordinea gtin_cache → ocr_match → (doar dacă confidence < 0.85 sau nu s-a găsit nimic, și există imagine) gemini → nimic (needs_review, substances goale). ATC-ul vine mereu din kb, niciodată din OCR sau din LLM; și rezultatul Gemini trece prin aceeași potrivire în kb.
3b. Reguli de potrivire, învățate din testul Gemini pe 8 cutii (12.11.2026; vezi secțiunea 10): (a) se potrivește pe **substanță + doză**, nu doar pe brand: pe cutiile de generice „brandul” citit poate fi producătorul (Gemini a citit „Actavis” pentru Amlodipina Actavis, cu substanța și doza corecte), deci brandul citit se caută în `brand_norm` și în numele producătorului, iar substanța (`dci_ro`) și doza decid; (b) unitățile se normalizează înainte de comparație: `µg` = `mcg` = `ug`, `mg`/`miligrame`, virgula zecimală, `UI` = `IU` (Euthyrox a ieșit „100 µg”, catalogul scrie „100 mcg”); (c) un câmp `null` (din OCR sau din Gemini) înseamnă „nu am recunoscut”: `needs_review = true`, mesaj „fotografiați din nou cutia”, niciodată o presupunere, și nu se completează substanța din numele comercial.
4. polygraph/extract/gemini.py: modelul din variabila GEMINI_MODEL (implicit `gemini-3.1-flash-lite`, testat pe tier-ul gratuit la 12.11.2026; `gemini-2.5-flash` a dat 404, iar modelele noi `gemini-3.5-flash` / `3.8-flash` au dat 503, deci nu se pun pe drumul critic; fără aliasuri de tip `-latest`, ca modelul să nu se schimbe pe sub demo; un singur apel, fără reîncercare, decis la 13.11.2026 ca o scanare să aștepte cel mult 8 s; la 503 / 429 → needs_review) (cheia în .env, GEMINI_API_KEY), structured output după schema RawExtraction, temperatura 0, promptul: „copiază doar textul vizibil; dacă un câmp nu e vizibil, null; nu deduce substanța din numele comercial”. Timeout 8 s; la 429 sau timeout → needs_review, nu eroare. Cache: sha256(imagine) → demo/llm_cache/<hash>.json (doar răspunsurile nevide); make demo-warm trimite pozele demo o dată, cu internet.
5. polygraph/extract/gs1.py: același parser ca în app (A2, Swift), cu aceleași cazuri de test; decode_datamatrix(image) cu zxingcpp.read_barcodes ca fallback.
6. După confirmare (POST /meds cu gtin), se scrie gtin_cache, ca a doua scanare să fie instantă.
7. Logul fiecărei scanări spune ce cale a decis (gtin_cache / ocr_match / gemini / manual) și cu ce încredere: e argumentul de la pitch că LLM-ul nu e pe drumul critic.

Criterii de acceptare: tests/test_extract_demo.py pe textele OCR salvate de pe pozele demo (demo/ocr/*.json, produse la A2 cu telefonul): fiecare cutie → produsul corect pe calea ocr_match, fără Gemini; rețeta tipărită → toate medicamentele, cu pattern-ul corect; fără internet și fără potrivire → warning „nu am putut citi cutia, completați manual”, nu eroare 500.
~~~

**Status:** ✅ Backend integrat în `main` ([PR #9](https://github.com/VladimirTM/PolyGraph/pull/9)) și verificat cu cele patru capturi OCR reale din A2 și cazurile GS1 suplimentare din Swift. `/scan` și `/v1/kb/search` afișează câmpurile normalizate. Fotografiile încărcate sunt disponibile prin `GET /media/{name}`.

Cache-ul GTIN se golește la `/demo/reset`. După `make kb`, backend-ul încarcă noul catalog și ignoră asocierile legate de versiunea anterioară.

Rămase deschise după B3, închise la B7 (13.11.2026): un DataMatrix trimis, dar invalid, se caută acum în poză (`match.scan`, testat în `test_demo_b7.py`). Genericele confirmate rămân, intenționat, în afara `gtin_cache`: când brandul citit e doar substanța sau un producător care nu e în catalog, potrivirea `exact_dci` nu indică un singur produs, iar cache-ul ar afișa la a doua scanare marca altui producător; a doua scanare trece din nou prin OCR (tot sub 1 s).

**Teste**
- [x] Gemini live: o imagine sintetică a produs candidatul Sintrom 4 mg (B01AA07). Rescanarea cu cheia dezactivată a întors același candidat din cache, fără apel de rețea.
- [x] T-B3-01 `posology.py`: 20 de formulări românești reale.
- [x] T-B3-02 *(13.11.2026)* Testele trimit cele patru capturi OCR din A2 prin `POST /scan` și verifică produsele, GTIN-urile, expirarea și posologia rețetei pe calea `ocr_match`, fără apeluri Gemini.
- [x] T-B3-03 Un brand inexistent → `needs_review`, nicio substanță inventată (nici pe calea Gemini).
- [x] T-B3-04 *(13.11.2026)* Parserul Python trece cazurile din fixture-ul GS1 comun și cele trei cazuri suplimentare din `GS1Tests.swift`.
- [x] T-B3-05 OCR cu diacritice pierdute și litere confundate (`0`/`O`, `l`/`1`) pe 10 cazuri → aceeași potrivire.
- [x] T-B3-06 Normalizarea unităților: „100 µg”, „100 mcg” și „100 ug” dau aceeași potrivire în catalog; o cutie de generic cu producătorul în loc de brand („Actavis”) se potrivește pe substanță + doză; un răspuns cu toate câmpurile `null` produce `needs_review`, nu un produs.

---

### B4 · Solverul de program

**Responsabil:** Dev B · **Depinde de:** B1 (`timing_rule`), B2 · **Durată:** 2.5 h · **Branch:** `feature/b4-schedule`

~~~text
[WORKFLOW] Branch: feature/b4-schedule.

Obiectiv: GET /schedule?date= întoarce un program respectat de toate regulile de orar, cu cât mai puține momente.

1. Candidați per doză, din ancore: wake, wake+30, breakfast-30, breakfast, lunch-30, lunch, dinner-30, dinner, dinner+120, bed. Pattern-ul limitează fereastra (morning: wake…lunch-60; noon: lunch±90; evening: dinner-60…bed-60; bedtime: bed-60…bed).
2. Constrângeri dure din timing_rule și with_food: empty_stomach = ≥ 30 min înainte de o masă și ≥ 2 h după masa anterioară; before_meal = cu 15–60 min înainte; with_meal / after_meal = la masă sau la +30; min_separation între substanțe (ex. levotiroxină ↔ calciu ≥ 4 h); preferred_time (statinele cu timp de înjumătățire scurt seara, diureticele dimineața) ca preferință.
3. Căutare: backtracking peste doze ordonate după numărul de candidați (cele mai constrânse întâi), cu pruning; obiectiv lexicografic: (1) numărul de momente distincte, (2) încălcări de preferințe, (3) suma distanțelor față de ancora pattern-ului. Doze ≤ 15, candidați ≤ 10 → rapid fără OR-Tools.
4. Fiecare doză primește reasons (texte RO din regulile care au decis-o) și instruction. Momentele primesc etichete („Imediat după trezire”, „La micul dejun”, „Seara, după cină”, „La culcare”).
5. Imposibil → cea mai bună soluție relaxată + unsatisfied, iar B2 primește alerta timing aferentă.

Criterii de acceptare: tests/test_schedule_golden.py: demo_patient → expected_schedule.json (levotiroxina singură la trezire, calciul la prânz la ≥ 4 h de ea, omeprazolul înainte de micul dejun, simvastatina și amitriptilina seara, 5 momente: regula `alone: true` pentru levotiroxină, decisă la S0); solver < 100 ms.
~~~

**Teste**
- [x] T-B4-01 Golden pe pacientul demo.
- [x] T-B4-02 Proprietate: pe 200 de regimuri aleatoare din substanțele cu reguli, nicio constrângere dură încălcată când `unsatisfied` e gol.
- [x] T-B4-03 Ancore schimbate (trezire 05:30) → programul se mută coerent.

---

### B5 · Simptomele: înțelegere, corelare, escaladare

**Responsabil:** Dev B · **Depinde de:** B2 · **Durată:** 2.5 h · **Branch:** `feature/b5-symptoms`

Transcrierea se face pe telefon (A5), deci backend-ul primește text. Whisper intră doar dacă testul de la pregătire arată că recunoașterea vocală iOS e slabă în română (punctul 6).

~~~text
[WORKFLOW] Branch: feature/b5-symptoms.

Obiectiv: POST /checkins transformă propoziția unui vârstnic (deja transcrisă) în simptome codificate, le leagă determinist de medicamente și decide escaladarea.

1. polygraph/voice/understand.py: calea principală, deterministă: potrivire de sinonime din symptoms.md (rapidfuzz partial_ratio ≥ 85 pe n-grame) → { intent, symptoms: [{code, severity}], drug_query }; intent din cuvinte-cheie („pot să iau” → can_i_take). drug_query se potrivește întâi pe medicamentele pacientului (listă mică, prag mai permisiv, plus potrivire fonetică: „sindrom” → Sintrom, pentru că dictarea transformă numele comerciale în cuvinte românești apropiate), abia apoi pe tot catalogul, cu prag strict; cuvintele românești uzuale (sindrom, calciu etc.) nu se potrivesc singure pe catalog. Rezerva (doar dacă nu s-a găsit niciun simptom și textul are > 5 cuvinte): Gemini din tier-ul gratuit, cu output constrâns la enum-ul generat din contracts/symptoms.md (codurile necunoscute nu pot fi produse), timeout 5 s. Textul e normalizat întâi (litere mici, fără diacritice), pentru că transcrierea poate pierde diacriticele.
2. polygraph/voice/correlate.py (determinist): pentru fiecare simptom: (a) alertele deschise ale căror efecte (adverse_effects.yaml pe substanțele implicate, plus o hartă mică alertă → simptome, ex. ddi sângerare → bruising, bleeding_gums, black_stool) conțin codul → basis "alert:<id>"; (b) substanțele active cu efectul în adverse_effects.yaml → basis "adverse_effects.yaml". escalate = orice red_flag sau orice corelare cu o alertă major / critical.
3. reply_text din template-uri: mulțumire + „I-am trimis Anei” dacă escalate + un sfat de siguranță generic per simptom (ex. dizziness_orthostatic → „Ridicați-vă încet din pat”), scris de mână în symptoms.md, nu de LLM.
4. Check-in-ul se salvează, intră în feed dacă escalate și apare în graf (nod symptom legat de substanțe).
5. (X1, doar dacă S3 a fost atins la timp) intent = can_i_take: drug_query → match.py (B3) → engine what-if → reply_text din template. *(Decizia din 14.11.2026, la 1.3: niciodată „puteți lua”, fără farmacist; răspunsul după cea mai gravă alertă nouă: grav → numele, motivul, „nu luați X până nu vă răspunde medicul de familie” + eveniment `checkin` în Noutăți; moderat → „am notat întrebarea”, fără eveniment; nimic găsit → „nu am găsit o interacțiune cunoscută”, fără eveniment; fără date → „nu am date despre …” + eveniment cu `severity` null. `escalate` rămâne false.)*
6. (Doar dacă recunoașterea vocală iOS a picat testul de la pregătire) polygraph/voice/stt.py: multipart audio → Whisper (API, language="ro"; altfel faster-whisper local) → același pipeline.

Criterii de acceptare: tests/test_voice_demo.py: checkin_demo → simptomele și corelările din fixture; 3 transcrieri reale făcute cu iPhone-ul la pregătire (demo/transcripts/*.txt, cu greșelile de recunoaștere cu tot) → aceleași coduri.
~~~

**Teste**
- [x] T-B5-01 Calea deterministă recunoaște simptomele din 10 propoziții de test (inclusiv fără diacritice), fără niciun apel la Gemini.
- [x] T-B5-02 LLM-ul nu poate întoarce un cod din afara enum-ului (test cu un răspuns falsificat → respins).
- [x] T-B5-03 `POST /checkins` (text) < 4 s pe laptopul de demo.
- [x] T-B5-04 *(X1, 14.11.2026)* „Pot să iau…?” pe severități: aspirină → grav, eveniment în Noutăți valid după schemă; paracetamol → moderat, fără eveniment; Algocalmin → fără date, eveniment cu `severity` null; nimic găsit (alerte falsificate) → fără eveniment; Nurofen de pe listă neschimbat; niciun răspuns cu „puteți lua” sau „farmacist” (`tests/test_can_i_take.py`); aspirina apare în Noutăți în `make demo-check`.

---

### B6 · Portalul medicului de familie și versiunea de tipărit

**Responsabil:** Dev B · **Depinde de:** B2, B4 · **Durată:** 3 h · **Branch:** `feature/b6-doctor-portal`

~~~text
[WORKFLOW] Branch: feature/b6-doctor-portal.

Citește .claude/skills/apple-design/SKILL.md: portalul e web, deci skill-ul se aplică direct (§1, §7, §12, §14, §15, §16), fără traducerea SwiftUI din docs/DESIGN.md; din DESIGN.md iei doar culorile, severitățile și textele.

Obiectiv: medicul de familie vede, într-un singur loc, pacienții care i-au partajat tratamentul și înțelege situația fiecăruia în 30 de secunde: inclusiv ce n-a prescris niciun medic (OTC-urile) și ce au prescris ceilalți specialiști.

1. POST /v1/patients/{id}/share → token aleator (secrets.token_urlsafe(16)), expires_at = acum + 72 h, în share_tokens. GET /share/{token} (linkul din QR-ul aplicației): cu sesiunea portalului, pacientul intră în lista medicului și pagina redirecționează la fișa lui (303); fără sesiune, autentificarea, care revine la link; token expirat / inexistent → pagina „Linkul a expirat” (404, fără date).
2. Autentificarea: POST /portal/login cu codul de acces (hash în tabela doctors), sesiune prin cookie HttpOnly, SameSite=Lax, 12 h; `next` doar spre căi locale; POST /portal/logout. În demo: medicul „dr. Elena Popa”, codul din PG_DOCTOR_CODE (implicit medic-demo), cu pacientul demo și încă doi pacienți în listă, recreați la /demo/reset.
3. GET /portal: lista „Pacienții mei”: nume, vârstă, numărul de medicamente, ACB, ultimul check-in, titlurile alertelor grave nerevizuite; sus pacienții cu semnale de la familie (check-in escaladat în ultimele 7 zile), apoi cei cu cele mai multe alerte grave nerevizuite.
4. GET /portal/patients/{id} (Jinja2 + un singur CSS + cytoscape.min.js servit local; 404 dacă pacientul nu e în lista medicului): antet (nume, vârstă, „Fișă generată de PolyGraph; nu înlocuiește evaluarea clinică”), rezumatul („8 medicamente de la 5 medici · 5 alerte grave · ACB 3 · aderență 86% în ultimele 7 zile”), alertele grave, tabelul medicamentelor (brand, DCI, ATC, posologie, prescriptor, de când), celelalte alerte, graful, check-in-urile din ultimele 7 zile, programul zilei. Pe fiecare alertă: „Menține” / „Modific la consultație” / „Trimit la specialist” + notă opțională → POST /portal/patients/{id}/alerts/{alert_id}/review → status reviewed_by_doctor, resolution.decision și evenimentul doctor_reviewed în Noutăți (A5); decizia apare pe alertă în aplicație (A3).
   Design (skill-ul, aplicat pe web):
   - tipografie: font: 100%/1.5 system-ui; titlul paginii cu letter-spacing -0.02em și line-height 1.1, corpul la 0, notele mici la +0.01em; spațieri în rem, ca zoom-ul și mărimea textului din browser să nu strice layout-ul;
   - antet sticky translucid (background rgba 0.7 + backdrop-filter: blur(20px) saturate(180%)), conținutul derulează pe sub el; în loc de border, un gradient de margine afișat doar când pagina e derulată;
   - ordinea pe ecran = ordinea importanței: rezumatul, apoi alertele grave, apoi restul; detaliile (mecanism, ATC) în <details> deschis la cerere;
   - butoanele de decizie cu :active { transform: scale(0.97) } instant; trimiterea prin fetch, cu starea schimbată inline („Modific la consultație · acum”), fără reîncărcarea paginii; eroarea inline, lângă butoane;
   - @media (prefers-reduced-motion: reduce) fără tranziții de poziție; (prefers-reduced-transparency: reduce) antet opac; (prefers-contrast: more) fundaluri solide și margini vizibile; dark mode cu prefers-color-scheme;
   - un singur fișier CSS, fără framework; doar transform și opacity în tranziții.
5. GET /share/{token}/graph?embed=1: doar graful, pe tot ecranul, pentru WKWebView-ul din app (A3), cu fundal transparent, aceleași culori și același font (-apple-system) ca aplicația; tap pe o muchie → window.webkit.messageHandlers.alert.postMessage(alert_id). În portal, graful e și pe tot ecranul la /portal/patients/{id}/graph.
6. GET /portal/patients/{id}/print: „Reconcilierea medicației”, cu un stylesheet @media print (fără graf interactiv, fără butoane, A4, 1–2 pagini): medicamente (pe prescriptori), probleme găsite (cu sursa și decizia, dacă există), întrebări propuse pentru consultație (din template-uri per kind), spațiu pentru concluzie și semnătură. Medicul o salvează ca PDF din browser; fără WeasyPrint.
7. Paginile au date medicale: Cache-Control no-store, Referrer-Policy no-referrer, X-Robots-Tag noindex, CSP doar cu 'self'.

Criterii de acceptare: fișa se încarcă în < 2 s pe rețeaua locală; versiunea de tipărit a pacientului demo încape în ≤ 2 pagini A4 (Print Preview în Safari) și are toate alertele major / critical; o decizie luată în portal apare în app la următorul polling; un medic nu poate deschide fișa unui pacient care nu e în lista lui.
~~~

**Teste**
- [x] T-B6-01 Token expirat / inexistent → 404 cu pagina prietenoasă, fără date.
- [x] T-B6-02 HTML-ul de la `/print` conține fiecare alertă `major` / `critical`.
- [x] T-B6-03 Escape HTML pe nota medicului (XSS simplu: `<script>` rămâne text).
- [x] T-B6-05 Portalul: fără sesiune → autentificare, fără date; un medic vede doar pacienții din lista lui (404 pentru ceilalți); `next` doar spre căi locale.
- [x] T-B6-06 Linkul din QR adaugă pacientul în lista medicului autentificat; fără sesiune, autentificarea revine la link.
- [x] T-B6-07 Decizia + nota ajung pe alertă (`reviewed_by_doctor`) și în Noutăți (`doctor_reviewed`), validate după contracte.
- [x] T-B6-04 *(14.11.2026)* Manual: pagina pe un iPhone cu Reduce Motion, Reduce Transparency și Increase Contrast pornite; pe desktop la zoom 200%.

---

### B7 · Demo hardening

**Responsabil:** Dev B · **Depinde de:** B2–B6 · **Durată:** 3 h · **Branch:** `chore/b7-demo-hardening`

~~~text
[WORKFLOW] Branch: chore/b7-demo-hardening.

Obiectiv: demo-ul nu poate pica din cauza rețelei, a sălii sau a unui LLM lent.

1. POST /demo/reset (doar cu DEMO_MODE=1): șterge pacientul demo și îl recreează din fixture (8 medicamente, cu fotografiile din demo/photos/, istoric de doze pe 7 zile cu 2 doze ratate, un check-in vechi fără simptome). POST /demo/missed-dose.
2. make demo-warm (cache LLM pentru toate pozele și pentru transcrierea înregistrărilor demo); make demo-check (R4): rulează scenariul din secțiunea 7 prin API și compară cu expected_*.json.
3. Timeouts: LLM 12 s, apoi fallback (cache sau „completați manual”); check-in: LLM 5 s, apoi potrivirea de sinonime.
4. Pornire într-o singură comandă: make demo (backend pe 0.0.0.0:8000, afișează IP-ul local și un QR cu baseURL pentru setările app-ului).
5. Loguri lizibile în terminal pentru momentele cheie (scan, alertă nouă, check-in escaladat): pot fi arătate juriului dacă întreabă „cum e determinist?”.

Criterii de acceptare: cu Wi-Fi-ul laptopului oprit (telefoanele pe hotspot-ul laptopului), make demo-check e verde.
~~~

**Status:** ✅ pe `chore/b7-demo-hardening` (13.11.2026). Ce s-a făcut, pe punctele promptului:

1. `/demo/reset` recreează și istoricul (`polygraph/demo/seed.py`): dozele din ultimele 7 zile din programul real, toate „Am luat” în afară de 2 (Calciu + D3 acum 2 zile, simvastatina acum 5 zile), care apar ca `dose_missed` în Noutăți, și un check-in vechi fără simptome; ziua de azi rămâne neatinsă, ca „Acum” să pornească de la Euthyrox. Fotografiile vin din `demo/photos/med_0N.jpg` (servite deja de `/media`); folderul e încă gol, deci aplicația arată imaginea neutră până le punem. `POST /demo/missed-dose` e real: ultimul moment de azi care a trecut, cu dozele neconfirmate → eveniment în Noutăți.
2. `make demo-warm` pune în cache și răspunsurile Gemini pentru transcrieri (doar cele pe care sinonimele nu le înțeleg; acum, niciuna). `make demo-check` (`polygraph/demo/check.py`) rulează scenariul din secțiunea 7 prin API (reset cu `live_scan`, scanarea Sintrom + Nurofen și a doua scanare din cache, alertele = `expected_alerts.json`, graful, programul = `expected_schedule.json`, „Am luat” idempotent, check-in-ul demo < 4 s, rețeta ORL cu alerta critică, portalul cu decizia, tipărirea, doza ratată) și compară cu fixture-urile; implicit în proces, cu Gemini oprit, sau `URL=…` pe serverul pornit.
3. Termen **total** pentru Gemini (`polygraph/deadline.py`; `urlopen(timeout)` nu acoperă DNS-ul și răspunsurile lente): scanarea rămâne la **8 s** (decizia din 13.11.2026 de la B3, mai strictă decât cele 12 s din prompt), check-in-ul la 5 s, apoi calea deterministă / completarea manuală.
4. `make demo`: backend-ul pe 0.0.0.0:8000 cu DEMO_MODE=1, fără `--reload`, adresele locale (hotspot-ul `bridge100` primul), QR-ul cu baseURL desenat în terminal (cu zxing-cpp, fără dependențe noi), adresa portalului și ce lipsește din pregătire.
5. Loguri `SCAN` (calea și încrederea), `ALERTĂ` (alerta nouă și sursa), `CHECK-IN` (sinonime sau Gemini, escaladare), `DOZĂ`, `DEMO`. În plus: un medicament nou cu alerte `major` / `critical` creează `alert_new` în Noutăți (pentru pasul 2:10 „pe ambele telefoane”).

**Teste**
- [x] T-B7-01 Reset: 7 zile de doze cu exact 2 ratate (și în Noutăți), check-in-ul vechi valid după contract, azi neatins; resetul repetat de 3 ori dă aceeași stare; portalul arată aderența.
- [x] T-B7-02 `/demo/missed-dose`: evenimentul valid după `feed_event.schema.json` și prezent în Noutăți; 404 fără DEMO_MODE.
- [x] T-B7-03 Gemini blocat 3 s: scanarea și check-in-ul răspund sub 1 s cu termenul redus (rezerva deterministă); răspunsul la check-in vine din cache a doua oară.
- [x] T-B7-04 `make demo-check` verde în proces (Gemini oprit) și pe serverul pornit cu `make demo`; un pas stricat apare cu ✗ și ieșirea e 1.
- [x] T-B7-05 Alertele grave noi după rețeta ORL ajung în Noutăți (critică + gravă), fără „opriți” / „nu mai luați”; DataMatrix greșit → codul citit din poză.
- [x] T-B7-06 *(14.11.2026)* Manual: Wi-Fi-ul laptopului oprit, telefoanele pe hotspot-ul laptopului, `make demo` + `make demo-check URL=http://127.0.0.1:8000` verde, apoi scenariul pe telefoane.

---

### Q · Verificarea pe simulator, făcută de agent, după fiecare milestone

**Ce este.** După S1, S2, S3 și S4, un agent (o sesiune **nouă**, de preferat de la alt furnizor decât cel care a scris codul: Gemini CLI) rulează aplicația pe simulatorul iOS, parcurge fiecare funcționalitate livrată până atunci și scrie un raport cu bug-uri, inconsistențe și îmbunătățiri de UI/UX, fiecare cu o captură de ecran și un fix propus. Agentul de review **nu modifică codul aplicației**: doar raportează și poate adăuga teste în `PolyGraphUITests/`. Voi alegeți ce se repară; fix-urile le face apoi agentul obișnuit, pe branch-uri `fix/qN-…`.

**De ce o sesiune nouă:** agentul care a scris ecranul tinde să-și confirme propria muncă. O sesiune care pornește doar de la plan, `docs/DESIGN.md` și skill vede aplicația ca un utilizator nou.

| Review | Când | Unde rulează | Ce acoperă | Cât costă oamenii |
|---|---|---|---|---|
| **Q1** | după S1 (W8), **peste noapte** | Mac-ul lui Dev A, cât dormiți | onboarding, navigarea, medicamentele și alertele pe mock, sheet-ul de confirmare cu scanarea simulată | 10 min de triere dimineața |
| **Q2** | după S2 (W14) | Mac-ul lui Dev B, în paralel cu lucrul | fluxul real: scanare → confirmare → alerte → graf; erorile de rețea; + verificarea fix-urilor din Q1 | 10 min de triere |
| **Q3** | după S3 + A5 / B6 (W23), **peste noapte** | Mac-ul lui Dev A | tot MVP-ul: modul senior, programul, „Am luat”, check-in-ul, Noutăți, portalul medicului; toate variantele de accesibilitate | 15 min de triere dimineața; fix-urile blocker / major în W23–W24.5 |
| **Q4** | la S4 (W24.5), primele 45 min din D1 | Mac-ul lui Dev B | scenariul demo din secțiunea 7, cap-coadă, de 2 ori; regresia tuturor constatărilor închise | se repară doar blocker-ele |

Fiecare Q verifică din nou și constatările rămase deschise din Q-urile anterioare.

#### Q0 · Infrastructura de review

**Responsabil:** un agent pornit de Dev A într-un worktree separat (`git worktree add ../polygraph-q0 -b test/q0-review-tour`), în paralel cu A2 · **Depinde de:** A1 · **Durată:** ~1 h de agent, ~5 min de om · **Se termină:** înainte de S1

Pe simulator nu există cameră, scanner VisionKit, microfon, recunoaștere vocală reală sau haptic. Aplicația le poate simula **doar în build-ul Debug**, prin variabile de mediu (hook-urile sunt adăugate la A1, punctul 9):

| Variabilă | Efect |
|---|---|
| `PG_BASE_URL` | adresa backend-ului (`http://127.0.0.1:8000` pe simulator) |
| `PG_ROLE` = `senior` / `caregiver`, `PG_SKIP_ONBOARDING=1` | pornește direct în modul cerut, cu pacientul demo |
| `PG_RESET_DEMO=1` | la pornire cheamă `POST /demo/reset` (sau, pe mock, reîncarcă fixture-urile) |
| `PG_FAKE_SCAN` = `sintrom` / `klacid_rx` / `unreadable` … | în locul camerei apare o „cameră falsă” cu poza din `DebugAssets/` și codul DataMatrix din `gs1_cases.json`; fluxul de după (upload, confirmare) e cel real |
| `PG_FAKE_TRANSCRIPT` = text | `Listener` emite textul cuvânt cu cuvânt (rezultate parțiale la 150 ms) și apoi liniște, deci se exercită tot UI-ul de ascultare |
| `PG_NOW` = dată și oră ISO | ceasul aplicației (pentru „momentul curent” dimineața, la prânz, seara) |
| `PG_REDUCE_MOTION=1` | forțează comportamentul Reduce Motion (simulatorul nu îl poate porni din linia de comandă) |

~~~text
[WORKFLOW] Branch: test/q0-review-tour (în worktree-ul separat; atingi doar app/PolyGraphUITests/, app/PolyGraph.xctestplan-urile, tools/review/ și Makefile).

Obiectiv: un tur automat al aplicației pe simulator care produce, pentru fiecare ecran și fiecare variantă de afișare, o captură de ecran, lista textelor vizibile și rezultatul auditului de accesibilitate. Pe baza lui, agentul de review (Q1–Q4) judecă aplicația.

1. Ținta PolyGraphUITests (XCUITest). ReviewTour.swift cu câte un test per flux, fiecare pornind aplicația cu variabilele de mediu din tabelul Q0: testOnboarding, testCaregiverMeds, testCaregiverAlertsAndDetail, testGraph, testScanBoxFake, testScanPrescriptionFake, testScanUnreadable, testSeniorNowMorning / Noon / Evening (PG_NOW), testTakenAndUndo, testDay, testVoiceCheckInFake, testFeed, testShare, testSettingsDemo, testBackendDown (PG_BASE_URL către un port închis). Testele sunt toleranți: dacă un ecran nu există încă (etapa nu e gata), notează „absent” și trec mai departe, nu pică.
2. La fiecare pas: XCTAttachment cu captura (numele: <flux>-<pas>-<variantă>), plus un fișier JSON cu toate elementele vizibile (tip, label, identifier, frame, isHittable) din app.descendants(matching: .any); la finalul fiecărui ecran, try app.performAccessibilityAudit() cu erorile colectate (nu oprite) într-un JSON.
3. Test plan-uri: Review.xctestplan cu configurațiile Light, Dark, AX (argumentul de lansare -UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXL), Motion (PG_REDUCE_MOTION=1), Contrast (după `xcrun simctl ui <udid> increase_contrast enabled`, setat de script).
4. tools/review/run.sh <QN>:
   - alege simulatorul: primul iPhone disponibil cu cel mai nou iOS (`xcrun simctl list devices available -j`), îl pornește; `xcrun simctl status_bar <udid> override --time 9:41 --batteryLevel 100` pentru capturi curate;
   - pornește backend-ul (`make demo` cu DEMO_MODE=1; înainte de B2, `make mock`) și așteaptă /health;
   - `xcodebuild test -scheme PolyGraph -testPlan Review -destination id=<udid> -resultBundlePath .review/<QN>/result.xcresult`;
   - `xcrun xcresulttool export attachments --path … --output-path .review/<QN>/shots`;
   - salvează logul aplicației (`xcrun simctl spawn <udid> log show --last 30m --predicate 'subsystem == "ro.polygraph"'`) și logul backend-ului;
   - pentru animațiile lucrate („Am luat”, inelul microfonului): `xcrun simctl io <udid> recordVideo` cât rulează testTakenAndUndo și testVoiceCheckInFake, apoi `ffmpeg` extrage cadrele la 0, 100, 200, 300, 500, 800 ms după atingere în .review/<QN>/frames/;
   - scrie .review/<QN>/index.md: lista capturilor pe flux și variantă, numărul de erori de audit, durata.
5. Makefile: `make review Q=Q1` rulează scriptul. .review/ e în .gitignore (capturile sunt mari); raportul final merge în docs/reviews/.
6. .claude/settings.json: permisiuni pre-aprobate pentru xcodebuild, xcrun, make, ffmpeg, git, curl pe localhost, ca turul de noapte să nu se oprească așteptând aprobări; echivalentul pentru agentul de review (Gemini CLI: comenzile permise în setările proiectului sau modul fără confirmări, doar în acest repo).

Criterii de acceptare: `make review Q=Q0` rulează cap-coadă pe aplicația de la A1 (ecranele lipsă apar ca „absent”), în < 15 min, și produce capturi în toate cele 5 configurații.
~~~

#### Promptul pentru agentul de review (Q1–Q4)

**Notă (12.11.2026):** Codex CLI și Gemini CLI au fost sărite la pregătire (secțiunea 10). Dacă nu sunt instalate la hackathon, review-ul rulează pe Claude Code, într-o sesiune nouă, fără contextul celei care a scris codul, și cu atenție la limitele de 5 h. Se pornește o **sesiune nouă de Gemini CLI** (contul Google AI Pro) în repo, pe `main` actualizat, cu promptul de mai jos; dacă Gemini CLI nu poate citi capturile de ecran (testat la pregătire), Codex CLI, iar Claude Code doar ca ultimă variantă, ca să nu consume limitele folosite pentru cod (`QN` și lista de etape se completează). Pentru rulările de noapte: laptopul la priză, `caffeinate -dimsu &`, capacul deschis.

~~~text
Ești agentul de review pentru PolyGraph. NU modifici codul din app/PolyGraph/ sau backend/. Poți rula orice, poți citi orice și poți adăuga teste în app/PolyGraphUITests/ (pe branch-ul test/QN-review). Lucrezi singur, fără să aștepți răspunsuri: nimeni nu e la calculator.

Context de citit întâi: docs/PLAN.md (secțiunile 1, 2.4, 5, 7 și etapele livrate: <lista>), docs/DESIGN.md, .claude/skills/apple-design/SKILL.md, contracts/fixtures/expected_alerts.json, contracts/symptoms.md și rapoartele anterioare din docs/reviews/.

1. Rulează `make review Q=QN`. Dacă pică din cauza infrastructurii (simulator, build), repară doar scriptul / testele UI, nu aplicația; dacă build-ul aplicației pică, oprește-te și scrie un raport cu eroarea ca blocker.
2. Pentru fiecare flux și fiecare variantă (Light, Dark, AX, Motion, Contrast), deschide capturile și JSON-urile și verifică, în ordinea asta:
   a. Funcțional: fiecare feature livrat (secțiunea 1.2) face ce spun criteriile de acceptare ale etapei lui; alertele afișate pentru pacientul demo = expected_alerts.json (aceleași, aceeași ordine, aceleași severități); programul = expected_schedule.json; check-in-ul demo produce simptomele și corelările din fixture; erorile din logul aplicației și al backend-ului.
   b. Siguranța conținutului: niciun text vizibil care spune „opriți”, „nu mai luați” sau o doză nouă; nicio alertă fără sursă în modul aparținător; niciun roșu și niciun jargon (ATC, DDI, „farmacocinetic”, coduri) în modul senior.
   c. Consistență: aceeași acțiune are același nume peste tot („Am luat”, nu și „Luat” / „Confirmă”); același termen pentru același lucru (medicament / pastilă / cutie, folosite consecvent); diacritice corecte; formatul orei (24 h, „ora 13”); etichetele severității identice în card, detaliu, feed și portalul medicului; aceleași componente arată și se comportă la fel pe ecrane diferite.
   d. Designul (DESIGN.md și skill-ul): răspuns instant la apăsare; componente de sistem folosite acolo unde DESIGN.md o cere; consistență spațială (detaliul iese din card și se întoarce în el); fără animații cu overshoot în afara gesturilor cu impuls; suprafețe opace în modul senior; din cadrele extrase: „Am luat” fără salturi între cadre și fără mișcare cu PG_REDUCE_MOTION.
   e. Accesibilitate: erorile din performAccessibilityAudit; în varianta AX, text tăiat sau elemente suprapuse; ținte de atingere în modul senior < 72 pt (din frame-urile din JSON); butoane fără label; contrast vizibil insuficient în Dark și Contrast.
   f. UX pentru vârstnici (2.4.2): o singură acțiune principală pe ecran; nicio acțiune disponibilă doar prin gest; ce urmează e clar fără explicații; stările de status, finalizare, avertizare și eroare (2.4.6) există și sunt în cuvinte simple.
   g. Stări limită: backend oprit, cutie ilizibilă, listă goală, alertă revizuită de medic, medicament expirat, moment fără doze.
3. Re-verifică fiecare constatare deschisă din rapoartele anterioare: închisă / încă deschisă / regresie.
4. Scrie docs/reviews/QN.md:
   - rezumat în 5 rânduri: ce merge, câte constatări pe severitate, cele 3 cele mai importante;
   - tabelul constatărilor: ID (QN-01…), ecran, tip (bug / inconsistență / UX / design / accesibilitate / siguranță conținut), severitate (blocker = demo-ul sau o alertă e greșită / major = vizibil în demo sau la juriu / minor / polish), pașii de reproducere (cu variabilele de mediu), ce se așteaptă vs ce se întâmplă, captura (calea din .review/QN/shots/), fix-ul propus în 1–3 rânduri, estimarea (< 15 min / < 1 h / mai mult);
   - pentru fiecare blocker și major, un prompt gata de dat agentului de implementare (branch fix/qN-<id>, fișierele probabile, criteriul de acceptare, testul UI care îl prinde);
   - lista de idei de îmbunătățire separată, scurtă, marcată „după hackathon” dacă depășește 1 h;
   - tabelul constatărilor anterioare cu starea lor.
5. Copiază în docs/reviews/QN/ doar capturile citate în raport (redimensionate la 600 px lățime), commit pe test/QN-review, push, PR cu titlul „Review QN” și rezumatul în descriere.

Reguli: fără constatări vagi („ar putea fi mai frumos”); fiecare constatare are o captură și o propunere concretă. Nu raporta ce DESIGN.md decide explicit altfel decât skill-ul (2.4.2). Nu raporta ca bug lipsa unei etape care nu e încă în lista celor livrate. Maximum 25 de constatări: dacă găsești mai multe, păstrează cele mai grave și notează câte ai omis.
~~~

#### Trierea (oamenii, 10–15 min)

1. Citiți rezumatul și tabelul din `docs/reviews/QN.md`.
2. Fiecare constatare primește o decizie în coloana „Decizie”: **acum** (blocker-ele, mereu), **etapa următoare** (major-ele sub 1 h), **după hackathon**, **nu** (cu motivul într-un cuvânt).
3. Prompturile pentru „acum” se dau agentului de implementare, fiecare pe branch-ul lui `fix/qN-…`, cu `make check` și rulat pe iPhone înainte de merge.
4. Un sync point nu e considerat trecut cât timp raportul Q aferent are un blocker cu decizia „acum” încă deschis.

**Teste**
- [ ] T-Q-01 `make review Q=QN` produce capturi pentru toate fluxurile livrate, în toate cele 5 configurații.
- [ ] T-Q-02 Raportul are pentru fiecare constatare captură, pași de reproducere și fix propus.
- [ ] T-Q-03 Q4: scenariul demo trece de 2 ori la rând pe simulator, fără blocker deschis.

---

### QA · Testarea web și backend (14.11.2026) și planul de reparații

**Ce este.** Pe 14.11.2026, după X1 și paginile web refăcute (`chore/restante-dupa-x1`), un agent a testat cap-coadă partea lui Dev B: portalul, pagina de prezentare și API-ul. Q1–Q4 verifică aplicația pe simulator; QA verifică web-ul și backend-ul, apoi compară fiecare constatare cu aplicația, ca o reparație să nu facă cele două platforme să spună lucruri diferite. Raportul complet, cu capturi și pașii de reproducere: [PolyGraph · raport de testare web și backend](https://claude.ai/artifact/3X6KzAHid224S9xra2tALR).

**Cum s-a testat:**
- **Chrome, pe `make demo` (`localhost:8000`):** paginile, popover-ele, „Arată cele 22”, tap pe graf, deciziile (cu `fetch` simulat: 401, 500, rețea căzută, dublu-click), logout, login. Fără scrieri în baza demo.
- **Un server separat, cu bază temporară:** ~150 de cazuri HTTP (token străin, corpuri invalide, 3 MB, HTML/SQL, path traversal, concurență, scalare până la 37 de medicamente, expirări).
- **Chromium headless:** 8 pagini × 375 / 640 / 1280 px × light / dark, tastatură, tipărire.
- **Neacoperit:** aplicația iOS (rămâne la Q3 / Q4), scanarea cu Gemini real, al doilea medic.

**Ce merge** (nu mai trebuie re-testat înainte de demo): zero erori 500; HTML escapat pe toate paginile; izolarea pacienților și a medicilor; expirarea link-ului și a sesiunii; `no-store` la înapoi după logout; nicio depășire de layout la 375–1280 px; focus vizibil; tipărirea pe 2 pagini A4; 60 de analize în paralel în 0,2 s.

#### Constatările

Coloana „Platforme” spune unde se vede problema. „Ambele” = backend-ul trimite același lucru aplicației și portalului, deci reparația dintr-un loc le schimbă pe amândouă.

| ID | Severitate | Constatare | Platforme | Unde | Etapa |
|---|---|---|---|---|---|
| QA-01 | mare (demo) | Graful web desenează muchiile neutre gri opac `#999` și bordura medicamentelor neagră: Cytoscape nu înțelege `rgb(0 0 0 / 0.1)` din `--line` | web | `share/static/share.css`, `graph.js` | QA2 |
| QA-02 | mare (risc) | `/analysis` și `/schedule` cresc exploziv: 24 de medicamente = 0,4 s, 30 = 1,5 s, 37 = 29 s; serverul are un singur proces, deci totul așteaptă | ambele | `schedule/solver.py` `solve()`, apelat din `engine/timing.py` | QA1 |
| QA-03 | medie (siguranță) | Medicament cu `substances: []`: niciun avertisment, interacțiunile lui nu se verifică, fișa arată „nicio alertă” | ambele | `engine/analyze.py` | QA1 |
| QA-04 | medie (demo) | Eticheta alimentului din graf e „k” în loc de „alimente bogate în vitamina K”: id-ul e reconstruit cu `rsplit("_")` din id-ul alertei | ambele | `graph/build.py` (r. 98) | QA2 |
| QA-05 | mică (demo) | Substanțe în engleză în graf și pe fișă („calcium carbonate”) | ambele | `graph/build.py`, `share/view.py` | QA2 |
| QA-06 | mică (demo) | „1 alertă revizuită · trimise familiei” | web | `share/view.py` `portal_summary` | QA0 |
| QA-07 | mică | 10 decizii pe aceeași alertă = 10 evenimente în Noutăți (10 notificări la familie); dublu-click-ul e oprit doar în JS | ambele | `api/main.py` `review_alert` | QA1 |
| QA-08 | mică | `end_date` înainte de `start_date` e acceptat, apoi medicamentul dispare din fișă fără urmă | ambele | `add_med` | QA1 |
| QA-09 | mică | Valori neplauzibile fără semnal: 100 de comprimate dimineața, 0-0-0-0 fără „la nevoie”, doză în 2030, `what-if` doar cu spații | ambele | `add_med`, `/doses`, `/what-if` | QA1 |
| QA-10 | mică | `POST /meds` cu un id existent redenumește în tăcere (`med_01` → `med_02`): o cerere reluată de aplicație dublează medicamentul | ambele | `store.free_med_id` | QA1 |
| QA-11 | mică | Numele pacientului n-are limită (3 MB acceptați) | ambele | `contracts/schema/patient_create.schema.json` | QA1 |
| QA-12 | mică | Cytoscape își injectează un `<style>`, blocat de CSP: eroare în consolă + „container position:static” | web | `share.css`, CSP | QA2 |
| QA-13 | mică | Pacient fără medicamente: secțiuni goale fără mesaj, graful e un dreptunghi gol (aplicația are `ContentUnavailableView`) | web | `templates/page.html` | QA3 |
| QA-14 | mică | Enter în nota pentru familie nu face nimic și nu explică de ce | web | `static/share.js` | QA4 |
| QA-15 | mică | După un cod greșit adresa rămâne `/portal/login` (POST); refresh-ul cere retrimiterea | web | `portal_login` | QA1 |
| QA-16 | mică | La eroare 500, mesajul spune „Verificați conexiunea” | web | `static/share.js` | QA4 |

#### Consistența între aplicație și web

Regula pentru toate etapele de mai jos: **un lucru pe care îl văd și familia, și medicul are o singură sursă**, iar unde perspectiva diferă (medicul decide, familia află), diferă doar persoana verbului, nu cuvintele. Tabelul e lista de verificat la QA2–QA4; coloana a treia e ce trebuie să rămână adevărat după reparații.

| Element | Aplicația (azi) | Web (azi) | Regula comună |
|---|---|---|---|
| Graful | `app/PolyGraph/Graph/graph.html`: layout radial (`pgRadialPositions`), muchii neutre `rgba(60,60,67,0.18)`, alimentele verzi (`round-tag`), simptomele mov, interacțiunile necunoscute punctate | `share/static/graph.js`: alt layout, culorile stricate (QA-01), alimentele portocalii, „de știut” albastru | **un singur renderer:** `graph.html` din aplicație devine sursa; `graph.js` din portal folosește același cod (layout, paletă, stiluri). Aplicația rămâne offline, cu copia din bundle, verificată de un test că e identică |
| Etichetele din graf | „k”, „calcium carbonate” (vin din backend) | la fel | reparate în backend (QA-04, QA-05): ambele platforme se schimbă odată |
| Severitatea | `Severity.label`: Critică / Gravă / Moderată / Minoră / De știut; titlul din backend: „interacțiune importantă” | aceleași etichete, același titlu | titlul folosește cuvântul etichetei („interacțiune gravă”); textele în `engine/texts_ro.py`, nicăieri altundeva |
| Decizia medicului | detaliul alertei: „Menține tratamentul” / „Îl modifică la consultație” / „Trimite la specialist”; în Noutăți vine din backend „Decizie: Modific la consultație” (persoana I, în aplicația familiei) | butoanele: „Menține” / „Modific la consultație” / „Trimit la specialist” | **butoanele medicului la persoana I; tot ce citește familia la persoana a III-a, cu exact cuvintele din aplicație.** Backend-ul primește tabelul pentru familie (`DECISION_LABEL_FAMILY`), folosit în Noutăți și pe tipărire |
| Recomandarea de pe alertă | scrisă pentru familie („Discutați cu medicul de familie…”): corect | același text, citit de medicul de familie: greșit | contractul nu se schimbă; portalul afișează o variantă pentru medic, făcută în `share/view.py` din aceleași câmpuri |
| Posologia în cuvinte | `Meds/MedSections.swift` | `plain_posology` în `view.py`; tipărirea arată „0-0-1” | aceleași perechi de test („1-0-1” → „1 dimineața, 1 seara”, „0-0-½” → „½ seara”, la nevoie) într-un fixture comun, verificat de pytest și de XCTest; tipărirea arată ambele forme |
| Stările goale | `ContentUnavailableView` cu titlu + explicație | lipsesc (QA-13) | aceleași texte pe ambele („Familia n-a adăugat încă medicamente”) |
| Culorile și accentul | culorile de sistem iOS, accent `#0E6B68` / `#5CC2BC` | identice | rămân identice; orice culoare nouă intră în ambele locuri |
| Țintele de atingere | 44 pt (HIG) | 17–24 px pe linkuri și pe „Adaugă o notă” | pe ecrane tactile (`pointer: coarse`), minimum 44 px și pe web |
| Decizia schimbată | aplicația arată ultima rezoluție | portalul nu permite schimbarea | după QA4 portalul permite; aplicația arată mereu ultima, iar Noutăți spune „Medicul de familie a schimbat decizia” |

#### Pașii

Ordinea ține cont de feature freeze-ul de la S4 (D 09:30): QA0–QA4 intră înainte, QA5 doar cât rămâne timp, restul la secțiunea 11. Fiecare etapă e un PR mic, cu testele ei; `make check` și `make demo-check` verzi la final. Cele cu „ambele” în coloana „Platforme” se încheie cu `make check-ios` pe Mac.

| Etapa | Ce rezolvă | Cine | Durată | Branch |
|---|---|---|---|---|
| QA0 | QA-06 | Dev B | 10 min | în `chore/restante-dupa-x1` (PR-ul curent) |
| QA1 | QA-02, 03, 07–11, 15: robustețea backend-ului | Dev B (+ Dev A pentru kind-ul nou) | 2 h | `fix/qa1-backend-robustness` |
| QA2 | QA-01, 04, 05, 12: graful comun | Dev B + Dev A | 2,5 h | `fix/qa2-shared-graph` |
| QA3 | textele comune și QA-13 | Dev B (+ Dev A pentru Noutăți) | 1,5 h | `fix/qa3-shared-copy` |
| QA4 | portalul: decizii, mesaje, accesibilitate, QA-14, 16 | Dev B | 2,5 h | `feature/qa4-portal-ux` |
| QA5 | funcționalitățile pentru demo (opțional) | Dev B | 2–4 h | `feature/qa5-…` |

##### QA0 · Pluralul din portal

**Responsabil:** Dev B · **Depinde de:** — · **Durată:** 10 min · **Branch:** `chore/restante-dupa-x1`

Nota de sub cifra „alerte revizuite” trece la singular / plural ca eticheta („trimisă familiei” / „trimise familiei”), cu un test în `test_share.py` pentru 0, 1 și 2.

**Teste**
- [x] T-QA0-01 `portal_summary` cu 1 alertă revizuită → „1 alertă revizuită · trimisă familiei”; cu 2 → „trimise”.

##### QA1 · Robustețea backend-ului

**Responsabil:** Dev B (+ Dev A: afișarea alertei `unverified`) · **Depinde de:** QA0 în `main` · **Durată:** 2 h · **Branch:** `fix/qa1-backend-robustness`

~~~text
[WORKFLOW] Branch: fix/qa1-backend-robustness. În acest task ai voie să schimbi contracts/schema/patient_create.schema.json (doar maxLength pe name și caregiver_name) și contracts/schema/alert.schema.json (doar kind "unverified"), după ce Dev A a fost de acord.

Obiectiv: niciun input al aplicației nu poate bloca serverul sau ascunde o problemă de medicație.

1. QA-02: solve() din schedule/solver.py primește un buget (noduri sau 200 ms, ce vine întâi). La buget atins întoarce cea mai bună soluție găsită; fără niciuna, o soluție greedy (fiecare doză la candidatul cu cost minim, în ordinea din `order`). Răspunsul spune asta în `solver` (ex. "version": "bb-1+budget"), fără câmpuri noi în contract. Logul `PROGRAM  buget atins (N doze)`.
2. QA-03: în engine/analyze.py, un medicament fără substanțe sau doar cu substanțe necunoscute în kb primește o alertă nouă, kind "unverified", severitate moderate, sursa PolyGraph: „Nu am putut verifica {brand}: substanța activă nu e cunoscută. Interacțiunile lui nu sunt incluse.” Kind-ul nou se adaugă în contracts/schema/alert.schema.json doar după acordul lui Dev A (enum-ul Swift generat de make models trebuie să-l cunoască, altfel decodarea alertelor pică), iar Dev A îl afișează în Alerts/AlertSections.swift lângă „moderate”.
3. QA-07: review_alert nu adaugă eveniment în Noutăți dacă decizia și nota sunt identice cu rezoluția salvată (răspunde 200 cu alerta, idempotent).
4. QA-08 și QA-09: add_med și update_med răspund 422 la end_date < start_date, la pattern cu toate valorile 0 fără as_needed și la o doză de peste 10 unități pe moment; /doses răspunde 422 la scheduled_at în viitor cu peste 24 h; /what-if răspunde 422 la query doar cu spații. Mesajele în română, ca restul erorilor.
5. QA-10: POST /meds cu un id care există deja: dacă corpul e identic cu medicamentul salvat → 200 cu el (cererea reluată nu dublează); altfel 409 „Există deja un medicament cu acest id”. Aplicația trimite azi id-uri noi la fiecare adăugare; verifică în app/PolyGraph/API că așa rămâne.
6. QA-11: maxLength 80 pe name și caregiver_name în patient_create.schema.json; make models; make check-contracts.
7. QA-15: POST /portal/login cu cod greșit → 303 la /portal?eroare=1&next=…, iar login.html arată mesajul din query.

Criterii de acceptare: un pacient cu 40 de medicamente primește /analysis și /schedule în < 1 s; niciun medicament nu dispare din fișă fără mesaj; make check și make demo-check verzi; programul Mariei rămâne identic cu expected_schedule.json (bugetul nu se atinge la 8 medicamente).
~~~

**Teste**
- [ ] T-QA1-01 40 de medicamente (copii ale celor demo): `/analysis` și `/schedule` < 1 s fiecare; programul Mariei = `expected_schedule.json`.
- [ ] T-QA1-02 Medicament cu `substances: []` → alerta `unverified` „Nu am putut verifica…”, validă după contract, vizibilă pe fișă și în aplicație.
- [ ] T-QA1-03 Aceeași decizie de 10 ori în paralel → un singur eveniment `doctor_reviewed`; o decizie diferită → al doilea eveniment.
- [ ] T-QA1-04 422 pentru `end_date < start_date`, 0-0-0-0 fără „la nevoie”, 100 de comprimate, doză în 2030, `what-if` cu spații.
- [ ] T-QA1-05 `POST /meds` repetat identic → 200 și un singur medicament; corp diferit cu același id → 409.
- [ ] T-QA1-06 Nume de 81 de caractere → 422; aplicația compilează după `make models`.
- [ ] T-QA1-07 Cod greșit → 303 la `/portal?eroare=1`, mesajul pe pagină, refresh fără retrimitere.

##### QA2 · Graful comun, pe aplicație și pe web

**Responsabil:** Dev B (backend, portal) + Dev A (aplicația) · **Depinde de:** QA1 · **Durată:** 2,5 h · **Branch:** `fix/qa2-shared-graph`

~~~text
[WORKFLOW] Branch: fix/qa2-shared-graph. Citește .claude/skills/apple-design/SKILL.md și docs/DESIGN.md. Nu edita project.pbxproj.

Obiectiv: graful arată la fel în aplicație și în portal: același layout, aceeași paletă, aceleași etichete, în română.

1. Sursa unică: rendererul din app/PolyGraph/Graph/graph.html (pgRadialPositions, paleta, stilurile Cytoscape, mesajele alert / med) se mută într-un fișier JS fără dependențe de WKWebView, backend/polygraph/share/static/graph-core.js, cu o funcție pgMount(container, graph, {dark, onAlert, onMed}). graph.js din portal și graph.html din aplicație îl folosesc amândouă; aplicația îl are în bundle ca app/PolyGraph/Graph/graph-core.js (copie identică), iar un test pytest compară cele două fișiere byte cu byte (ca la Resources/med_09_fromilid.json). GraphView.usesSharePage rămâne false: aplicația merge offline.
2. QA-01: paleta din graph-core.js e în hex / rgba(r,g,b,a), nu citită din variabilele CSS; în portal, dark mode vine din matchMedia, ca în aplicație.
3. QA-04: în graph/build.py, cheia alimentului vine din alertă (câmp intern adăugat de engine/food.py în make_alert, scos înainte de răspuns, sau din med_ids + kb.dfi), nu din rsplit("_") pe id; eticheta = kb.foods[cheie].label_ro, apoi food_ro, ca în food.py.
4. QA-05: eticheta substanței în graf și DCI-ul de pe fișă / tipărire în română (DCI-ul din nomenclator, ex. „carbonat de calciu”), cu INN-ul englezesc doar ca rezervă.
5. QA-12: #graph { position: relative } în share.css. Eroarea de CSP de la stilul injectat de Cytoscape rămâne (inofensivă); notează în docs/DESIGN.md, la „Convenții de implementare”, de ce.
6. Pe telefon (portalul la < 600 px), graful umple lățimea și are cel puțin 70% din înălțimea ecranului; fit cu padding 24 px.
7. Q3-12 (din review-ul Q3): ce e grav se vede primul, pe ambele platforme. Muchiile moderate au width 1.5 și opacitate 0.4, iar cele major / critical width 4. La primul render, fit pe nodurile alertei celei mai grave (padding 48 px); „Recentrează” arată tot graful. Etichetele claselor ATC apar doar peste zoom 1.5.

Criterii de acceptare: aceeași captură a grafului Mariei din aplicație (simulator) și din portal (Safari, aceeași lățime) arată aceleași poziții relative, culori și etichete; consola portalului fără erori în afară de CSP-ul Cytoscape; make check, make check-ios și make demo-check verzi.
~~~

**Teste**
- [ ] T-QA2-01 `graph-core.js` din `backend/` și din `app/` sunt identice (pytest).
- [ ] T-QA2-02 Graful Mariei: nodul alimentului se numește „alimente bogate în vitamina K…”, nicio etichetă de substanță în engleză.
- [ ] T-QA2-03 În portal: `cy.edges()` neutre au `line-color` cu transparență, nu `rgb(153,153,153)`; bordura medicamentelor nu e neagră în dark mode.
- [ ] T-QA2-04 Tap pe muchia Sintrom–Nurofen deschide aceeași alertă în aplicație și în portal.
- [ ] T-QA2-05 Manual: graful Mariei pe iPhone (aplicația) și în Safari pe același iPhone, light și dark, comparate una lângă alta.
- [ ] T-QA2-06 La deschidere, muchia roșie Sintrom–Nurofen e în centrul grafului, fără etichete de clasă peste nodurile medicamentelor, în aplicație și în portal (Q3-12).

##### QA3 · Textele comune

**Responsabil:** Dev B (+ Dev A pentru Noutăți și posologie) · **Depinde de:** QA1 · **Durată:** 1,5 h · **Branch:** `fix/qa3-shared-copy`

~~~text
[WORKFLOW] Branch: fix/qa3-shared-copy. Nicio schimbare de contract, cu excepția fixture-ului nou de la punctul 4.

Obiectiv: familia și medicul citesc aceleași cuvinte pentru același lucru, din aceeași sursă.

1. Severitatea: titlul alertelor ddi folosește cuvântul etichetei (critică / gravă / moderată / minoră), din engine/texts_ro.py; nicio altă formulare („importantă”) nicăieri.
2. Decizia: în backend, DECISION_LABEL (butoanele medicului, persoana I) și DECISION_LABEL_FAMILY = exact DoctorDecision.label din app/PolyGraph/Alerts/AlertSections.swift („Menține tratamentul”, „Îl modifică la consultație”, „Trimite la specialist”). Evenimentul doctor_reviewed din Noutăți și tipărirea folosesc varianta pentru familie. Un test pytest citește AlertSections.swift și verifică că cele trei texte coincid.
3. Recomandarea pentru medic: share/view.py produce, doar în portal, o variantă din câmpurile alertei: „Pacientul a fost sfătuit să discute cu dumneavoastră înainte de următoarea doză de {med}.” când route_to e medicul de familie, „…cu medicul {specialitate}…” altfel. Aplicația rămâne cu recommendation-ul din contract.
4. Posologia: contracts/fixtures/posology_words.json cu perechile pattern → text (inclusiv fracții, la nevoie, culcare); testat de pytest pe plain_posology și de un XCTest pe MedSections (Dev A). Tipărirea arată „1 dimineața, 1 seara (1-0-1)”.
5. QA-13: stările goale din portal (medicamente, programul zilei, check-in-uri, graf) cu aceleași texte ca ContentUnavailableView din aplicație; graful ascuns când nu are noduri.
6. Sursele fără căi interne: „Lista verificată PolyGraph (din DDInter 2.0)” în loc de „kb/curated_ddi.csv: DDInter 2.0: …”, pe fișă și pe tipărire; detaliul complet rămâne la „i”.
7. Pacient care nu e în lista medicului → pagina „Pacientul nu e în lista dumneavoastră” (404), nu „Linkul a expirat”.

Criterii de acceptare: în niciun ecran (aplicație sau portal) nu apare „interacțiune importantă”, „Modific la consultație” în Noutăți sau o cale de fișier; make check, make check-ios și make demo-check verzi.
~~~

**Teste**
- [ ] T-QA3-01 Etichetele deciziei din backend = cele din `AlertSections.swift` (pytest citește fișierul Swift).
- [ ] T-QA3-02 `posology_words.json` trece în pytest și în XCTest.
- [ ] T-QA3-03 Fișa Mariei în portal: nicio recomandare care începe cu „Discutați cu medicul de familie”.
- [ ] T-QA3-04 Pacient fără medicamente: fiecare secțiune are mesajul ei, graful e ascuns.
- [ ] T-QA3-05 HTML-ul fișei și al tipăririi nu conține `kb/`.

##### QA4 · Portalul: decizii, mesaje, accesibilitate

**Responsabil:** Dev B · **Depinde de:** QA3 · **Durată:** 2,5 h · **Branch:** `feature/qa4-portal-ux`

~~~text
[WORKFLOW] Branch: feature/qa4-portal-ux. Citește .claude/skills/apple-design/SKILL.md și docs/DESIGN.md (B6); componentele native (details, button) înaintea codului propriu.

Obiectiv: portalul nu sugerează decizia clinică, iar o greșeală se poate repara.

1. Butoanele de decizie: toate trei secundare (fără „Menține” plin). Sub 600 px, un control segmentat pe un rând (role="radiogroup", trei opțiuni) + butonul „Trimite” cu nota; peste 600 px, cele trei butoane pe un rând, ca acum.
2. „Schimbă decizia”: după salvare, starea inline („Modific la consultație · acum”) are un link „Schimbă”, care readuce formularul cu decizia curentă selectată; o decizie nouă trece prin aceeași rută (QA1 o face idempotentă) și creează evenimentul „Medicul de familie a schimbat decizia” (textul în texts_ro.py, persoana a III-a).
3. QA-14: Enter în notă nu trimite nimic și arată, lângă câmp, „Alegeți o decizie mai jos”; QA-16: mesaje separate pentru rețea („Nu s-a putut salva. Verificați conexiunea.”) și server („Nu s-a putut salva. Încercați din nou.”).
4. „Ieșire” și pe fișă și pe tipărire, în antet; linkul „← Pacienții mei” rămâne.
5. Pagina de prezentare: rolurile pe 3 coloane peste 900 px; adresa serverului = IP-ul din rețea când cererea vine de pe localhost / 127.0.0.1 (aceeași funcție ca local_ips() din demo/serve.py, mutată într-un modul comun), cu un buton „Copiază”.
6. Accesibilitate: h1 pe paginile de graf; pe pointer: coarse, ținte de cel puțin 44 px (linkurile de întoarcere, „Adaugă o notă”, butoanele „i”), ca în aplicație; în listă, avatarul are o culoare stabilă per pacient (hash pe id, din paleta de accente), cu inițiala.

Criterii de acceptare: pe un iPhone (Safari), o decizie se ia și se schimbă dintr-o mână, fără zoom; în aplicație, după polling, alerta arată ultima decizie și Noutăți are evenimentul de schimbare; make check și make demo-check verzi.
~~~

**Teste**
- [ ] T-QA4-01 Nicio decizie nu are stil primar; sub 600 px un singur rând de opțiuni.
- [ ] T-QA4-02 Decizie → „Schimbă” → altă decizie: alerta are ultima rezoluție, Noutăți are două evenimente, al doilea „a schimbat decizia”.
- [ ] T-QA4-03 Enter în notă: niciun request, mesajul apare; 500 simulat → mesajul pentru server.
- [ ] T-QA4-04 `/` cerut de pe `127.0.0.1` arată IP-ul din rețea, nu `localhost`.
- [ ] T-QA4-05 Playwright la 375 px, `hasTouch`: nicio țintă interactivă sub 44 px.
- [ ] T-QA4-06 Manual: decizia luată și schimbată pe iPhone, apoi văzută în aplicația aparținătorului.

##### QA5 · Funcționalitățile pentru demo (opțional, doar înainte de S4)

**Responsabil:** Dev B · **Depinde de:** QA2, QA4 · **Durată:** 2–4 h · **Branch:** `feature/qa5-<nume>`

În ordinea valorii pe scenă; fiecare e un PR separat, iar ce nu intră până la S4 trece la secțiunea 11.

1. **Portalul se actualizează singur** (M): lista și fișa ascultă `GET /portal/events` (Server-Sent Events, sau polling la 5 s ca rezervă), alimentat din `feed_events`. Când familia scanează Nurofen în aplicație, cardul Mariei urcă în „De revizuit” pe ecranul proiectat, fără refresh. În aplicație nu se schimbă nimic: polling-ul existent arată deja decizia medicului.
2. **„Dacă prescriu X?” în portal** (S–M): un câmp pe fișă care cheamă `/what-if` (X1) și arată alertele cu aceleași carduri; răspunsul e același pe care familia îl aude în aplicație la „Pot să iau…?”.
3. **„Ce s-a schimbat de la ultima consultație”** (M): în capul fișei, din `feed_events`, `doses` și `checkins`, de la ultima decizie a medicului: medicamente noi, alerte noi, doze ratate, simptome.

Restul ideilor din raport (simptome legate de medicamente, programul de lipit pe frigider, scrisoarea către specialist, aderența pe 30 de zile, lista medicului cu căutare și scoaterea unui pacient, STOPP v3, limitarea încercărilor de cod, eGFR, mai mulți medici) merg la secțiunea 11.

**Teste**
- [ ] T-QA5-01 Funcționalitatea 1: un medicament adăugat prin API apare în portal în < 5 s, fără reîncărcare.
- [ ] T-QA5-02 Funcționalitatea 2: „Fromilid” în câmp dă aceleași alerte ca `POST /what-if` și ca scenariul 2:10.
- [ ] T-QA5-03 Funcționalitatea 3: după o decizie, „Ce s-a schimbat” se golește; un medicament nou îl umple.

### Q3 · Turul agresiv pe aplicație (14.11.2026) și planul de reparații

**Ce este.** Pe 14.11.2026, după X1, un agent a rulat turul complet pe simulator (`make review Q=Q3`) și un tur agresiv nou (`EdgeCaseTour`: apăsări repetate, anulări la limită, ore la marginea zilei, rețea căzută în mijlocul fluxului, check-in-uri limită, valuri de Noutăți, text uriaș + dark), plus ~80 de cereri curl pe API. QA (mai sus) verifică web-ul și backend-ul; Q3 verifică aplicația, iar constatările care țin de backend sunt puse lângă etapele QA, ca să nu se repare de două ori. Raportul complet, cu capturi, pași de reproducere și prompturi: [`docs/reviews/Q3.md`](reviews/Q3.md) ([PR #32](https://github.com/VladimirTM/PolyGraph/pull/32)).

**Cum s-a testat:**
- **Simulator, turul de bază:** 17 teste × Light / Dark / AX / Motion / Contrast, 246 de capturi, 406 probleme de audit, 17 min.
- **Simulator, turul agresiv:** `make review Q=Q3e TOUR=EdgeCaseTour CONFIGS="Light AX" NO_VIDEO=1` (variabila `TOUR` e nouă în `run.sh`), 21 de teste, ~150 de capturi.
- **API:** curl pe un `make demo` separat, cu bază temporară: corpuri invalide, enum-uri, id-uri inexistente, idempotență, 5–10 cereri în paralel, path traversal, portal fără sesiune, HTML / `<script>` în notă, check-in și numele cutiei, validarea răspunsurilor după scheme.
- **Neacoperit:** iPhone fizic (VoiceOver, haptic, camera reală), „ștergere → Anulează → ștergere din nou” (fereastra de 5 s a expirat cât rula auditul; de reluat cu `AUDIT=0`), expirarea cutiilor cu `PG_NOW` (analiza folosește data serverului; verificată prin API).

**Ce merge** (nu mai trebuie re-testat înainte de demo): alertele Mariei = `expected_alerts.json` (27, 31 cu Fromilid, aceeași ordine, toate cu sursă); toate răspunsurile API validează după scheme; escaparea HTML în portal, tipărire și graf; `/media` închis la path traversal; `POST /doses` idempotent și la 10 cereri în paralel; „AM LUAT” de 2 și de 5 ori → o singură doză; „Salvează” de 3 ori → un singur medicament; avertizările de duplicat și de cutie expirată înainte de salvare; Noutăți cu 34 de evenimente: pastila „↑ noutăți”, lista nu se mișcă sub deget; aplicația își revine după backend fără repornire; X1 (cu `kb.sqlite` la zi) răspunde exact ca în 1.3, fără „puteți lua” și fără nimic despre tratamentele existente.

#### Constatările

Coloana „Platforme”: **app** = doar aplicația; **ambele** = backend-ul trimite același lucru aplicației și portalului; **app + web** = două implementări care trebuie să spună același lucru (vezi tabelul de consistență). „= QA-nn” înseamnă că problema e deja în tabelul QA și se repară acolo.

| ID | Severitate | Constatare | Platforme | Unde | Etapa |
|---|---|---|---|---|---|
| Q3-01 | **blocker** | `kb/kb.sqlite` de pe Mac e anterior lui X1 (fără Aspirin): „Pot să iau o aspirină?” → răspuns generic, nimic în Noutăți; `make demo-check` ROȘU; `make demo` nu avertizează | ambele | `demo/serve.py`, `make kb` | Q3F0 |
| Q3-02 | major | „Acum” în AX / XXXL: cardul „Am observat ceva…” + cele trei butoane fixe umplu ecranul, nu se vede ce pastilă se ia; în Light, numele e sub fold | app | `Senior/NowView.swift` | Q3F1 |
| Q3-03 | major | Dublă atingere pe „Am sărit”: a doua cade pe „Anulează” (apare sub deget), deci nu se notează nimic; serverul primește `skipped` + `pending` | app | `Senior/SeniorComponents.swift` (UndoBanner) | Q3F1 |
| Q3-04 | major | „Ați terminat pastilele de azi.” la 23:59 fără nicio confirmare și cu lista goală; „Ziua de azi” goală fără mesaj | app | `NowView.dayDone`, `SeniorDay`, `DayView` | Q3F1 |
| Q3-05 | major | Eroarea din „Acum” și „Ziua de azi” se repară doar prin tragere în jos (gest), contrar 2.4.2 | app | `NowView.loadError`, `DayView` | Q3F1 |
| Q3-06 | major | Modul senior nu reîncarcă programul la revenirea în aplicație și la miezul nopții: rămâne ziua de ieri | app | `Senior/SeniorRoot.swift`, `AppStore.refreshAll` | Q3F1 |
| Q3-07 | major | „Am luat” offline arată succes; eroarea nu apare nicăieri, iar coada `unsent` e doar în memorie (se pierde la repornire) | app | `Senior/DoseLog.swift` | Q3F1 |
| Q3-08 | major | „Am amețeli”, „Am greață”, „Amețesc” nu produc simptome; răspunsul e generic, iar portalul nu vede nimic | ambele | `contracts/symptoms.md`, `voice/understand.py` | Q3F2 |
| Q3-09 | major | Rețeta scrisă pe DCI („Paracetamol 500 mg”) nu dă candidat; din 3 rânduri rămân 2, cu o avertizare care nu spune care lipsește | ambele | `extract/ocr_match.py`, `match.py` | Q3F2 |
| Q3-10 | major | `GET /feed?since=` compară strict, la secundă: un eveniment din aceeași secundă cu ultimul primit nu ajunge niciodată la familie | ambele | `api/main.py` `feed` | Q3F3 |
| Q3-11 | major | `POST /meds` în paralel → 4 × 500 (`IntegrityError` pe `meds.id`); = QA-10 pentru cererea reluată, aici și concurența | ambele | `store.free_med_id`, `add_med` | Q3F3 (cu QA1) |
| Q3-12 | major | Graful: rețeaua portocalie domină, iar muchia roșie Sintrom–Nurofen din scena 0:45 abia se vede; etichetele claselor peste medicamente | app + web | `graph-core.js` (QA2) | QA2 (punctul 7) |
| Q3-13 | major | Noutăți arată doar ora („14:00”), deci dozele ratate din 12.11 par de azi; portalul are „14.11.2026, 13:25” | app + web | `Feed/FeedView.swift`, `PgFormat`, `share/view.py` | Q3F4 |
| Q3-14 | minor | Graful fără „Încearcă din nou”; căzut în timpul fluxului, pânză goală fără mesaj | app | `Graph/GraphView.swift` | Q3F4 |
| Q3-15 | minor | Medicamente / Noutăți offline: datele vechi rămân fără niciun semn | app | `MedsListView`, `FeedView` | Q3F4 |
| Q3-16 | minor | Contrast insuficient (Dark, Increase Contrast) pe butoanele accent din bare: „Arată medicului”, „Gata”, „Închide”, „Renunță”, „Editează” | app + web | `Assets.xcassets` (accent), `share.css` | Q3F4 |
| Q3-17 | minor | Cardul ACB e primul în Alerte, cu „3” și punct roșii, deși alerta e `moderate` | app | `Alerts/AlertSections.swift`, `AcbCard.swift` | Q3F4 |
| Q3-18 | minor | „…spuneți-i Ana sau medicului” (fără dativ); apare și în fișa din portal | ambele | `voice/correlate.py` `reply_text` | Q3F2 |
| Q3-19 | minor | „Pot să iau sindromul seara cu mâncare?” → simptomul `rash` (mâncare ≈ mâncărime), ajunge în portal; „sindromul” nu e recunoscut ca Sintrom | ambele | `voice/understand.py` | Q3F2 |
| Q3-20 | minor | Mod demo: „Adaugă rețeta ORL” apăsat rapid → mesajul final „Fromilid e deja în listă.” (deși a mers); „Simulează doza ratată” × 3 → 3 evenimente | app + backend | `SettingsView.run`, `/demo/missed-dose` | Q3F3 + Q3F4 |
| Q3-21 | minor | „…dacă vă simțiți slăbită” la orice pacient (gen fix) | ambele | `contracts/symptoms.md` (sfatul `black_stool`) | Q3F2 |
| Q3-22 | minor | Onboarding în AX: întrebarea acoperită, „Pentru cinev…” | app | `OnboardingView` | Q3F5 |
| Q3-23 | minor | Cutie ilizibilă: spinner-ul „Caut substanța activă…” rămâne lângă eroare; butoanele erorii palide | app | `ScanView` | Q3F4 |
| Q3-24 | minor | 32 de evenimente într-un lot → 32 de notificări locale | app | `FeedModel.receive`, `FeedAlerts` | Q3F4 |
| Q3-25 | minor | Singura ieșire din „Ziua de azi” e înapoi de 44 pt (sau swipe) | app | `DayView` | Q3F1 |
| Q3-26 | minor | Bara de navigare translucidă în modul senior (2.4.2: suprafețe opace) | app | `SeniorRoot` | Q3F1 |
| Q3-27 | minor | „Am adăugat Fromilid. 6 alerte noi.” / „Am salvat. 7 alerte noi” numără și alertele `minor` și `food`, pe care familia nu le vede | app | `AppStore.addMed`, `SettingsView` | Q3F4 |
| Q3-28 | minor | Concentrația „9999 mg” se salvează fără avertizare (= QA-09 pe server) | app | `ConfirmSheet` | Q3F5 |
| Q3-29…41 | polish | chevroane duble în detaliul medicamentului; „AM LUAT” cu majuscule; titlul foii de partajare diferit la Ana / Maria; titlul „Medicam…” strivit; analogia explicată de două ori; eticheta „k” (= QA-04); status suprapus și segment tăiat la confirmare; texte suprapuse în tranziția „Am luat”; ordinea dozelor la 07:30 față de fixture; graful gol = un cerc uriaș (= QA-13 pe web); comutarea rolului fără „Gata”; „Arată medicului” cu lista goală; „Anulează” la ștergere de 34 pt | app | vezi raportul | Q3F1 (AM LUAT), Q3F5 (restul) |
| A-3 | minor | Erorile de validare FastAPI au `detail` listă / obiect, nu `string` ca `Error` din openapi; aplicația afișează mesajul generic | ambele | `api/main.py` (handler `RequestValidationError`) | Q3F3 |
| A-5 | minor | Posologie necitită la scanare („1-0-1-1-1”, „9999-0-0”, „abc”) → 0-0-0-0 fără avertizare | ambele | `extract/posology.py` | Q3F2 |
| A-6 | minor | `/what-if {query}` alege alt produs decât check-in-ul („algocalmin” → fiola 1 g/2 ml, cu majuscule) | ambele | `api/main.py` `what_if` | Q3F2 |
| A-7 | minor | Aceeași întrebare X1 de două ori → două evenimente identice în Noutăți | ambele | `voice/can_i_take.py` / `create_checkin` | Q3F2 |
| A-4, A-8 | – | doză 9999 / nume de 600 de caractere acceptate | ambele | = QA-09, QA-11 | QA1 |
| Q3-I1…I5 | infra | `TOUR` în `run.sh` (gata); `tapFakeUsePage()` (gata); varianta Dark intermitentă (13 capturi din 7 fluxuri sunt Light); skill-ul lipsă (readus în #33) | – | `tools/review/`, `PolyGraphUITests/` | Q3F6 |

#### Consistența între aplicație și web (completare la tabelul QA)

Aceeași regulă ca la QA: **un lucru pe care îl văd și familia, și medicul are o singură sursă**. Rândurile de mai jos se adaugă la tabelul QA și se verifică la Q3F1–Q3F5 și la QA2–QA4.

| Element | Aplicația (azi) | Web (azi) | Regula comună |
|---|---|---|---|
| Data și ora evenimentelor | Noutăți: doar ora („14:00”); detaliul check-in-ului: „sâmbătă, 14 noiembrie, ora 13:25” | `ro_datetime`: „14.11.2026, 13:25”; check-in-uri: „14.11, 13:25” | **„Azi, 14:00” / „Ieri, 20:00” / „joi, 12 nov., 14:00”** pe ecran, în ambele (`PgFormat.relativeDay` și `share/view.py`, aceleași perechi de test într-un fixture comun, ca la posologie); data completă „14.11.2026, 13:25” rămâne doar pe tipărire |
| Numele codului pentru medic | Ana: butonul și foaia „Arată medicului”; Maria: „Cod pentru medicul de familie” și foaia „Codul pentru medic” | portalul îi spune medicului „Rugați familia să deschidă «Arată medicului»” | **„Arată medicului”** peste tot: butonul la Ana și la Maria, titlul foii, textele din portal și de pe pagina de prezentare |
| Stările de eroare | aparținător: mesaj + „Încearcă din nou”; senior: „Trageți ecranul în jos” (Q3-05); graful fără buton (Q3-14) | decizia: mesaj inline (QA-16) | **orice eroare are mesajul în română și „Încearcă din nou”**, inclusiv în modul senior (buton de 72 pt) și în graf; mesajele de rețea / server separate, cu textele din QA-16 în ambele |
| Datele vechi după o reîmprospătare eșuată | nimic (Q3-15) | pagina se reîncarcă întreagă | bandă discretă „Nu am putut actualiza. Încearcă din nou” în aplicație; pe web, dacă QA5.1 (actualizare automată) intră, același text |
| Numărul de alerte noi | „6 alerte noi” (toate, inclusiv `minor`) | cifrele din rezumat numără gravele | **numărul spune doar ce se vede**: „2 alerte grave noi”, iar moderatele „și 2 de discutat”; aceeași funcție de numărare pe server și în aplicație (`critical` + `major`, fără `food`) |
| Ordinea și culoarea alertelor | ACB primul, roșu (Q3-17) | gravele sus, ACB în rezumat | ordinea din 5.3 pe ambele: grave → moderate grupate → Mâncare și băutură → ACB; culoarea după `severity` (ACB `moderate` = portocaliu) |
| Graful: ce e grav se vede primul | muchiile moderate la fel de groase ca gravele | la fel (+ QA-01) | în `graph-core.js` comun (QA2): moderate subțiri și transparente, grave groase, zoom inițial pe perechea cea mai gravă |
| Accentul la contrast mare | teal `#0E6B68` / `#5CC2BC`, fără variantă „High Contrast” | aceleași culori, fără `prefers-contrast` | o variantă de contrast mare în Asset Catalog și `@media (prefers-contrast: more)` în `share.css`, cu aceleași valori |
| Textele de check-in (răspunsul și ce vede medicul) | citite cu voce și afișate | fișa le arată la check-in-uri | se repară doar în backend (Q3F2): gramatica, genul neutru, fără „Mulțumesc.” la întrebări; ambele platforme se schimbă odată |
| Stările goale | senior: „Ați terminat pastilele de azi” fals (Q3-04); graful gol = un nod uriaș | QA-13: lipsesc | aceleași texte în aplicație (aparținător și senior) și pe web: „Familia n-a adăugat încă medicamente.” (aparținător, portal), „Nu aveți pastile în program.” (pacient) |
| Țintele de atingere | senior 72 pt (în afară de înapoi, Q3-25); aparținător 50 pt (în afară de „Anulează” 34 pt) | QA4: 44 px pe `pointer: coarse` | senior ≥ 72 pt, aparținător ≥ 44 pt (HIG), web tactil ≥ 44 px |
| Suprafețele | senior: bara translucidă (Q3-26) | opace | modul senior și portalul: opace; materialele translucide doar în chrome-ul aparținătorului |

#### Pașii

Ordinea ține cont de S4 (D 09:30): Q3F0 acum; Q3F1–Q3F4 înainte de S4, în paralel cu QA1–QA4 (Q3F1 și Q3F4 sunt ale lui Dev A, Q3F2 și Q3F3 ale lui Dev B); Q3F5 doar cât rămâne timp; Q3F6 înainte de Q4. Fiecare etapă e un PR mic, cu testele ei; `make check`, `make demo-check` și, pentru cele cu app, `make check-ios` verzi la final. Prompturile detaliate, pe constatare, sunt în `docs/reviews/Q3.md`; mai jos e ce intră în fiecare PR.

| Etapa | Ce rezolvă | Cine | Durată | Branch |
|---|---|---|---|---|
| Q3F0 | Q3-01 | Dev B | 15 min | `fix/q3f0-kb-freshness` |
| Q3F1 | Q3-02…07, 25, 26, 30: modul senior | Dev A | 2,5 h | `fix/q3f1-senior` |
| Q3F2 | Q3-08, 09, 18, 19, 21, A-5…7: vocea și scanarea pe backend | Dev B | 1,5 h | `fix/q3f2-voice-scan` |
| Q3F3 | Q3-10, 11, 20 (backend), A-3: robustețea API | Dev B | 45 min | în `fix/qa1-backend-robustness`, dacă QA1 nu e închis; altfel `fix/q3f3-api` |
| Q3F4 | Q3-13…17, 20 (app), 23, 24, 27: aparținătorul și consistența cu web-ul | Dev A (+ Dev B pentru datele din portal) | 2 h | `fix/q3f4-caregiver-consistency` |
| Q3F5 | Q3-22, 28, polish-ul rămas | Dev A | 1 h | `chore/q3f5-polish` |
| Q3F6 | regresia: `EdgeCaseTour` în Q4, Dark stabil, testul de ștergere reluat | Dev A (agent) | 30 min | `test/q3f6-review-tour` |

Q3-12 (graful) nu are etapă proprie: intră în QA2, ca punctul 7 al promptului, pentru că `graph-core.js` e comun.

##### Q3F0 · `kb.sqlite` la zi pe Mac-ul de demo

**Responsabil:** Dev B · **Depinde de:** — · **Durată:** 15 min · **Branch:** `fix/q3f0-kb-freshness`

`make kb` pe Mac-ul de demo (acum, înainte de orice repetiție). Apoi, în `backend/polygraph/demo/serve.py`, la verificările de pornire: `kb_meta.built_at` comparat cu mtime-ul maxim al `kb/ro_products_extra.csv`, `kb/curated_ddi.csv`, `kb/curated_dfi.csv`, `kb/overrides.csv` și `kb/rules/*.yaml`; dacă unul e mai nou, `✗ kb.sqlite e mai vechi decât <fișier>: rulați make kb`.

**Teste**
- [x] T-Q3F0-01 Un CSV atins după build → `make demo` afișează ✗; după `make kb`, ✓. *(14.11.2026: `backend/tests/test_kb_freshness.py`, 5 teste; pe Mac, înainte de build: „✗ kb.sqlite e mai vechi decât ro_products_extra.csv”, după `make kb`: „✓ kb.sqlite la zi”)*
- [x] T-Q3F0-02 `make demo-check` verde pe Mac-ul de demo, inclusiv pasul X1 (aspirina în Noutăți). *(14.11.2026: în proces, pe `kb.sqlite` reconstruit, 12 pași în 1,1 s; de repetat cu `URL=` pe serverul din `make demo` înainte de D1)*

##### Q3F1 · Modul senior: ce vede Maria e adevărat și se poate repara cu un buton

**Responsabil:** Dev A · **Depinde de:** — · **Durată:** 2,5 h · **Branch:** `fix/q3f1-senior`

~~~text
[WORKFLOW] Branch: fix/q3f1-senior. Citește .claude/skills/apple-design/SKILL.md și docs/DESIGN.md (2.4.2). Nu edita project.pbxproj; fără dependențe externe; xcodebuild build după fiecare modificare.

Obiectiv: pe „Acum” se vede mereu ce pastilă se ia, nicio atingere dublă nu anulează ce a făcut prima, nimic nu spune „ați terminat” când nu e adevărat, iar orice eroare se repară cu un buton mare.

1. Q3-02: în NowView, `notices` după cardurile de doză (sau PatientNoticeCard compact: un rând + buton secundar). Când dynamicTypeSize.isAccessibilitySize, bara fixă de jos ține doar „Am luat”; „Mai târziu” și „Am sărit” intră în ScrollView, după carduri.
2. Q3-03: „Anulează” din UndoBanner ignoră atingerile în primele 800 ms după apariție (sau un GuardedAction comun pentru toată bara de jos).
3. Q3-04: `dayDone` doar dacă toate momentele zilei sunt luate sau sărite; altfel „Pentru azi nu mai e nimic de luat acum.” + „Mâine, primele sunt la ora 07:00.” (fără îndemn la doza ratată, fără roșu); `schedule.moments.isEmpty` → „Nu aveți pastile în program.” în Acum și în Ziua de azi (`day.empty`); vocea spune același lucru.
4. Q3-05: SeniorButton „Încearcă din nou” (`now.retryButton`, `day.retryButton`) sub eroare; textul fără „trageți”; în Ziua de azi, „Arată medicului” ascuns cât e eroare.
5. Q3-06: în SeniorRoot, `.task(id: scenePhase)` → `refreshAll()` la `.active`, plus `.NSCalendarDayChanged` → `refreshAll()`; cu PG_NOW (FixedClock) nu se schimbă nimic.
6. Q3-07: DoseLog persistă coada `unsent` în UserDefaults („pg.doseLog.unsent”) și o retrimite la `.active` și la 30 s cât nu e goală; sub cronologie, cât `lastError != nil`: „Confirmarea pleacă când revine internetul.” (calm, `now.pendingSync`).
7. Q3-25, 26, 30: la finalul Zilei de azi, SeniorButton „Înapoi la Acum”; bara de navigare opacă în modul senior (`.toolbarBackground(PgColor.background, for: .navigationBar)` + visible); „Am luat” în loc de „AM LUAT”.
8. Butonul de cod din Ziua de azi se numește „Arată medicului” (regula comună din tabelul de consistență).
Actualizează identificatorii noi în docs/DESIGN.md („Convenții de implementare”).

Criterii de acceptare: EdgeCaseTour.testRapidLaterAndSkipped, testClockEdges (lateNight), testDeleteUndoAndDeleteAll (emptyNow, emptyDay), testBackendDownSeniorScreens, testBackendDropsMidFlowSenior și testSeniorHugeTextDark arată comportamentul nou; make check-ios verde; încercat pe iPhone la textul maxim.
~~~

**Teste**
- [x] T-Q3F1-01 AX și XXXL, PG_NOW=…T07:05: ora și numele primei pastile vizibile fără scroll (`onScreen(now.dose.med_05)`).
- [x] T-Q3F1-02 3 atingeri pe „Am sărit” → momentul e „sărit”, `now.undoBanner` vizibil, un singur `POST /doses` cu `skipped`.
- [x] T-Q3F1-03 23:59 fără confirmări → textul neutru; listă goală → „Nu aveți pastile în program.” în Acum și Ziua de azi.
- [x] T-Q3F1-04 Backend oprit → `now.retryButton` și `day.retryButton` (≥ 72 pt) reîncarcă după ce backend-ul revine.
- [x] T-Q3F1-05 Unit test DoseLog: trimitere eșuată → DoseLog nou pe aceleași `UserDefaults` → retrimite aceeași doză.
- [x] T-Q3F1-06 Unit test AppStore: ceasul trece de miezul nopții → `schedule.date` nou.

> Verificat pe 14.11.2026 (`fix/q3f1-senior`): 05 și 06 în `SeniorTests.swift` (`DoseQueueTests`, `MidnightRefreshTests`, verzi cu `-only-testing:PolyGraphTests`); 01–04 în `ReviewTour.seniorNow` (AX) și `EdgeCaseTour` (`make review Q=Q3F1-edge` / `Q3F1-ax`, fără absențe); pe iPhone: textul maxim, „Am sărit” rapid, confirmarea cu serverul oprit, reîncărcarea la revenire (Fromilid adăugat din fundal), „Arată medicului” și „Înapoi la Acum”. Tot aici: bara de jos goală nu mai lasă o bandă peste carduri.

##### Q3F2 · Vocea și scanarea pe backend

**Responsabil:** Dev B · **Depinde de:** — · **Durată:** 1,5 h · **Branch:** `fix/q3f2-voice-scan`

~~~text
[WORKFLOW] Branch: fix/q3f2-voice-scan. În acest task ai voie să schimbi contracts/symptoms.md (doar sinonime și textul sfatului), nimic altceva din contracts/.

Obiectiv: ce spune Maria în cuvinte obișnuite e înțeles, rețetele scrise pe DCI sunt citite, iar răspunsurile sunt corecte gramatical; aplicația și fișa din portal se schimbă odată.

1. Q3-08: în symptoms.md, la dizziness „amețeli; amețesc; am amețeală”, la nausea „greață; am greață; greţuri”; potrivire pe cuvinte întregi.
2. Q3-19: sinonimele nu se potrivesc pe prefix („mâncare” nu e „mâncărime”); `phonetic` și pe forma articulată („sindromul” → Sintrom).
3. Q3-18, Q3-21: `reply_text` folosește `dative(caregiver)` și în „spuneți-i …”; sfatul pentru black_stool fără gen („dacă vă simțiți fără putere”); la intent can_i_take, fără „Mulțumesc.” în față.
4. Q3-09: un rând de rețetă fără brand potrivit → căutare pe DCI + concentrație, cu produsul oral cu o singură substanță (rank-ul din can_i_take.pick_product), `match.method = "exact_dci"`, `needs_review = true`; rândurile nepotrivite → avertizare cu textul rândului („Nu am găsit «Paracetamol 500 mg». Adăugați-l manual.”).
5. A-5: posologia necitită → avertizare „Nu am înțeles posologia «…»”, câmpul rămâne gol (aplicația îl marchează deja „verificați”).
6. A-6: `/what-if {query}` folosește `can_i_take.pick_product`, ca check-in-ul.
7. A-7: aceeași întrebare X1 (același brand, aceeași zi, același răspuns) nu adaugă al doilea eveniment în Noutăți.

Criterii de acceptare: fraza „Am amețeli, greață, mă dor mușchii și am vânătăi pe mâini și scaun negru.” → dizziness, nausea, muscle_pain, bruising, black_stool; rețeta [Aspirin 500 mg, Paracetamol 500 mg, Algocalmin 500 mg] → 3 candidați; fixture-ul Fromilid și checkin_demo.json neschimbate; make check și make demo-check verzi.
~~~

**Teste**
- [x] T-Q3F2-01 „Am amețeli.”, „Am greață.”, „Amețesc.” → simptomul corect; „…cu mâncare” → fără `rash`. *(14.11.2026: `backend/tests/test_q3f2.py`; sinonime noi în `symptoms.md`, potrivire pe cuvinte întregi în `understand.py`, negația și înaintea lui „am”; fraza din criterii → cele 5 simptome; „sindromul” → Sintrom de pe listă)*
- [x] T-Q3F2-02 Rețeta cu 3 rânduri → 3 candidați; „Paracetamol 500 mg” singur → un candidat oral cu `needs_review`. *(14.11.2026: `ocr_match.dci_match`, `exact_dci`, încredere 0,8, substanța din produsul oral cu o singură substanță, numele și concentrația de pe rețetă; rândul nepotrivit e numit în avertizare; A-5: posologia necitită sau peste 10 unități → câmp gol + „Nu am înțeles posologia «…»”)*
- [x] T-Q3F2-03 `reply_text` fără „spuneți-i Ana”, fără „slăbită”; la „Pot să iau…?” nu începe cu „Mulțumesc.”. *(14.11.2026: `correlate.unwell_hint` folosit și în istoricul demo; „Mulțumesc.” doar când pacientul spune cum se simte, nu la `can_i_take` / `which_pill_now`)*
- [x] T-Q3F2-04 `/what-if {"query":"algocalmin"}` și check-in-ul „Pot să iau Algocalmin?” aleg același produs. *(14.11.2026: `/what-if` cu `query` folosește `can_i_take.pick_product`; „Algocalmin” oral, nu fiola)*
- [x] T-Q3F2-05 Aceeași întrebare de două ori → un singur eveniment în Noutăți. *(14.11.2026: `_asked_today` în `api/main.py`: același titlu și același răspuns în aceeași zi nu se mai adaugă; `make check` are 328 de teste, `make demo-check` verde, 12 pași)*

##### Q3F3 · Robustețea API (lângă QA1)

**Responsabil:** Dev B · **Depinde de:** — (dacă QA1 e în lucru, în același PR) · **Durată:** 45 min · **Branch:** `fix/qa1-backend-robustness` sau `fix/q3f3-api`

1. **Q3-10:** `feed()` filtrează cu `>=`; aplicația deduplică deja pe `id`. În `openapi.yaml`, `since` e descris ca inclusiv.
2. **Q3-11:** `free_med_id` + inserarea într-o tranzacție (`BEGIN IMMEDIATE`) sau reîncercare la `IntegrityError`; împreună cu QA-10 (cererea identică reluată → 200).
3. **Q3-20 (backend):** `/demo/missed-dose` nu adaugă al doilea eveniment pentru același moment.
4. **A-3:** handler pentru `RequestValidationError` și pentru `invalid()` → `{"detail": "<mesaj în română>"}`, ca în `Error` din `openapi.yaml`; lista de erori rămâne în log.

**Teste**
- [ ] T-Q3F3-01 Două evenimente cu același `at`, `since = at` → ambele.
- [ ] T-Q3F3-02 5 `POST /meds` în paralel cu Fromilid → zero 5xx, un singur medicament.
- [ ] T-Q3F3-03 `/demo/missed-dose` × 3 → un singur eveniment.
- [ ] T-Q3F3-04 JSON invalid, câmp lipsă, enum greșit → 422 cu `detail` string, valid după `Error`.

##### Q3F4 · Aparținătorul și consistența cu web-ul

**Responsabil:** Dev A (+ Dev B pentru formatul datelor în `share/view.py`) · **Depinde de:** QA3 pentru texte (stările goale), Q3F3 pentru numărare · **Durată:** 2 h · **Branch:** `fix/q3f4-caregiver-consistency`

~~~text
[WORKFLOW] Branch: fix/q3f4-caregiver-consistency. Citește .claude/skills/apple-design/SKILL.md, docs/DESIGN.md și tabelul „Consistența între aplicație și web” din docs/PLAN.md (QA și completarea Q3). Nu edita project.pbxproj.

Obiectiv: aparținătorul vede date, numere, nume și culori identice cu cele din portal.

1. Q3-13: PgFormat.relativeDay („Azi, 14:00” / „Ieri, 20:00” / „joi, 12 nov., 14:00”) în cardurile din Noutăți și în detaliul check-in-ului; aceeași funcție în share/view.py pentru fișă și listă (tipărirea păstrează „14.11.2026, 13:25”); perechile de test în contracts/fixtures/date_words.json, verificate de pytest și de XCTest (ca posology_words.json din QA3).
2. Q3-14, Q3-15: GraphView cu eroare + „Încearcă din nou” (`graph.retryButton`) și când WebView-ul are deja un graf; în Medicamente și Noutăți, bandă discretă „Nu am putut actualiza. Încearcă din nou” când `lastError != nil` și lista nu e goală.
3. Q3-16: varianta High Contrast a culorii accent în Asset Catalog; aceleași valori în share.css sub `@media (prefers-contrast: more)` (Dev B).
4. Q3-17: în AlertSections, ordinea grave → moderate grupate → Mâncare și băutură → ACB; cifra și punctul ACB cu Severity.moderate.color.
5. Q3-27: „Am salvat. 2 alerte grave noi” / „Am adăugat Fromilid. 2 alerte grave noi și 2 de discutat.”: numără doar critical + major (fără food) și moderate, ca rezumatul din portal.
6. Q3-20 (app): butoanele demo se dezactivează sincron (demoAction setat înainte de Task); a doua apăsare nu suprascrie statusul de succes.
7. Q3-23: la eroarea de scanare, statusul de sus dispare; butoanele erorii .borderedProminent.
8. Q3-24: peste 3 evenimente noi într-un lot, o singură notificare („Maria: 5 noutăți, 2 grave”).
9. „Arată medicului”: același titlu pentru foaia de partajare la Ana și la Maria (regula comună); textele din portal rămân.

Criterii de acceptare: aceeași doză ratată arată „joi, 12 nov., 14:00” în aplicație și în portal; numărul de alerte noi din aplicație = cel din rezumatul portalului după Fromilid; ReviewTour (Dark, Contrast) fără „Contrast failed” pe butoanele accent; make check, make check-ios și make demo-check verzi.
~~~

**Teste**
- [x] T-Q3F4-01 `date_words.json` trece în pytest (`share/view.py`) și în XCTest (`PgFormat`).
- [x] T-Q3F4-02 Backend oprit → `graph.retryButton`; revenit → graful se încarcă fără repornire.
- [ ] T-Q3F4-03 Auditul de contrast în Dark și Contrast fără erori pe `meds.shareButton`, `settings.doneButton`, `scan.closeButton`, `share.doneButton`.
- [x] T-Q3F4-04 Alerte: primul card e o alertă gravă; ACB portocaliu.
- [x] T-Q3F4-05 „Adaugă rețeta ORL” × 4 → statusul de succes rămâne; un singur Fromilid.
- [ ] T-Q3F4-06 Manual: aceeași doză ratată și același check-in, unul lângă altul în aplicație și în portal (dată, ora, severitatea, cuvintele).

> Implementat pe 14.11.2026 (`fix/q3f4-caregiver-consistency`), toate cele 9 puncte din prompt. Verificat: `make check` (341 de teste; `backend/tests/test_q3f4.py` cu perechile din `date_words.json`, fișa cu „Actualizată azi, …”, tipărirea cu data completă). Scrise, dar nerulate încă pe Mac: `CaregiverConsistencyTests` (01, 04, Fromilid = „2 alerte grave noi și 2 de discutat”, lotul de notificări) și starea de eroare a grafului (02, 05 prin logica butoanelor); de confirmat cu `make check-ios` și `make review`. 03 rămâne deschis: variantele de contrast mare ale accentului existau deja în Asset Catalog și în `share.css` (aceleași valori); s-a reparat eticheta albă pe accent în Dark (`.pgProminent`, „Gata” pe iOS 26), dar textul teal pe sticla barei (`meds.shareButton`, `scan.closeButton`) trebuie re-auditat. 06 e manual. Portalul nu afișează dozele ratate (doar check-in-urile și deciziile), deci comparația cu „joi, 12 nov., 14:00” se face pe check-in.

##### Q3F5 · Polish (doar cât rămâne timp înainte de S4)

**Responsabil:** Dev A · **Depinde de:** Q3F1, Q3F4 · **Durată:** 1 h · **Branch:** `chore/q3f5-polish`

În ordinea vizibilității în demo: Q3-29 (chevroane duble), Q3-32 (titlul strivit: „Arată medicului” ca pictogramă `qrcode` cu etichetă VoiceOver), Q3-33 (analogia o singură dată, ca pe web: detaliul complet după „i”), Q3-35 (statusul și segmentul la confirmare), Q3-40 („Arată medicului” ascuns cu lista goală), Q3-41 („Anulează” de 50 pt), Q3-22 (onboarding în AX), Q3-28 (avertizare la concentrații neobișnuite), Q3-36 (tranziția „Am luat”), Q3-37 (ordinea dozelor), Q3-38 (graful gol: textul comun din QA3), Q3-39 (comutarea rolului la „Gata”). Ce nu intră trece la secțiunea 11.

**Teste**
- [ ] T-Q3F5-01 `make review Q=Q3f5 ONLY="testCaregiverMeds testScanBoxFake testGraph testOnboarding" CONFIGS="Light AX" NO_VIDEO=1`: capturile arată schimbările.

##### Q3F6 · Regresia pentru Q4

**Responsabil:** Dev A (agent) · **Depinde de:** Q3F1–Q3F4 · **Durată:** 30 min · **Branch:** `test/q3f6-review-tour`

1. Varianta Dark stabilă: în `run.sh`, Dark rulează separat, după `xcrun simctl ui <udid> appearance dark` (ca la Contrast), nu doar cu `XCUIDevice.appearance` în `setUp`.
2. `testDeleteUndoAndDeleteAll`: auditul după „Anulează”, nu înainte, ca fereastra de 5 s să nu expire.
3. La Q4: turul de bază + `make review Q=Q4e TOUR=EdgeCaseTour CONFIGS="Light AX" NO_VIDEO=1`; fiecare constatare din Q3 primește starea închisă / deschisă / regresie în `docs/reviews/Q4.md`.

**Teste**
- [ ] T-Q3F6-01 `make review Q=dbg CONFIGS=Dark ONLY="testSeniorNowMorning testCaregiverAlertsAndDetail testGraph"`: toate capturile sunt dark.
- [ ] T-Q3F6-02 `testDeleteUndoAndDeleteAll`: „Anulează” readuce Sintrom (`meds.row.med_01` după undo).

---

### D1 · Integrare, repetiții, video de rezervă (împreună)

**Durată:** W24.5–W27.5

- [ ] `make demo-check` verde pe `main`
- [ ] Q4: raportul `docs/reviews/Q4.md` fără blocker deschis; regresia constatărilor din Q1–Q3 verde
- [ ] Q4 rulează și `EdgeCaseTour` (Q3F6); `make demo-check` verde pe Mac-ul de demo cu `kb.sqlite` reconstruit (Q3F0)
- [ ] Scenariul din secțiunea 7 rulat cronometrat de 3 ori, cu resetare între rulări; fiecare problemă → fix doar dacă e < 20 min, altfel se scoate din scenariu
- [ ] Înregistrare ecran (ambele telefoane + portalul medicului) a unei rulări curate: **video de rezervă** dacă ceva pică pe scenă
- [ ] Telefoanele: luminozitate maximă, Nu deranja (cu excepția notificărilor app-ului), baterie > 80%, aplicația instalată din Xcode în configurația Release
- [ ] Cutiile demo fizice și rețeta tipărită într-o pungă, în ordinea scenariului

### D2 · Pitch și submit (împreună)

**Durată:** W27.5–W30

- [ ] Slide-urile (secțiunea 8), maximum 8
- [ ] README cu capturi, arhitectura, sursele de date și licențele, cum se rulează
- [ ] Submit pe platforma hackathonului cu link-ul repo-ului și video-ul
- [ ] O repetiție completă a pitch-ului + demo, cronometrată

---

## 7. Scenariul demo (3 minute, două telefoane + laptop)

Telefonul 1 = Maria (modul senior). Telefonul 2 = Ana (aparținător). Laptopul = cabinetul medicului de familie (portalul), proiectat pe ecran.

| Timp | Ce se întâmplă | Ce spunem |
|---|---|---|
| 0:00 | Punga cu 8 cutii reale pe masă | „Maria are 78 de ani, 5 medici și 8 cutii. Niciun medic nu vede punga întreagă.” |
| 0:15 | Ana scanează 2 cutii live (DataMatrix + poză) → confirmare → salvat (restul sunt deja în app după reset) | „Codul de pe cutie dă data expirării; poza dă substanța activă, potrivită în nomenclatorul românesc, nu ghicită.” |
| 0:45 | Ecranul de alerte + **graful**: muchia roșie Sintrom – Nurofen; Beers pe amitriptilină; ACB 3 | „Fiecare alertă vine dintr-o bază de date cu sursa afișată. LLM-ul doar citește poza.” |
| 1:15 | Telefonul Mariei: „Acum”, cu poza Euthyrox-ului, TTS citește instrucțiunea, „Am luat” | „Programul îl calculează un solver: Euthyrox singur dimineața, calciul la 4 ore distanță, 5 momente pe zi în loc de 8.” |
| 1:40 | Maria apasă microfonul: „Dimineața, când mă ridic din pat, mi se învârte capul și am observat niște vânătăi pe mână” | – |
| 1:55 | Pe telefonul Anei: notificare „Maria a raportat: amețeală, vânătăi; posibil legat de Sintrom + Nurofen” | „Vânătăile au fost legate de interacțiunea deja găsită; Ana află în câteva secunde, din alt oraș.” |
| 2:10 | **Medic nou:** Ana scanează rețeta ORL (Fromilid, claritromicină) → alertă **critică** simvastatină + claritromicină și una gravă Sintrom + claritromicină, pe ambele telefoane | „Al șaselea medic a prescris un antibiotic. PolyGraph a prins două conflicte înainte de prima pastilă.” |
| 2:30 | laptopul (cabinetul): portalul medicului de familie, Maria sus în listă; medicul alege „Modific la consultație” + notă la Sintrom + Nurofen → apare la Ana | „Familia și medicul de familie văd aceeași fișă; medicul vede și ce nu i-a prescris nimeni (Nurofen-ul). Asta e comunitatea conectată din The Bloom.” |
| 2:50 | „Reconcilierea medicației” (versiunea de tipărit) | „Și asta o duce Maria la medicul de familie.” |

Plan B pentru fiecare pas: scanarea pică → butonul „Adaugă rețeta ORL” din modul demo; recunoașterea vocală pică → check-in prin text; rețeaua pică → hotspot-ul laptopului + cache; totul pică → video-ul de rezervă.

---

## 8. Pitch (7 slide-uri + demo)

1. **Problema, cu cifre:** în Europa, ~1 din 10 internări ale vârstnicilor e legată de reacții adverse la medicamente (studiul ADAPT, Irlanda: 10,0%; o meta-analiză pe pacienți vârstnici: 8,7%); Comisia Europeană a estimat ~5% din toate internările și ~197.000 de decese pe an în UE din reacții adverse. Polimedicația crește riscul de internare de ~3 ori într-un studiu finlandez (OR 3,3).
2. **De ce acum / de ce noi:** nimeni nu vede lista completă; medicii nu comunică; vârstnicul e singurul „integrator”. API-ul public de interacțiuni al NLM a fost oprit în 2024, deci soluțiile simple nu mai merg.
3. **Soluția:** poză → graf → alerte deterministe → program simplu → voce → familia și medicul de familie în buclă.
4. **Demo** (secțiunea 7).
5. **Cum e construit:** diagrama din 2.1 cu regula „LLM doar la margini”; DDInter 2.0 + nomenclatorul RO + Beers / STOPP / ACB; solverul; designul pentru vârstnici (un singur ecran, butoane mari, fără gesturi, Reduce Motion / Dynamic Type respectate).
6. **Impact și model:** familia (abonament mic), medicii de familie (portalul și fișa de reconciliere: timp câștigat la consultație, OTC-urile pe care altfel nu le vede). Pași următori: date licențiate comercial, pilot cu un cabinet de medicină de familie din Timișoara, integrare cu rețeta electronică.
7. **Responsabil:** nu diagnosticăm, nu schimbăm doze; GDPR (date de sănătate, partajare cu token care expiră); drumul spre conformitate MDR (după Regula 11 din MDR, un software care dă informații pentru decizii terapeutice e, probabil, cel puțin clasa IIa; de confirmat cu un specialist în reglementare).

Întrebări probabile de la juriu (de pregătit răspunsul în 2 fraze): „De unde știți că alertele sunt corecte?” · „Ce faceți cu alert fatigue?” (severități, minor ascuns, routing pe roluri) · „Licența datelor?” · „De ce ar deschide un medic de familie încă un portal?” (lista îi arată doar pacienții cu ceva de revizuit, iar fișa îi arată ce nu vede în sistemul lui: OTC-urile și rețetele altor specialiști) · „Cum convingeți un vârstnic să folosească telefonul?” (familia face setup-ul; seniorul are un singur ecran și vocea).

---

## 9. Riscuri și decizii deschise

| Risc / decizie | Când se închide | Cine |
|---|---|---|
| Regulamentul UniHack: cod scris înainte | închis: nu întrebăm organizatorii și nu scriem cod înainte de start (doar date, conturi, poze, research); se citește regulamentul / FAQ-ul | amândoi |
| Exportul catalogului românesc (CANAMED / ANMDMR) nu e disponibil ca fișier | pregătire; fallback: lista manuală de ~150 de produse uzuale + pacientul demo | B |
| Formatul exact al CSV-urilor DDInter 2.0 diferă de așteptări | pregătire (descărcat și deschis înainte); B1 | B |
| Perechile din scenariul demo au alt nivel în DDInter decât în plan | B1 (T-B1 afișează nivelurile); se ajustează fixture-ul și textul pitch-ului, nu datele | B |
| Licența DDInter (CC BY-NC-SA) nu permite produs comercial | pitch, slide 6: date licențiate comercial după hackathon | amândoi |
| LLM vision lent / fără credite / fără internet | cache pe hash (B3, B7), timeouts, completare manuală | B |
| Recunoașterea vocală iOS în română (calitate, zgomot de sală, disponibilitate pe telefon) | testată la pregătire; dacă e slabă, Whisper (B5, punctul 6); în demo, microfonul aproape de gură; fallback text | A |
| Nimeni din echipă nu știe Swift; codul îl scriu agenții | secțiunea „Cum lucrați cu agenții” (0): build automat după fiecare modificare, teste pe iPhone la fiecare sync point, folder sincronizat în loc de `project.pbxproj`; dacă A1–A2 depășesc cu > 3 h, se taie primul graful din app (rămâne în portalul medicului), apoi X-urile | amândoi |
| VisionKit `DataScannerViewController` indisponibil pe un model de iPhone | verificat la pregătire (`isSupported`); fallback: poza + zxing-cpp pe server | A |
| Semnarea în Xcode pe două Team-uri diferite | P0: `Signing.local.xcconfig` cu bundle id local per persoană (ca la NeuroTrack) | A |
| Vocea TTS ro-RO lipsește sau sună rău pe iPhone | A4, verificat devreme; fallback: doar text mare | A |
| DataMatrix greu de citit pe cutii lucioase / curbate | A2, pe cutiile demo, în lumina sălii; fallback poză | A |
| Alert fatigue (prea multe alerte moderate / minore) | B2: minor ascuns, routing pe roluri, dedup per pereche; alertele de mâncare grupate într-un singur card | B |
| Golurile din DDInter: acenocumarol (Sintrom) fără niciun nivel, fără texte în fișierele descărcabile | `curated_ddi.csv` pentru perechile demo; regula de clasă ATC pentru `Unknown`, marcată „prin analogie, de confirmat de medicul de familie”; la pitch, prezentat ca limitare tratată transparent | B |
| Formulări care pot fi citite ca sfat medical | T-B2-03 (fără „opriți”, fără doze); disclaimer pe pagină și pe versiunea de tipărit | B |
| Designul (animații, materiale) mănâncă timp | 2.4.7: tokenii + 3 interacțiuni lucrate; restul componente de sistem | A |
| Skill-ul `apple-design` e pentru web; agenții pot reimplementa în Swift ce oferă deja sistemul sau pot ignora abaterile pentru vârstnici | `docs/DESIGN.md` (tabelul skill → SwiftUI) e citit în fiecare prompt A; 2.4.2 are prioritate; T-A6-01 prinde valorile scrise de mână | A |
| Limitele Claude Pro (fereastra de 5 h și plafonul săptămânal) în timp ce agenții scriu tot codul | două conturi Pro; Codex CLI și Gemini CLI ca rezerve cu același prompt; review-urile pe Gemini CLI; limita săptămânală verificată și păstrată plină înainte de hackathon | amândoi |
| Tier-ul gratuit Gemini API (limite mici, nepublicate; cererile pot fi folosite de Google) | doar rezervă, cu cache; date demo fictive; menționat la pitch | B |
| OCR-ul Apple pe cutii (font mic, reflexii, diacritice) | `customWords` cu brandurile; potrivire fuzzy; date OCR reale salvate la A2 pentru testele B3; rezerva Gemini; completare manuală | A, B |
| Agentul de review se oprește peste noapte (o aprobare cerută, Mac-ul adormit, simulatorul blocat) | `.claude/settings.json` cu permisiunile pre-aprobate (Q0), `caffeinate`, laptop la priză; testele UI tolerante la ecrane lipsă; dacă Q1 / Q3 n-au rulat până dimineața, se rulează doar fluxurile noi (`-only-testing`) în 15 min | A |
| Constatări din review prea multe sau vagi | maximum 25, fiecare cu captură și fix concret; trierea decide, nu agentul; după S4 se repară doar blocker-ele | amândoi |
| Notificări push reale (APNs) | decizie: **nu** la hackathon; polling la 10 s în prim-plan + notificări locale | A |
| 30 h în loc de 48 h | scope tăiat: fără Android, fără PDF generat, fără Whisper pe drumul critic, bonusurile X doar dacă S3 e la timp; după S4 (W24.5) nu se mai scrie cod nou | amândoi |
| Somnul | două nopți, în același timp pentru amândoi | amândoi |

---

## 10. Pregătirea dinainte de start (de făcut acum)

**Fără cod** până nu e clar regulamentul; tot ce urmează e research, date și materiale.

Primul pas:
- [x] *(sărit, decizie 12.11.2026)* Fără mesaj către organizatori: înainte de start nu se scrie cod, doar date, conturi, poze și materiale; codul începe la deschiderea hackathonului. Rămâne de citit regulamentul oficial / FAQ-ul.

Date și conturi:
- [x] Descărcat DDInter 2.0 în `kb/raw/ddinter/` (12.11.2026): 8 CSV-uri, coloanele și problemele notate în `kb/raw/ddinter/README.md`; nivelurile perechilor demo în `demo_pairs_report.csv`.
- [x] Descărcat catalogul românesc (Catalogul Public național al prețurilor maximale, Ministerul Sănătății, 04.08.2026) în `kb/raw/ro/`; coloanele și acoperirea în `kb/raw/ro/README.md`; OTC-urile demo în `kb/ro_products_extra.csv` (de completat după cutiile reale).
- [x] Completat `kb/curated_ddi.csv` (11 perechi) și `kb/curated_dfi.csv` (11 alimente) de pe site-ul DDInter (12.11.2026). Pe site, acenocumarolul e tot `Unknown` și fără texte, deci perechile lui sunt marcate `class_analogy` (prin warfarină).
- [x] Verificat în RCP (anm.ro, 12.11.2026): Sintrom 4.5 numește explicit IPP/omeprazol, simvastatină, hormoni tiroidieni, clasa AINS și alimentele cu vitamina K; **claritromicina și clasa macrolide nu sunt numite** (doar eritromicina), deci rândul acenocumarol+claritromicină rămâne analogie de clasă, de confirmat de medicul de familie. Simvastatină 4.3: claritromicina contraindicată (confirmat și în RCP-ul claritromicinei); max 20 mg/zi cu amlodipină (4.5). Euthyrox 4.5: IPP, calciu și soia confirmate, levotiroxina potențează cumarinicele; **cafeaua nu apare**, rândul levotiroxină+cafea a fost scos din `curated_dfi.csv`.
- [x] `kb/rules/elderly.yaml`: 13 reguli din AGS Beers 2023 (AINS cronic, AINS + anticoagulant, benzodiazepine, somnifere Z, antihistaminice de generația 1, triciclice, IPP > 8 săptămâni, sulfoniluree, digoxină > 0,125 mg, antipsihotice, metoclopramid, opioid + sedativ, ≥ 3 medicamente active pe SNC), pe coduri ATC verificate în catalogul românesc. ID-urile STOPP v3 sunt de completat doar dacă e timp.
- [x] `kb/rules/acb.yaml`: scala ACB 2012 (~75 de substanțe, scoruri 1–3, prag 3). Licența e Regenstrief: OK pentru prototip, permisiune pentru produs.
- [x] `kb/rules/timing.yaml`: 15 reguli de orar (Euthyrox, simvastatină și omeprazol verificate în RCP-urile de pe anm.ro; restul marcate `verified: false`). Pe demo: Euthyrox pe stomacul gol dimineața, la ≥ 4 h de calciu; omeprazol înainte de micul dejun; simvastatină seara; amitriptilină la culcare.
- [x] Cheie gratuită Gemini din Google AI Studio (fără card), în `~/.zshrc` pe Mac-ul lui Vladimir (12.11.2026); fiecare își face propria cheie și nu o trimite în chat sau în prompturi. Testat: `gemini-3.1-flash-lite` merge (200); `gemini-3.8-flash` și `gemini-3.5-flash` au dat 503 (supraîncărcate), `gemini-2.5-flash` 404. Test pe 8 poze de produs de pe catena.ro: 5 corecte pe toate câmpurile (Fromilid, Algocalmin, Sintrom, Euthyrox, Nurofen), Amlodipina corectă (a citit producătorul ca brand, vezi B3 punctul 3b), 2 imagini fără text (Simvastatin, Vasilip) → toate câmpurile `null`, adică nu inventează. Poze curate de produs sunt un test blând: **de repetat cu 3–4 poze reale făcute cu telefonul** (reflexii, text mic), inclusiv simvastatină și amlodipină, când aveți cutiile.
- [x] Verificat în Claude (Settings → Usage) când se resetează limita săptămânală pe ambele conturi (12.11.2026); în zilele dinainte, folosiți Claude puțin, ca să intrați în hackathon cu limita plină.
- [ ] *(opțional, sărit la pregătire)* Instalat și autentificat Codex CLI (contul ChatGPT Plus) și Gemini CLI (contul Google AI Pro); testat pe fiecare că poate citi o captură de ecran (pentru etapa Q). Fără ele, rezervele din „Cum lucrați cu agenții” se configurează în hackathon dacă e nevoie, iar review-urile Q rulează pe Claude Code.
- [x] Testat dictarea în română pe iPhone (12.11.2026): merge bine, deci recunoașterea vocală iOS rămâne calea principală și Whisper nu intră în B5. „Sintrom” a ieșit „sindrom” (`demo/transcripts/`): rezolvat prin `contextualStrings` (A5) și potrivirea pe lista pacientului (B5). Merge și în modul avion, deci transcrierea rulează pe telefon, fără internet.
- [x] Descărcată vocea română Enhanced / Premium pentru citire (Setări → Accesibilitate → Conținut vorbit → Voci) pe ambele iPhone-uri.
- [x] Verificat că Xcode, iOS SDK-ul și iPhone-ul se văd între ele; un proiect gol rulat pe telefon (12.11.2026, pe ambele Mac-uri și iPhone-uri).
- [x] Runtime-ul de simulator iOS și `ffmpeg` instalate (12.11.2026, pe ambele Mac-uri; runtime-ul are câțiva GB, nu se descarcă pe Wi-Fi-ul de la hackathon).
- [x] *(sărit, decizie 12.11.2026: înseamnă cod înainte de start; proiectul gol pe ambele iPhone-uri a trecut deja, iar acela era riscul real)* Testul cu agentul (1 h): cereți unui agent un proiect SwiftUI gol cu un ecran care afișează o listă dintr-un JSON local și rulați-l pe ambele iPhone-uri. Dacă merge fără să vă blocați, sunteți gata; dacă semnarea sau build-ul vă blochează, ați aflat acum, nu vineri seara. (Doar dacă regulamentul permite; altfel, doar proiectul gol din Xcode.)
- [x] *(sărit, decizie 12.11.2026; dacă Q1 sau Q3 nu rulează peste noapte, review-ul se face dimineața, ~15 min; testul se poate face în prima oră, cât se lucrează la P0)* Un test de noapte scurt: o sesiune Claude Code lăsată să ruleze 20 min fără să ceară aprobări, cu laptopul la priză, capacul deschis și `caffeinate -dimsu` (cu capacul închis, Mac-ul adoarme).

Materiale demo:
- [ ] Cutiile fizice (goale ajung) pentru cele 9 medicamente, sau cât mai multe; fotografiate fiecare din față și DataMatrix-ul; codurile DataMatrix scrise în `demo/datamatrix.txt`.
- [ ] O rețetă demo tipărită (format asemănător cu rețeta electronică, cu date fictive) pentru Fromilid 500 mg, 1-0-1, 7 zile.
- [ ] Check-in-ul demo dictat de 3 ori, cu voci diferite, pe iPhone (Dictare în română); textele rezultate, cu greșeli cu tot, salvate în `demo/transcripts/` (B5 le folosește ca teste).

Logistică:
- [x] Două iPhone-uri cu Developer Mode pornit; Team-ul Apple pe ambele Mac-uri; bundle id-uri locale ca la NeuroTrack.
- [x] Hotspot pe laptop testat cu ambele telefoane.
- [ ] Prelungitor, cabluri, încărcătoare.

---

## 11. După hackathon (pentru slide-ul „next steps”, nu pentru weekend)

- Date de interacțiuni licențiate comercial; validarea alertelor cu medici de familie și specialiști în farmacologie clinică.
- Integrare cu rețeta electronică (SIUI / PIAS) pentru import automat în loc de poze.
- Neo4j pentru graful populațional (ce combinații produc cele mai multe alerte la pacienții cabinetelor partenere).
- Push real (APNs), conturi și consimțământ GDPR complet, audit log; Android doar dacă pilotul o cere.
- Dozele individualizate (INR pentru anticoagulante, funcția renală) doar prin medic, niciodată automat.
- Din review-ul Q3 (aplicația, `docs/reviews/Q3.md`): avertizare „expiră curând” din DataMatrix (azi doar „expirat”); aderența săptămânală în portal („5 din 7 seri”, cu „neconfirmate”, nu „nelulate”); al doilea telefon al familiei legat de același pacient, fără reset; „Pot să iau…?” și pentru suplimente / plante (sunătoare, ginkgo), din surse verificate; QR spre fișă pe reconcilierea tipărită; graful what-if în portal pentru o întrebare gravă; istoricul pe zile în „Ziua de azi” (doar citire, butoane mari); exportul FHIR `MedicationStatement`; actualizarea cutiei existente la o scanare duplicat (expirare, lot), în loc de un al doilea medicament.

---

## Surse

- [DDInter 2.0: an enhanced drug interaction resource (Nucleic Acids Research, 2025)](https://academic.oup.com/nar/article/53/D1/D1356/7740584)
- [DDInter 2.0 (site)](https://ddinter2.scbdd.com/)
- [biothings/DDInter: licența datelor descărcabile (CC BY-NC-SA 4.0)](https://github.com/biothings/DDInter)
- [RxNav FAQ: oprirea API-ului de interacțiuni pe 2 ianuarie 2024](https://lhncbc.nlm.nih.gov/RxNav/information/FAQs.html)
- [ADAPT study: ADR-related hospital admissions in older patients (Frontiers in Pharmacology, 2023)](https://doaj.org/article/2c2aef1e004544c8a3dbfe4bf0f1e56b)
- [ADRs as cause of admission in older patients, meta-analiză (Eur J Clin Pharmacol)](https://link.springer.com/10.1007/s00228-017-2225-3)
- [Adverse drug reactions in older adults: a narrative review (European Geriatric Medicine)](https://link.springer.com/doi/10.1007/s41999-021-00481-9)
- [Hospitalizations Due to Adverse Drug Events in the Elderly (Frontiers in Pharmacology, 2016)](https://www.frontiersin.org/journals/pharmacology/articles/10.3389/fphar.2016.00358/full)
- [UniHack (Liga AC): FAQ](https://unihack.ligaac.ro/faq)
- [emilkowalski/skills: `apple-design` (MIT)](https://github.com/emilkowalski/skills/blob/main/skills/apple-design/SKILL.md)
