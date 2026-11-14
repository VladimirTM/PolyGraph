# tools/review/: turul de review pe simulator (etapa Q)

`make review Q=Q1` (sau `tools/review/run.sh Q1`) rulează turul automat al aplicației și lasă în `.review/Q1/` (gitignored) tot ce îi trebuie agentului de review. Planul e în docs/PLAN.md, „Q0 · Infrastructura de review”; raportul final merge în `docs/reviews/`.

## Ce face `run.sh`

1. Alege primul iPhone cu cel mai nou iOS (`xcrun simctl list devices available -j`) și, pentru rularea în paralel, clone cu același model, numite „<model> (review N)” (create o dată, refolosite, oprite la final). Pe fiecare: bara de stare fixă (9:41, baterie 100%), aspect Light, Increase Contrast oprit, permisiunea de microfon.
2. Pornește câte un backend per simulator: `make demo` (DEMO_MODE=1) pe primul port liber de la 8000 în sus, cu baza de date și media proprii în `.review/QN/backend-N/`, ca testele de pe simulatoare diferite să nu-și strice datele. Fără `kb/kb.sqlite` (nici în checkout-ul principal, de unde e legat automat într-un worktree), cade pe `make mock`. Așteaptă `/health`.
3. `xcodebuild build-for-testing` o singură dată, în `.review/DerivedData/`.
4. Transformă `app/Review.xctestplan` într-un `.xctestrun` (schema `PolyGraph` e autogenerată, `xcshareddata/` e ignorat în git, deci `-testPlan Review` nu e disponibil). Împarte testele pe simulatoare după durata măsurată (`review.py split`); fiecare simulator își trece testele prin Light, Dark, AX și Motion, apoi pornește `xcrun simctl ui <udid> increase_contrast enabled` și le trece prin Contrast.
5. Pe primul simulator, filmează `testTakenAndUndo` și `testVoiceCheckInFake` în Light și Motion (`simctl io recordVideo`) și extrage cu `ffmpeg` cadrele de la 0, 100, 200, 300, 500, 800 ms după fiecare atingere (`frames/`).
6. Unește rezultatele în `result.xcresult`, exportă atașamentele în `shots/` cu numele date de teste, salvează logul aplicației (`app-N.log`, subsystem `ro.polygraph`) și al backend-ului (`backend-N.log`), apoi scrie `index.md`.

Durata măsurată la Q0 (Mac cu 10 nuclee și 16 GB, 3 simulatoare iPhone 18 Pro, iOS 27.2, build incremental): **12 min 25 s** pentru 17 teste × 5 variante (246 de capturi). Ținta: < 15 min.

## Variabile

| Variabilă | Efect |
|---|---|
| `SIMS=3` | câte simulatoare în paralel (3 e maximul rezonabil pe un Mac cu 16 GB; 5 au dus load-ul la 350); `SIMS=1` = secvențial |
| `CONFIGS="Light Dark AX Motion Contrast"` | doar câteva variante (de ex. `CONFIGS=Light` pentru o verificare rapidă) |
| `ONLY="testDay testFeed"` | doar câteva teste din tur (de ex. fluxurile atinse de fix-uri, la Q2) |
| `TOUR=EdgeCaseTour` | altă clasă de teste din `app/PolyGraphUITests/` (implicit `ReviewTour`); filmarea rulează doar cu `ReviewTour`. Turul agresiv de la Q3: `make review Q=Q3e TOUR=EdgeCaseTour CONFIGS="Light AX" NO_VIDEO=1` |
| `NO_VIDEO=1` | fără video și cadre |
| `AUDIT=0` | fără `performAccessibilityAudit` (~2 s pe fiecare element nerezolvat); doar la depanare, nu la un review |
| `PORT=8000` | portul de la care se caută porturi libere |

## Ce produce

```
.review/QN/
  index.md                 capturile pe flux și variantă, erorile de audit, absentele, durata
  shots/<flux>-<NN>-<pas>-<variantă>.png
  shots/…​.elements.json    elementele vizibile: type, label, identifier, frame, isHittable (+ value, selected)
  shots/…​.audit.json       performAccessibilityAudit, colectat, nu oprit (la finalul fiecărui ecran): Light = toate
                           tipurile, Dark și Contrast = contrastul, AX = Dynamic Type, text tăiat, zone de atingere,
                           Motion = fără (randează ca Light)
  shots/<flux>-notes-<variantă>.json   ce n-a apărut („absent”) și numărul de probleme de audit
  frames/<flux>-<variantă>-<ms>ms.png  cadrele animațiilor lucrate
  animations.mp4, app-N.log, backend-N.log, test-*.log, result.xcresult
```

`isHittable` din `.elements.json` e aproximat (element activ cu centrul în ecran): cel real costă o cerere per element și ar lungi turul de câteva ori.

## Testele (`app/PolyGraphUITests/`)

- `PolyGraphUITests.swift`: `ReviewTestCase`, baza: pornirea cu variabilele `PG_*` (tabelul Q0), varianta din test plan (`PG_REVIEW_VARIANT`; Dark prin `XCUIDevice.appearance`, AX prin `-UIPreferredContentSizeCategoryName`, Motion prin `PG_REDUCE_MOTION=1`), `step()` (captură + elemente + audit), alertele de sistem, notarea „absent”.
- `ReviewTour.swift`: câte un test per flux (onboarding, medicamente, alerte și detaliu, graf, scanările false, „Acum” dimineața / la prânz / seara, „Am luat” + „Anulează”, ziua, check-in-ul vocal fals, Noutăți, codul pentru medic, setările demo, backend oprit).

În Motion rulează doar fluxurile cu tranziții proprii (`motionTests` din `ReviewTour`: onboarding, zoom-ul alertei, scanarea, „Am luat”, ziua, check-in-ul); restul apar ca „sărite”, pentru că o captură făcută după ce animațiile s-au terminat e identică cu Light. Mișcarea însăși se judecă din `frames/`.

Testele sunt tolerante: un identificator care nu apare (ecran neterminat, identificator suprascris) e notat „absent” și testul merge mai departe; nu pică. Identificatorii sunt cei din docs/DESIGN.md („Convenții de implementare”). Un test nou: o metodă în `ReviewTour` care cheamă `launch(...)` și `step(...)`.

## Cum iterezi (citește înainte să rulezi turul)

Turul complet (17 teste × 5 variante) ține 12–15 min. **Se rulează complet o singură dată**: la review (Q1, Q4) sau ca verificare finală după o modificare a turului. La Q0 s-au pierdut ~80 min pe 7 rulări complete, câte una după fiecare test reparat.

- Un test pică sau îl modifici: rulezi doar testul acela, într-o singură variantă, fără video și fără audit:
  `make review Q=dbg ONLY="testDay" CONFIGS=Light NO_VIDEO=1 AUDIT=0` (1–2 min). Varianta în care pică o adaugi în `CONFIGS` abia după ce merge în Light.
- Mai multe teste reparate: le rulezi împreună cu `ONLY="…"`, tot fără audit.
- La final: o singură rulare completă, `make review Q=QN`.
- Review după fix-uri (Q2, Q3): doar fluxurile atinse, `make review Q=Q2 ONLY="…" CONFIGS="Light AX" NO_VIDEO=1`, cu audit. Video doar dacă fix-ul atinge „Am luat” sau inelul microfonului.
- Agentul de review nu repornește turul dacă `.review/QN/` există deja: îl rulează omul o dată, agentul doar citește rezultatele.

## Aprobările

`.claude/settings.json` pre-aprobă comenzile turului (`make`, `xcodebuild`, `xcrun`, `ffmpeg`, `git`, `gh pr`, `curl` pe localhost, `run.sh`), ca turul să nu se oprească așteptând o aprobare cât omul lucrează în paralel. Pentru Gemini CLI, echivalentul se pune local, doar în acest repo (nu e în git): `.gemini/settings.json` cu `"tools": {"allowed": ["run_shell_command(make)", "run_shell_command(xcodebuild)", "run_shell_command(xcrun)", "run_shell_command(ffmpeg)", "run_shell_command(git)", "run_shell_command(curl)"]}`.

Review-urile rulează doar de zi, cu cineva lângă Mac (decizie 13.11.2026, docs/PLAN.md „Planul Q de zi”): fără `caffeinate`, fără rulări peste noapte. Laptopul la priză.
