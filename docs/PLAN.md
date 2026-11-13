# PolyGraph: plan de development pentru hackathon (~30 h de lucru, 2 developeri, iOS nativ)

**Track:** The Bloom (Connected Communities, Mobility & Healthcare) → **Medical Renaissance**
**Platformă:** aplicație **iOS nativă (SwiftUI)**, backend Python. Fără Android: echipa are două MacBook-uri și două iPhone-uri, iar demo-ul se face pe iPhone.
**Repo:** [github.com/VladimirTM/PolyGraph](https://github.com/VladimirTM/PolyGraph) (local: `~/Git/PolyGraph`)

**Pitch într-o frază:** pozezi cutiile de medicamente și rețetele bunicii; PolyGraph construiește graful ei terapeutic, găsește deterministic interacțiunile, dublurile și medicamentele nepotrivite vârstei, îi face un program zilnic simplu, o ascultă când spune cum se simte și ține familia, farmacistul și medicul de familie în aceeași buclă.

---

## Fazele de lucru și sync point-urile (de aici vedeți unde suntem)

**Unde suntem (13.11.2026):** S0 e trecut: P0 e în `main` ([PR #1](https://github.com/VladimirTM/PolyGraph/pull/1), [PR #2](https://github.com/VladimirTM/PolyGraph/pull/2)), CI verde, aplicația goală rulează pe ambele iPhone-uri, iar deciziile din `contracts/fixtures/README.md` sunt luate. **B1 e în `main`:** `make kb` construiește `kb/kb.sqlite` în ~1,5 s, `make check` are 72 de teste, `expected_alerts.json` are acum 27 / 6 alerte (3 adăugate prin regula de clasă), iar `app/PolyGraph/Resources/brands.txt` e gata pentru A2. **B2 e în `main`** ([PR #7](https://github.com/VladimirTM/PolyGraph/pull/7)): `polygraph.engine.analyze` dă exact `expected_alerts.json` (27 fără med_09, 33 cu med_09, aceleași id-uri și același `basis`) în ~10 ms, graful Cytoscape validează după `graph.schema.json`, iar `make dev` pornește backend-ul real (pacienți, `/meds`, `/analysis`, `/what-if`, `/kb/search`, `/demo/reset` cu `DEMO_MODE=1`) pe `app.sqlite`. **B3 e în `main`** ([PR #9](https://github.com/VladimirTM/PolyGraph/pull/9)), partea de backend: `/scan` real (GTIN cache → potrivire OCR → Gemini cu cache → completare manuală), `make demo-b3` arată fluxul cap-coadă pe date sintetice; rămân T-B3-02 și T-B3-04, care așteaptă OCR-ul și parserul GS1 din A2. `make check` are 170 de teste (în CI: 96 + 74 sărite fără `kb.sqlite`). **A1 e în `main`** ([PR #8](https://github.com/VladimirTM/PolyGraph/pull/8)): aplicația rulează pe mock pe ambele iPhone-uri și pe simulator (`make check-ios` verde, 18 teste). **B4 e în `main`** ([PR #13](https://github.com/VladimirTM/PolyGraph/pull/13)): `GET /schedule` real dă exact `expected_schedule.json` (5 momente, Euthyrox singur prin `alone: true` în `timing.yaml`) în ~4 ms, iar pe 200 de regimuri aleatoare nicio regulă dură nu e încălcată când `unsatisfied` e gol; regulile imposibile ies în `unsatisfied` și devin alerte `timing` (`ask_pharmacist`); `POST /doses` e idempotent pe `med_id` + `scheduled_at`. `make check` are 186 de teste. **Urmează:** Dev A pornește A2 (`feature/a2-scan`), Dev B închide B3 când vin datele din A2 (`demo/ocr/`, `GS1Tests`). Actualizați coloana „Status” la fiecare sync point.

Legendă: ⬜ neînceput · 🔄 în lucru · ✅ gata · ⚠️ blocat / tăiat

### Fazele, în ordine

| Faza | Cine | Ore de lucru | Ceas (orientativ) | Status | Ce iese |
|---|---|---|---|---|---|
| Pregătirea (secțiunea 10) | amândoi | înainte de start | până vineri | 🔄 | date, reguli YAML, conturi; rămân cutiile, rețeta tipărită, transcrierile, cablurile |
| **P0** repo, contracte, mock | amândoi | W0–W1.5 | V 18:00–19:30 | ✅ | `contracts/`, mock server, Makefile, CI, proiectul Xcode pe ambele iPhone-uri |
| **S0** | amândoi | W1.5 | V 19:30 | ✅ | contracte în `main`, mock pornit, Xcode pe ambele telefoane |
| A1 schelet iOS, tokeni, client API | Dev A | W1.5–W4 | V 19:30–22:00 | ✅ | app pe mock, pe ambele iPhone-uri (`make check-ios` verde, 18 teste) |
| B1 ingestia `kb.sqlite` + potrivirea | Dev B | W1.5–W8 | V 19:30–02:00 | ✅ | `make kb`, substanțele demo găsite |
| Q0 infrastructura de review | agent (worktree) | în paralel cu A2 | V seara | ⬜ | `make review Q=…` |
| A2 scanarea (DataMatrix, poză, rețetă, confirmare) | Dev A | W4–W8 | V 22:00–02:00 | ⬜ | cutie → listă, pe mock |
| B2 motorul de interacțiuni + graful | Dev B | W4–W12 | V 22:00–S 13:00 | ✅ | golden test = `expected_alerts.json` |
| **S1** | amândoi | W8 | S 02:00 | ⬜ | |
| Q1 review (noaptea) | agent | somn | S 02:00–09:00 | ⬜ | `docs/reviews/Q1.md`, triere 10 min |
| A3 medicamente, alerte, graf | Dev A | W8–W12 (+ integrare W12–W14) | S 09:00–16:00 | ⬜ | modul aparținător |
| B3 extracția (OCR → catalog, GS1, cache) | Dev B | W12–W14 | S 14:00–16:00 | 🔄 | `/scan` real |
| **S2** + Q2 | amândoi | W14 | S 16:00 | ⬜ | fluxul real cap-coadă |
| A4 modul senior | Dev A | W14–W19 | S 16:00–21:30 | ⬜ | Acum, Ziua de azi, „Am luat”, TTS, notificări |
| B4 solverul de program + B5 simptomele | Dev B | W14–W19 | S 16:00–21:30 | 🔄 | `/schedule`, `/checkins` reale; B4 gata (`/schedule`, `/doses`), B5 neînceput |
| **S3** (MVP complet) | amândoi | W19 | S 21:30 | ⬜ | |
| A5 check-in vocal + Noutăți | Dev A | W19–W23 | S 21:30–D 02:00 | ⬜ | |
| B6 pagina farmacistului + tipărire | Dev B | W19–W23 | S 21:30–D 02:00 | ⬜ | |
| Q3 review (noaptea) | agent | somn | D 02:00–08:00 | ⬜ | triere 15 min |
| A6 QR, modul demo · B7 demo hardening | A · B | W23–W24.5 | D 08:00–09:30 | ⬜ | + fix-urile blocker din Q3 |
| **S4** feature freeze + Q4 | amândoi | W24.5 | D 09:30 | ⬜ | după S4 nu se mai scrie cod nou |
| D1 integrare, repetiții, video de rezervă | amândoi | W24.5–W27.5 | D 09:30–12:30 | ⬜ | |
| D2 pitch, submit | amândoi | W27.5–W30 | D 12:30–15:00 | ⬜ | |

### Sync point-urile

| Sync point | Când | Condiție de trecere | Dacă pică | Status |
|---|---|---|---|---|
| **S0** | W1.5 | contractele în `main`, `validate.py` verde, mock-ul răspunde la toate rutele, proiectul Xcode rulează pe ambele iPhone-uri | nimeni nu începe A1 / B1 până nu e gata | ✅ (13.11.2026) |
| **S1** | W8 | app-ul pe iPhone, pe mock: lista, alertele, citirea unui DataMatrix; `kb.sqlite` construit, toate substanțele demo găsite cu ATC | B scoate catalogul RO și lucrează doar cu lista curată a pacientului demo + DDInter | ⬜ |
| **S2** | W14 | fluxul real: poză cutie → confirmare → salvat → alertele pacientului demo = `expected_alerts.json` (R4) | extracția rămâne pe cache pentru cutiile demo | ⬜ |
| **S3** | W19 | programul real pe telefon, „Am luat” salvat, un check-in transcris pe telefon cu simptomele corelate | se taie bonusurile; A5 se reduce la check-in prin text + Noutăți | ⬜ |
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
| W19–W23 | S 21:30–02:00 | A5 check-in vocal (pe telefon) + Noutăți | B6 pagina farmacistului + versiunea de tipărit |
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

> **Regula de aur a siguranței:** aplicația nu spune niciodată „opriți medicamentul X” și nu schimbă doze. Spune „discutați cu medicul / arătați farmacistului”, iar alertele grave merg la aparținător și la farmacist, nu doar la pacient.

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
  | Gemini CLI | Google AI Pro | rezerva lui Dev B (scripturi de date, teste Python, CSS-ul paginii farmacistului) și **agentul de review** din etapa Q (alt furnizor = verificare cu adevărat independentă, iar limitele Claude rămân pentru cod) |
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
| **Farmacistul** | farmacia de cartier | fișa de medicație prin link / QR temporar, poate marca alerte „verificat” și lăsa o notă |
| **Medicul de familie** | coordonatorul îngrijirii | aceeași fișă web + „Reconcilierea medicației” de tipărit (sau salvat ca PDF) pentru consultație |

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
| F10 | **Fișa pentru farmacist / medic** | QR / link cu token care expiră; pagină web cu lista, graful, alertele, aderența; farmacistul marchează „verificat” + notă; „Reconcilierea medicației” de tipărit | B (pagina), A (QR) |

### 1.3 Bonus (doar dacă sync point-ul S3 e atins la timp; la 30 h, realist doar X2, ca scenariu din modul demo)

| # | Feature | De ce e bun în pitch |
|---|---|---|
| X1 | **„Pot să iau…?”** prin voce („Pot să iau un Algocalmin?”) → același motor rulat ca „what-if” pe regimul curent → răspuns vocal | arată că motorul e reutilizabil; foarte natural pentru vârstnici |
| X2 | **Scenariul „medic nou”**: rețetă nouă scanată → alerta critică apare live pe telefonul aparținătorului și în pagina farmacistului | momentul „wow” din demo (se pregătește oricum ca script, X2 e doar varianta live, fără refresh) |
| X3 | Expirări și stoc („mai aveți pastile pentru 3 zile”) din numărul de comprimate de pe cutie | utilitate zilnică |
| X4 | Explicația în limbaj simplu, reformulată de LLM **strict din câmpurile alertei** (cu sursa) | accesibilitate |

### 1.4 Ce NU face (scris explicit în pitch și în aplicație)

- Nu pune diagnostice, nu schimbă și nu oprește medicamente, nu recomandă doze.
- Nu înlocuiește farmacistul sau medicul; îi aduce la aceeași informație.
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
│ share/     pagină Jinja + Cytoscape.js + note farmacist; versiune de tipărit    │
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

**Skill-ul e scris pentru web; SwiftUI are nativ aproape tot ce descrie.** Pagina farmacistului (B6) aplică skill-ul direct, în CSS. În aplicație, regula e: **folosește componenta de sistem care face deja ce cere skill-ul și scrie cod propriu doar unde nu există**. Tabelul de mai jos e traducerea; ce e în coloana a doua nu se reimplementează de mână.

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
| **Purpose** | Pacientul are **un singur ecran principal** („Acum”). Graful, sursele și severitățile există doar în modul aparținător și în pagina farmacistului. |
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
- **Fără roșu de alarmă pentru pacient.** Alertele grave se văd la Ana și la farmacist; Maria vede un card liniștit cu „Am anunțat-o pe Ana”.

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
| Construiește | proiectul iOS, tokenii de design (2.4, `docs/DESIGN.md`), clientul API, scanarea (DataMatrix + poză + rețetă), confirmarea, medicamentele și alertele, graful în WKWebView, modul senior (Acum, program, TTS, notificări), check-in-ul vocal pe telefon, Noutăți, QR, modul demo | ingestia datelor, potrivirea în nomenclator, motorul de interacțiuni, verificările pentru vârstnici, graful, solverul de program, pipeline-ul de extracție, înțelegerea simptomelor + corelarea, pagina farmacistului (și versiunea de tipărit), cache-ul pentru demo |
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
  "recommendation": "Discutați cu medicul cardiolog sau cu farmacistul înainte de următoarea doză de ibuprofen. Nu opriți anticoagulantul fără acordul medicului.",
  "action": "contact_doctor",
  "route_to": ["caregiver", "pharmacist"],
  "source": { "db": "ddinter", "ref": "<id DDInter substanța A> – <id DDInter substanța B>", "url": null },
  "basis": "direct",
  "analogy": null,
  "status": "open",
  "resolution": null
}
```

Reguli:
- `kind` ∈ `ddi`, `food`, `duplicate`, `elderly_pim`, `anticholinergic`, `timing`, `expired`, `symptom`.
- `severity` ∈ `critical`, `major`, `moderate`, `minor`, `info`. Sursele, în ordinea priorității: (1) `kb/curated_ddi.csv` (verificat de mână pe site-ul DDInter / în RCP; aici se marchează și perechile „contraindicat” → `critical`, ex. simvastatină + claritromicină); (2) nivelul DDInter: `Major` → `major`, `Moderate` → `moderate`, `Minor` → `minor`; (3) **regula de clasă** pentru `Unknown`: dacă o substanță din aceeași clasă ATC nivel 4 are nivel pentru aceeași pereche (ex. acenocumarol `B01AA07` → warfarină `B01AA03`), alerta preia nivelul, cu `basis = "class_analogy"`, `analogy = { "via": "warfarină", "atc4": "B01AA" }` și textul „evaluat prin analogie cu warfarina (aceeași clasă); de confirmat de farmacist”; (4) altfel, perechea `Unknown` nu produce alertă (doar o muchie gri în graf).
- `basis` ∈ `direct`, `curated`, `class_analogy`; se afișează în detaliul alertei și în pagina farmacistului.
- Afișarea pentru aparținător: `critical` și `major` sus, una câte una; `moderate` **grupate și restrânse** într-un singur card („6 interacțiuni moderate, de discutat cu farmacistul la următoarea vizită”); `minor` ascunse (vizibile doar în pagina farmacistului). **Alertele `food` nu intră printre cardurile grave, indiferent de severitate:** se grupează într-un singur card „Mâncare și băutură” (ex. grepfrutul cu simvastatina, care în DDInter e `Major`), sub cardurile grave.
- `action` ∈ `contact_doctor`, `ask_pharmacist`, `separate_times`, `avoid_food`, `monitor`, `replace_box`.
- `route_to` ⊆ `patient`, `caregiver`, `pharmacist`. Regula: `critical` și `major` (în afară de `food`) → `caregiver` + `pharmacist`; pacientul vede doar `patient_text`, fără termeni tehnici.
- `id` e determinist (tip + id-urile sortate), ca re-analiza să nu dubleze alertele.
- `status` ∈ `open`, `acknowledged`, `verified_by_pharmacist`; `resolution` = `{ "by": "pharmacist", "note": "...", "at": "..." }`.

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
- `unsatisfied` listează constrângerile imposibile (cu medicamentele implicate); fiecare intrare generează o alertă `timing` cu `action: ask_pharmacist`.

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
| GET | `/share/{token}` | pagina HTML pentru farmacist / medic | browser |
| POST | `/share/{token}/alerts/{alert_id}/verify` | `{ note }` → `status: verified_by_pharmacist` | pagina |
| GET | `/share/{token}/print` | „Reconcilierea medicației”, gândită pentru tipărire / „Salvează ca PDF” din browser | pagina |
| GET | `/v1/kb/search?q=` | autocomplete pentru adăugarea manuală | A |
| GET | `/share/{token}/graph?embed=1` | doar graful, pe tot ecranul, pentru WKWebView-ul din app (B6, A3) | A |
| POST | `/demo/reset` | doar cu `DEMO_MODE=1`: recreează pacientul demo din fixture (B7, A6, Q0) | A, Q |
| POST | `/demo/missed-dose` | doar cu `DEMO_MODE=1`: simulează o doză ratată (B7, A6) | A |

### 5.8 Pacientul demo (`contracts/fixtures/demo_patient.json`)

**Maria, 78 de ani, Timișoara; fiica, Ana, în Cluj.** 5 medici, niciunul nu vede lista completă.

| id | Produs (cutie) | Substanță | Prescris de | Posologie |
|---|---|---|---|---|
| med_01 | Sintrom 4 mg | acenocumarol | cardiolog | ½ seara |
| med_02 | Nurofen 400 mg (din `ro_products_extra.csv`, OTC) | ibuprofen | OTC (durere de genunchi) | 1-0-1 |
| med_03 | Simvastatin 40 mg | simvastatină | medic de familie | 0-0-1 |
| med_04 | Amlodipină 10 mg | amlodipină | medic de familie | 1-0-0 |
| med_05 | Euthyrox 75 mcg | levotiroxină | endocrinolog | dimineața, pe stomacul gol |
| med_06 | Calciu + D3 | carbonat de calciu + colecalciferol | medic de familie | 0-1-0 |
| med_07 | Omeprazol 20 mg | omeprazol | gastroenterolog (de 2 ani) | 1-0-0 înainte de masă |
| med_08 | Amitriptilină 25 mg | amitriptilină | neurolog | 0-0-1 |
| med_09 *(scenariul „medic nou”)* | Fromilid 500 mg (sau Klabax 500 mg; Klacid 500 mg există doar ca SR, o dată pe zi) | claritromicină | ORL, 7 zile | 1-0-1 |

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
- [ ] Mod **Cutie**: VisionKit `DataScannerViewController` (DataMatrix) + `capturePhoto()` pentru fața cutiei, într-un singur ecran
- [ ] Mod **Rețetă**: `VNDocumentCameraViewController` (decupează și îndreaptă foaia)
- [ ] Parser GS1 în Swift
- [ ] Upload multipart către `/scan`, cu stări de progres în cuvinte
- [ ] Sheet-ul de confirmare (detent `.large`), câmpurile nesigure marcate, „Salvează” → `POST /meds`
- [ ] Rețetă cu mai multe medicamente → pași „1 din 3” în același sheet

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
- [ ] T-A2-01 `GS1Tests` pe `contracts/fixtures/gs1_cases.json` (aceleași cazuri ca în Python, T-B3-04).
- [ ] T-A2-02 Unit: din `ExtractionResult`-ul fixture, modelul de confirmare marchează exact câmpurile cu `needs_review`, iar „Salvează” produce `MedicationItem`-ul editat.
- [ ] T-A2-03 Manual: 3 cutii demo + rețeta tipărită, pe iPhone, în lumina sălii.

---

### A3 · Medicamente, alerte, graf (modul aparținător)

**Responsabil:** Dev A · **Depinde de:** A1 (A2 în paralel) · **Durată:** 4 h + 2 h integrarea cu backend-ul real · **Branch:** `feature/a3-meds-alerts-graph`

**Checklist**
- [ ] Medicamente: `List` grupată pe medic, swipe-to-delete cu undo
- [ ] Alerte: carduri pe severitate; detaliul cu tranziție zoom din card
- [ ] Cardul ACB
- [ ] Graful în `WKWebView` (pagina lui B6; până atunci un HTML local cu Cytoscape)
- [ ] Detaliul unui medicament

~~~text
[WORKFLOW] Branch: feature/a3-meds-alerts-graph.

Citește .claude/skills/apple-design/SKILL.md (§3, §7, §12, §16) și docs/DESIGN.md (2.4.3–2.4.6). Aici nu scrii animații proprii: folosești List, NavigationStack, zoom transition și sheet-urile de sistem.

Obiectiv: modul Aparținător arată lista, alertele și graful pacientului.

1. MedsView: List(.insetGrouped) cu secțiuni pe prescriber.specialty („Cardiologie”, „Fără rețetă”); rând: AsyncImage cu poza cutiei (48 pt, rază 8), brand + concentrație, posologia în cuvinte („½ seara”), un punct de severitate + eticheta celei mai grave alerte. .swipeActions → Șterge: dispare imediat, apare un banner „Anulează” 5 s (agency, fără dialog), apoi DELETE. Toolbar: „+” → ScanView (fullScreenCover), „Arată farmacistului” → ShareSheet (A6). .refreshable.
2. AlertsView: ScrollView; sus, cardurile critical și major, câte unul pe alertă (fără alertele food); dedesubt, un singur card restrâns pentru toate alertele moderate („6 interacțiuni moderate, de discutat cu farmacistul la următoarea vizită”, DisclosureGroup); apoi un card restrâns „Mâncare și băutură” cu toate alertele food, indiferent de severitate; minor nu apar în aplicație (doar în pagina farmacistului). Card: punct + eticheta severității în cuvinte („Grav”), titlul, medicamentele ca chip-uri, o linie de recomandare; alertele cu basis = class_analogy au eticheta mică „prin analogie”. Fiecare card e .matchedTransitionSource(id: alert.id, in: ns) într-un NavigationLink.
3. AlertDetailView cu .navigationTransition(.zoom(sourceID: alert.id, in: ns)): „Ce înseamnă” (detail), „Ce puteți face” (recommendation), medicamentele (link la detaliu), sursa în .footnote („Sursa: DDInter 2.0”), statusul și nota farmacistului, buton „Am înțeles”. Închiderea interactivă (swipe în jos) și întoarcerea în card le face sistemul.
4. AcbCard deasupra alertelor dacă acb_total ≥ 1: scorul mare, o propoziție (≥ 3: „risc crescut de confuzie și căderi”), medicamentele care contribuie.
5. GraphView: UIViewRepresentable cu WKWebView care încarcă {baseURL}/share/{token}/graph?embed=1 (token creat o dată și ținut în AppStore). Până la B6: Graph/graph.html din bundle, cu cytoscape.min.js local, primind JSON-ul prin evaluateJavaScript. Tap pe muchie → WKScriptMessageHandler → deschide AlertDetailView. Fundal transparent, ca să se vadă fundalul aplicației.
6. MedDetailView (push): poza mare, substanțe, momentele din program, alertele lui, „Editează” (refolosește ConfirmSheet din A2).
7. Toate inserările / ștergerile din liste se fac în withPgAnimation(.pgStandard).

Criterii de acceptare: pe mock, alertele din expected_alerts.json (fără med_09) apar în ordinea corectă (4 carduri grave, sus); cardul se extinde în detaliu și se întoarce în el la swipe; tap pe o muchie din graf deschide alerta corectă.

Nu face: modul senior, vocea.
~~~

**Teste**
- [ ] T-A3-01 Unit: sortarea alertelor critical → minor și gruparea pe specialitate pe fixture-ul demo (6 grupuri).
- [ ] T-A3-02 Unit: ștergerea + „Anulează” în 5 s nu trimite DELETE.
- [ ] T-A3-03 Manual: graful pe iPhone, fără internet (doar rețeaua locală), se încarcă în < 2 s.

---

### A4 · Modul senior: Acum, Ziua de azi, „Am luat”, TTS, notificări

**Responsabil:** Dev A · **Depinde de:** A1; B4 pentru programul real (până atunci `expected_schedule.json` din mock) · **Durată:** 5 h · **Branch:** `feature/a4-senior-mode`

**Checklist**
- [ ] `NowView`: ora mare, momentul, dozele cu pozele cutiilor; suprafețe opace
- [ ] Trei `SeniorButton`: „Am luat” / „Mai târziu” / „Am sărit”, cu guard de 1 s
- [ ] **„Am luat” cu bifa care zboară în cronologie** + `.sensoryFeedback(.success)` + anulare 5 s
- [ ] `DayView`: cronologia momentelor
- [ ] TTS `AVSpeechSynthesizer` cu vocea `ro-RO`
- [ ] Notificări locale (`UNCalendarNotificationTrigger`) la fiecare moment

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
- [ ] T-A4-01 Unit: alegerea „momentului curent” pentru 6 ore ale zilei (înainte de trezire, între momente, după culcare).
- [ ] T-A4-02 Unit: „Am luat” apelat de două ori în 300 ms → un singur set de `POST /doses`; „Anulează” trimite `pending`.
- [ ] T-A4-03 Manual: Previews la `.accessibility3` fără text tăiat; o persoană care nu a văzut aplicația confirmă momentul fără explicații.

---

### A5 · Check-in vocal (pe telefon) și Noutăți

**Responsabil:** Dev A · **Depinde de:** A4; B5 pentru înțelegerea și corelarea simptomelor · **Durată:** 4 h · **Branch:** `feature/a5-voice-caregiver`

**Checklist**
- [ ] `VoiceCheckInView`: transcriere pe telefon cu `SFSpeechRecognizer(locale: ro-RO)`, textul apare în timp ce vorbește
- [ ] Atingere ca să pornească; se oprește la atingere, după 2 s de liniște sau la 60 s
- [ ] Inelul de ascultare care urmează nivelul vocii; static cu Reduce Motion
- [ ] Transcrierea → `POST /checkins` (text) → `reply_text` citit cu TTS
- [ ] Fallback: câmp text dacă recunoașterea vocală nu e disponibilă sau e refuzată
- [ ] Tab-ul Noutăți: polling la 10 s, inserare sus fără să miște lista sub deget, notificare locală la evenimente grave

~~~text
[WORKFLOW] Branch: feature/a5-voice-caregiver.

Citește .claude/skills/apple-design/SKILL.md (§1, §3, §13, §14) și docs/DESIGN.md (2.4.2, 2.4.4, 2.4.5).

Obiectiv: Maria spune cum se simte; Ana află în câteva secunde, pe alt telefon.

1. Voice/Listener.swift (@Observable): SFSpeechRecognizer(locale: Locale(identifier: "ro-RO")); requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition; SFSpeechAudioBufferRecognitionRequest cu shouldReportPartialResults = true și contextualStrings = numele comerciale și DCI-urile din lista pacientului + cele mai frecvente ~100 de branduri din brands.txt (la testul de pregătire, „Sintrom” a ieșit „sindrom”); AVAudioEngine cu tap pe input, din care calculezi și nivelul (RMS) pentru inel. Stop la a doua atingere, după 2 s cu nivel sub prag (după ce s-a vorbit ceva) sau la 60 s. Permisiunile (microfon + recunoaștere vocală) se cer la prima atingere, după o propoziție de motiv.
2. VoiceCheckInView (fundal opac): la deschidere, TTS „Cum vă simțiți azi? Apăsați butonul și spuneți-mi.”; buton circular de 160 pt (PressableButtonStyle); sub el, transcrierea parțială apare pe măsură ce Maria vorbește (feedback continuu, §1) și eticheta de stare („Vă ascult…”, „Am înțeles, mă gândesc…”).
3. Inelul: un cerc a cărui scară urmează nivelul netezit, actualizat cu withAnimation(.pgQuick) la fiecare valoare nouă (springul pornește de la valoarea curentă, deci nu sare). Cu Reduce Motion: inel static + textul de stare.
4. La oprire: POST /checkins cu { text: transcrierea finală } → reply_text mare (22 pt) + citit cu TTS; transcrierea mică, sub el. Dacă recunoașterea vocală nu e disponibilă sau e refuzată: TextField mare + „Trimite”. (Doar dacă testul de la pregătire a arătat că recunoașterea pe telefon e slabă în română: se trimite și înregistrarea audio, iar backend-ul folosește Whisper, vezi B5.)
5. intent = can_i_take (bonus X1, doar dacă S3 a fost atins la timp): card verde liniștit („Puteți lua”) sau nisip („Întrebați întâi farmacistul”), textul = reply_text.
6. FeedView (tab-ul Noutăți): polling GET /feed?since= la 10 s cât timp scenePhase == .active; elementele noi se inserează sus cu .pgStandard numai dacă lista e la început (ScrollPosition / onScrollGeometryChange); altfel apare o pastilă cu .regularMaterial „3 noutăți ↑” care derulează la început. Carduri pe tip: alertă nouă, doză ratată, check-in (transcriere, chip-uri cu simptome, „posibil legat de: Sintrom + Nurofen”), verificare de la farmacist (nota). Tap → AlertDetailView sau detaliul check-in-ului.
7. Eveniment nou cu severity critical / major sau escalate: notificare locală imediată (UNTimeIntervalNotificationTrigger 1 s) și, dacă aplicația e deschisă, .sensoryFeedback(.warning) pe același trigger cu inserarea cardului.

Criterii de acceptare: două iPhone-uri pe aceeași rețea; check-in-ul demo rostit pe telefonul 1 apare ca notificare pe telefonul 2 în < 15 s; textul apare pe ecran în timp ce Maria vorbește; înregistrarea se oprește singură când tace.

Nu face: push prin server (APNs); polling-ul ajunge pentru demo.
~~~

**Teste**
- [ ] T-A5-01 Unit: detectorul de liniște oprește după 2 s sub prag și nu oprește la o pauză de 1 s sau înainte să se fi vorbit.
- [ ] T-A5-02 Unit: feed-ul deduplică evenimentele la polling repetat (același `id`).
- [ ] T-A5-03 Manual: check-in-ul demo pe două telefoane, de 3 ori la rând, în zgomotul sălii; timpul până la notificare notat.

---

### A6 · QR de partajare, modul demo, trecerea de accesibilitate

**Responsabil:** Dev A · **Depinde de:** A3–A5, B6 · **Durată:** 1.5 h · **Branch:** `feature/a6-share-demo`

~~~text
[WORKFLOW] Branch: feature/a6-share-demo.

Citește .claude/skills/apple-design/SKILL.md (§14, §16, §17) și docs/DESIGN.md.

Obiectiv: aplicația e gata de scenă.

1. ShareSheet (.sheet, detents [.medium]): POST /share → QR generat cu CIFilter.qrCodeGenerator() (scalat fără interpolare, 260 pt, pe fundal alb și în dark mode), „Valabil până duminică, 15:00”, ShareLink cu url-ul. În modul senior: doar QR-ul și „Arătați acest cod la farmacie”, butonul în DayView.
2. Settings → Mod demo: „Resetează pacientul demo” (POST /demo/reset), „Adaugă rețeta ORL” (POST /meds cu med_09_fromilid.json din bundle), „Simulează doză ratată” (POST /demo/missed-dose).
3. Stări goale (ContentUnavailableView) cu o propoziție și o acțiune; erorile ca text inline în română, cu „Încearcă din nou”.
4. Icon și nume „PolyGraph”.
5. Trecerea finală, notată în docs/DESIGN.md: Reduce Motion (nicio mișcare spațială în fluxul demo), Increase Contrast, Reduce Transparency, Bold Text, Dynamic Type .accessibility3 în modul senior, VoiceOver pe „Acum → Am luat → Spuneți-mi cum vă simțiți”, dark mode; nicio valoare de animație / culoare scrisă de mână în afara Design/ (grep după `.spring(`, `Color(red:`, `.animation(.easeInOut`).

Criterii de acceptare: scenariul din secțiunea 7 rulează de 3 ori la rând, cu resetare între rulări, fără să atingi laptopul.
~~~

**Teste**
- [ ] T-A6-01 Test static în `make check-ios`: nicio apariție de `.spring(`, `Color(red:` sau `Animation.easeInOut(` în `app/PolyGraph/` în afara `Design/`.
- [ ] T-A6-02 Manual: QR-ul scanat cu camera celuilalt iPhone deschide pagina farmacistului.

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

**Status:** 🔄 Backend implementat și integrat în `main` ([PR #9](https://github.com/VladimirTM/PolyGraph/pull/9)). Testele locale acoperă cutiile pe transcrieri, rețeta fictivă din PDF, parserul Python pe fixture-ul GS1 comun și clientul Gemini cu răspunsuri simulate. Validarea pe OCR-ul și fotografiile A2 și comparația cu parserul Swift rămân de verificat. Reparat după review (`fix/b3-gemini`): Gemini e apelat o singură dată (maxim 8 s pe scanare), iar un răspuns gol nu mai rămâne în cache.

Rămase deschise (de rezolvat cel târziu la B7): `gtin_cache` ține id-ul produsului din `kb.sqlite`, deci trebuie golit după un `make kb` care schimbă id-urile; `/demo/reset` nu golește `gtin_cache` (după reset, cutia Sintrom scanată cu DataMatrix sare direct pe `gtin_cache`); genericele confirmate nu intră în `gtin_cache` (doar potrivirile exacte pe brand); un DataMatrix trimis, dar invalid, nu mai e căutat în imagine.

**Teste**
- [x] Gemini live: o imagine sintetică a produs candidatul Sintrom 4 mg (B01AA07). Rescanarea cu cheia dezactivată a întors același candidat din cache, fără apel de rețea.
- [x] T-B3-01 `posology.py`: 20 de formulări românești reale.
- [ ] T-B3-02 Toate cutiile demo găsite pe calea `ocr_match` (fără Gemini); rețeta demo complet.
- [x] T-B3-03 Un brand inexistent → `needs_review`, nicio substanță inventată (nici pe calea Gemini).
- [ ] T-B3-04 GS1: aceleași cazuri ca în T-A2-01 dau aceleași rezultate în Python și Swift (fixture comun în `contracts/fixtures/gs1_cases.json`).
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
5. (X1, doar dacă S3 a fost atins la timp) intent = can_i_take: drug_query → match.py (B3) → engine what-if → reply_text din template.
6. (Doar dacă recunoașterea vocală iOS a picat testul de la pregătire) polygraph/voice/stt.py: multipart audio → Whisper (API, language="ro"; altfel faster-whisper local) → același pipeline.

Criterii de acceptare: tests/test_voice_demo.py: checkin_demo → simptomele și corelările din fixture; 3 transcrieri reale făcute cu iPhone-ul la pregătire (demo/transcripts/*.txt, cu greșelile de recunoaștere cu tot) → aceleași coduri.
~~~

**Teste**
- [ ] T-B5-01 Calea deterministă recunoaște simptomele din 10 propoziții de test (inclusiv fără diacritice), fără niciun apel la Gemini.
- [ ] T-B5-02 LLM-ul nu poate întoarce un cod din afara enum-ului (test cu un răspuns falsificat → respins).
- [ ] T-B5-03 `POST /checkins` (text) < 4 s pe laptopul de demo.

---

### B6 · Pagina farmacistului / medicului și versiunea de tipărit

**Responsabil:** Dev B · **Depinde de:** B2, B4 · **Durată:** 3 h · **Branch:** `feature/b6-share`

~~~text
[WORKFLOW] Branch: feature/b6-share.

Citește .claude/skills/apple-design/SKILL.md: pagina e web, deci skill-ul se aplică direct (§1, §7, §12, §14, §15, §16), fără traducerea SwiftUI din docs/DESIGN.md; din DESIGN.md iei doar culorile, severitățile și textele.

Obiectiv: o pagină pe care farmacistul o deschide din QR și înțelege situația în 30 de secunde.

1. POST /share → token aleator (secrets.token_urlsafe(16)), expires_at = acum + 72 h, în share_tokens. Token expirat → pagină „Linkul a expirat”.
2. GET /share/{token} (Jinja2 + un singur CSS + cytoscape.min.js servit local): antet (nume, vârstă, „Fișă generată de PolyGraph, nu înlocuiește evaluarea profesională”), rezumatul („9 medicamente de la 5 medici · 2 alerte grave · ACB 3 · aderență 86% în ultimele 7 zile”), tabelul medicamentelor (brand, DCI, ATC, posologie, prescriptor, de când), alertele cu sursa și formularul „Am verificat” + notă (POST /share/{token}/alerts/{id}/verify), graful, check-in-urile din ultimele 7 zile, programul zilei.
   Design (skill-ul, aplicat pe web):
   - tipografie: font: 100%/1.5 system-ui; titlul paginii cu letter-spacing -0.02em și line-height 1.1, corpul la 0, notele mici la +0.01em; spațieri în rem, ca zoom-ul și mărimea textului din browser să nu strice layout-ul;
   - antet sticky translucid (background rgba alb 0.7 + backdrop-filter: blur(20px) saturate(180%)), conținutul derulează pe sub el; în loc de border, un gradient de margine afișat doar când pagina e derulată;
   - ordinea pe ecran = ordinea importanței: rezumatul, apoi alertele grave, apoi restul; detaliile (mecanism, ATC) în <details> deschis la cerere;
   - butoanele „Am verificat” cu :active { transform: scale(0.97) } instant; trimiterea prin fetch, cu starea schimbată inline („Verificat de dumneavoastră acum”), fără reîncărcarea paginii; eroarea inline, lângă buton;
   - @media (prefers-reduced-motion: reduce) fără tranziții de poziție; (prefers-reduced-transparency: reduce) antet opac; (prefers-contrast: more) fundaluri solide și margini vizibile; dark mode cu prefers-color-scheme;
   - un singur fișier CSS, fără framework; doar transform și opacity în tranziții.
3. GET /share/{token}/graph?embed=1: doar graful, pe tot ecranul, pentru WKWebView-ul din app (A3), cu fundal transparent, aceleași culori și același font (-apple-system) ca aplicația; tap pe o muchie → window.webkit.messageHandlers.alert.postMessage(alert_id).
4. GET /share/{token}/print: aceeași pagină, cu un stylesheet @media print (fără graf interactiv, fără butoane, A4, 1–2 pagini): „Reconcilierea medicației” pentru medicul de familie: medicamente (pe prescriptori), probleme găsite (cu sursa), întrebări propuse pentru consultație (din template-uri per kind), spațiu pentru semnătură. Farmacistul sau medicul o salvează ca PDF din browser; fără WeasyPrint (economisim instalarea și depanarea lui).
5. Verificarea de către farmacist apare în feed (A5) și pe alertă (A3).

Criterii de acceptare: pagina se încarcă pe un telefon în < 2 s pe rețeaua locală; versiunea de tipărit a pacientului demo încape în ≤ 2 pagini A4 (Print Preview în Safari) și are toate alertele major / critical; o verificare făcută în pagină apare în app la următorul polling.
~~~

**Teste**
- [ ] T-B6-01 Token expirat / inexistent → 404 cu pagina prietenoasă, fără date.
- [ ] T-B6-02 HTML-ul de la `/print` conține fiecare alertă `major` / `critical`.
- [ ] T-B6-03 Escape HTML pe nota farmacistului (XSS simplu: `<script>` rămâne text).
- [ ] T-B6-04 Manual: pagina pe un iPhone cu Reduce Motion, Reduce Transparency și Increase Contrast pornite; pe desktop la zoom 200%.

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

---

### Q · Verificarea pe simulator, făcută de agent, după fiecare milestone

**Ce este.** După S1, S2, S3 și S4, un agent (o sesiune **nouă**, de preferat de la alt furnizor decât cel care a scris codul: Gemini CLI) rulează aplicația pe simulatorul iOS, parcurge fiecare funcționalitate livrată până atunci și scrie un raport cu bug-uri, inconsistențe și îmbunătățiri de UI/UX, fiecare cu o captură de ecran și un fix propus. Agentul de review **nu modifică codul aplicației**: doar raportează și poate adăuga teste în `PolyGraphUITests/`. Voi alegeți ce se repară; fix-urile le face apoi agentul obișnuit, pe branch-uri `fix/qN-…`.

**De ce o sesiune nouă:** agentul care a scris ecranul tinde să-și confirme propria muncă. O sesiune care pornește doar de la plan, `docs/DESIGN.md` și skill vede aplicația ca un utilizator nou.

| Review | Când | Unde rulează | Ce acoperă | Cât costă oamenii |
|---|---|---|---|---|
| **Q1** | după S1 (W8), **peste noapte** | Mac-ul lui Dev A, cât dormiți | onboarding, navigarea, medicamentele și alertele pe mock, sheet-ul de confirmare cu scanarea simulată | 10 min de triere dimineața |
| **Q2** | după S2 (W14) | Mac-ul lui Dev B, în paralel cu lucrul | fluxul real: scanare → confirmare → alerte → graf; erorile de rețea; + verificarea fix-urilor din Q1 | 10 min de triere |
| **Q3** | după S3 + A5 / B6 (W23), **peste noapte** | Mac-ul lui Dev A | tot MVP-ul: modul senior, programul, „Am luat”, check-in-ul, Noutăți, pagina farmacistului; toate variantele de accesibilitate | 15 min de triere dimineața; fix-urile blocker / major în W23–W24.5 |
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
   c. Consistență: aceeași acțiune are același nume peste tot („Am luat”, nu și „Luat” / „Confirmă”); același termen pentru același lucru (medicament / pastilă / cutie, folosite consecvent); diacritice corecte; formatul orei (24 h, „ora 13”); etichetele severității identice în card, detaliu, feed și pagina farmacistului; aceleași componente arată și se comportă la fel pe ecrane diferite.
   d. Designul (DESIGN.md și skill-ul): răspuns instant la apăsare; componente de sistem folosite acolo unde DESIGN.md o cere; consistență spațială (detaliul iese din card și se întoarce în el); fără animații cu overshoot în afara gesturilor cu impuls; suprafețe opace în modul senior; din cadrele extrase: „Am luat” fără salturi între cadre și fără mișcare cu PG_REDUCE_MOTION.
   e. Accesibilitate: erorile din performAccessibilityAudit; în varianta AX, text tăiat sau elemente suprapuse; ținte de atingere în modul senior < 72 pt (din frame-urile din JSON); butoane fără label; contrast vizibil insuficient în Dark și Contrast.
   f. UX pentru vârstnici (2.4.2): o singură acțiune principală pe ecran; nicio acțiune disponibilă doar prin gest; ce urmează e clar fără explicații; stările de status, finalizare, avertizare și eroare (2.4.6) există și sunt în cuvinte simple.
   g. Stări limită: backend oprit, cutie ilizibilă, listă goală, alertă verificată de farmacist, medicament expirat, moment fără doze.
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

### D1 · Integrare, repetiții, video de rezervă (împreună)

**Durată:** W24.5–W27.5

- [ ] `make demo-check` verde pe `main`
- [ ] Q4: raportul `docs/reviews/Q4.md` fără blocker deschis; regresia constatărilor din Q1–Q3 verde
- [ ] Scenariul din secțiunea 7 rulat cronometrat de 3 ori, cu resetare între rulări; fiecare problemă → fix doar dacă e < 20 min, altfel se scoate din scenariu
- [ ] Înregistrare ecran (ambele telefoane + pagina farmacistului) a unei rulări curate: **video de rezervă** dacă ceva pică pe scenă
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

Telefonul 1 = Maria (modul senior). Telefonul 2 = Ana (aparținător). Laptopul = farmacia (pagina din QR), proiectat pe ecran.

| Timp | Ce se întâmplă | Ce spunem |
|---|---|---|
| 0:00 | Punga cu 8 cutii reale pe masă | „Maria are 78 de ani, 5 medici și 8 cutii. Niciun medic nu vede punga întreagă.” |
| 0:15 | Ana scanează 2 cutii live (DataMatrix + poză) → confirmare → salvat (restul sunt deja în app după reset) | „Codul de pe cutie dă data expirării; poza dă substanța activă, potrivită în nomenclatorul românesc, nu ghicită.” |
| 0:45 | Ecranul de alerte + **graful**: muchia roșie Sintrom – Nurofen; Beers pe amitriptilină; ACB 3 | „Fiecare alertă vine dintr-o bază de date cu sursa afișată. LLM-ul doar citește poza.” |
| 1:15 | Telefonul Mariei: „Acum”, cu poza Euthyrox-ului, TTS citește instrucțiunea, „Am luat” | „Programul îl calculează un solver: Euthyrox singur dimineața, calciul la 4 ore distanță, 5 momente pe zi în loc de 8.” |
| 1:40 | Maria apasă microfonul: „Dimineața, când mă ridic din pat, mi se învârte capul și am observat niște vânătăi pe mână” | – |
| 1:55 | Pe telefonul Anei: notificare „Maria a raportat: amețeală, vânătăi; posibil legat de Sintrom + Nurofen” | „Vânătăile au fost legate de interacțiunea deja găsită; Ana află în câteva secunde, din alt oraș.” |
| 2:10 | **Medic nou:** Ana scanează rețeta ORL (Fromilid, claritromicină) → alertă **critică** simvastatină + claritromicină și una gravă Sintrom + claritromicină, pe ambele telefoane | „Al șaselea medic a prescris un antibiotic. PolyGraph a prins două conflicte înainte de prima pastilă.” |
| 2:30 | QR → laptopul (farmacia): fișa, farmacistul bifează „verificat” + notă → apare la Ana | „Familia, farmacistul și medicul de familie văd aceeași fișă. Asta e comunitatea conectată din The Bloom.” |
| 2:50 | „Reconcilierea medicației” (versiunea de tipărit) | „Și asta o duce Maria la medicul de familie.” |

Plan B pentru fiecare pas: scanarea pică → butonul „Adaugă rețeta ORL” din modul demo; recunoașterea vocală pică → check-in prin text; rețeaua pică → hotspot-ul laptopului + cache; totul pică → video-ul de rezervă.

---

## 8. Pitch (7 slide-uri + demo)

1. **Problema, cu cifre:** în Europa, ~1 din 10 internări ale vârstnicilor e legată de reacții adverse la medicamente (studiul ADAPT, Irlanda: 10,0%; o meta-analiză pe pacienți vârstnici: 8,7%); Comisia Europeană a estimat ~5% din toate internările și ~197.000 de decese pe an în UE din reacții adverse. Polimedicația crește riscul de internare de ~3 ori într-un studiu finlandez (OR 3,3).
2. **De ce acum / de ce noi:** nimeni nu vede lista completă; medicii nu comunică; vârstnicul e singurul „integrator”. API-ul public de interacțiuni al NLM a fost oprit în 2024, deci soluțiile simple nu mai merg.
3. **Soluția:** poză → graf → alerte deterministe → program simplu → voce → familia și farmacistul în buclă.
4. **Demo** (secțiunea 7).
5. **Cum e construit:** diagrama din 2.1 cu regula „LLM doar la margini”; DDInter 2.0 + nomenclatorul RO + Beers / STOPP / ACB; solverul; designul pentru vârstnici (un singur ecran, butoane mari, fără gesturi, Reduce Motion / Dynamic Type respectate).
6. **Impact și model:** familia (abonament mic), farmaciile (serviciu de revizuire a medicației, diferențiator pentru lanțuri), medicii de familie (fișa de reconciliere, timp câștigat). Pași următori: date licențiate comercial, pilot cu o farmacie din Timișoara, integrare cu rețeta electronică.
7. **Responsabil:** nu diagnosticăm, nu schimbăm doze; GDPR (date de sănătate, partajare cu token care expiră); drumul spre conformitate MDR (după Regula 11 din MDR, un software care dă informații pentru decizii terapeutice e, probabil, cel puțin clasa IIa; de confirmat cu un specialist în reglementare).

Întrebări probabile de la juriu (de pregătit răspunsul în 2 fraze): „De unde știți că alertele sunt corecte?” · „Ce faceți cu alert fatigue?” (severități, minor ascuns, routing pe roluri) · „Licența datelor?” · „De ce n-ar face asta farmacia direct?” · „Cum convingeți un vârstnic să folosească telefonul?” (familia face setup-ul; seniorul are un singur ecran și vocea).

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
| Nimeni din echipă nu știe Swift; codul îl scriu agenții | secțiunea „Cum lucrați cu agenții” (0): build automat după fiecare modificare, teste pe iPhone la fiecare sync point, folder sincronizat în loc de `project.pbxproj`; dacă A1–A2 depășesc cu > 3 h, se taie primul graful din app (rămâne în pagina farmacistului), apoi X-urile | amândoi |
| VisionKit `DataScannerViewController` indisponibil pe un model de iPhone | verificat la pregătire (`isSupported`); fallback: poza + zxing-cpp pe server | A |
| Semnarea în Xcode pe două Team-uri diferite | P0: `Signing.local.xcconfig` cu bundle id local per persoană (ca la NeuroTrack) | A |
| Vocea TTS ro-RO lipsește sau sună rău pe iPhone | A4, verificat devreme; fallback: doar text mare | A |
| DataMatrix greu de citit pe cutii lucioase / curbate | A2, pe cutiile demo, în lumina sălii; fallback poză | A |
| Alert fatigue (prea multe alerte moderate / minore) | B2: minor ascuns, routing pe roluri, dedup per pereche; alertele de mâncare grupate într-un singur card | B |
| Golurile din DDInter: acenocumarol (Sintrom) fără niciun nivel, fără texte în fișierele descărcabile | `curated_ddi.csv` pentru perechile demo; regula de clasă ATC pentru `Unknown`, marcată „prin analogie, de confirmat de farmacist”; la pitch, prezentat ca limitare tratată transparent | B |
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
- [x] Verificat în RCP (anm.ro, 12.11.2026): Sintrom 4.5 numește explicit IPP/omeprazol, simvastatină, hormoni tiroidieni, clasa AINS și alimentele cu vitamina K; **claritromicina și clasa macrolide nu sunt numite** (doar eritromicina), deci rândul acenocumarol+claritromicină rămâne analogie de clasă, de confirmat de farmacist. Simvastatină 4.3: claritromicina contraindicată (confirmat și în RCP-ul claritromicinei); max 20 mg/zi cu amlodipină (4.5). Euthyrox 4.5: IPP, calciu și soia confirmate, levotiroxina potențează cumarinicele; **cafeaua nu apare**, rândul levotiroxină+cafea a fost scos din `curated_dfi.csv`.
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

- Date de interacțiuni licențiate comercial; validarea alertelor cu un farmacist clinician.
- Integrare cu rețeta electronică (SIUI / PIAS) pentru import automat în loc de poze.
- Neo4j pentru graful populațional (ce combinații produc cele mai multe alerte în farmaciile partenere).
- Push real (APNs), conturi și consimțământ GDPR complet, audit log; Android doar dacă pilotul o cere.
- Dozele individualizate (INR pentru anticoagulante, funcția renală) doar prin medic, niciodată automat.

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
