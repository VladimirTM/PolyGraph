# Designul PolyGraph: skill-ul `apple-design`, aplicat în SwiftUI

> Extras din `docs/PLAN.md`, secțiunea 2.4 (numerotarea e păstrată, ca trimiterile din prompturi să funcționeze). Dacă se schimbă ceva, se schimbă în ambele locuri.


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

## 2.4.1 Cele opt principii, aplicate la PolyGraph

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

## 2.4.2 Deciziile specifice pentru vârstnici (unde ne abatem conștient de skill)

- **Fără acțiuni doar prin gest în modul senior.** Tremorul face swipe-urile și long-press-urile nesigure: totul e buton mare (≥ 72 pt înălțime, pe toată lățimea). Gesturile (swipe-to-delete, sheet-uri glisabile) există doar în modul aparținător.
- **Feedback instant, commit protejat.** Butonul se micșorează imediat la atingere (§1); acțiunea pornește la ridicarea degetului, iar a doua apăsare pe aceeași doză în următoarea secundă e ignorată (și backend-ul e idempotent pe doză).
- **Microfonul: atingere ca să pornească, atingere sau liniște ca să se oprească**, nu „țineți apăsat”. Oprire automată după 2 s de liniște sau 60 s.
- **Suprafețe opace în modul senior.** Materialele translucide rămân doar în chrome-ul de sistem al modului aparținător.
- **Fără roșu de alarmă pentru pacient.** Alertele grave se văd la Ana și la medicul de familie; Maria vede un card liniștit cu „Am anunțat-o pe Ana”.

## 2.4.3 Tokenii (`app/PolyGraph/Design/`)

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

## 2.4.4 Consistență spațială și direcție (skill §7–§8)

- **Cardul de alertă → detaliul**: tranziție zoom din card (`.navigationTransition(.zoom)`), cu închidere interactivă înapoi în card.
- **Scanare → confirmare**: sheet de sistem (detent `.large`, cu fundalul întunecat de sistem, pentru că e sarcină blocantă). Ecranele împinse în stivă intră și ies pe dreapta (`NavigationStack`).
- **„Am luat”**: bifa se micșorează și se mișcă (`pgMove`, `matchedGeometryEffect`) spre punctul momentului din cronologia de sus, care se umple; cardurile ies în aceeași direcție.
- **Tab-ul Noutăți**: elementele noi apar sus cu `pgStandard` numai dacă lista e la început; altfel, o pastilă „3 noutăți ↑” (lista nu se mișcă sub degetul cuiva).

## 2.4.5 Feedback multimodal (skill §13)

| Eveniment | Vizual | Haptic (`.sensoryFeedback`) | Sunet / voce |
|---|---|---|---|
| Atingere pe orice buton | scale 0.97 instant | – | – |
| DataMatrix citit | contur verde pe cod | `.impact(weight: .medium)` | – |
| „Am luat” confirmat | bifa zboară în cronologie | `.success` | TTS: următorul moment |
| Alertă nouă `critical` / `major` (la Ana) | card nou sus | `.warning` | notificarea sistemului |
| Eroare (scanare nereușită) | mesaj inline, sub buton | `.error` | – |

Vizualul, haptica și vocea pornesc din aceeași schimbare de stare. Fără haptic pe navigare sau pe scroll.

## 2.4.6 Accesibilitate și orientare

- Ecranele se verifică în Xcode Previews la `dynamicTypeSize` `.large`, `.xxxLarge` și `.accessibility3`, în light și dark: nimic tăiat (cardurile cresc pe verticală).
- VoiceOver: fiecare card de doză e un singur element (`.accessibilityElement(children: .combine)`); butoanele au etichete de acțiune („Confirmă că ați luat Euthyrox, o pastilă”).
- **Patru tipuri de feedback** (skill §16): status („Citesc cutia…”), finalizare („Am salvat. 2 alerte noi”), avertizare (cutie expirată, înainte de salvare), eroare (inline, lângă câmpul greșit).
- **Etichete specifice**: tab-urile aparținătorului sunt „Medicamente”, „Alerte”, „Graf”, „Noutăți”. Modul senior nu are tab-uri: „Acum”, cu „Ziua de azi” un nivel mai jos.

## 2.4.7 Bugetul de design la 30 h

Doar **tokenii + 3 interacțiuni lucrate**: butonul cu răspuns instant și guard, „Am luat” cu bifa care zboară, inelul de ascultare la microfon. Restul (sheet-uri, zoom, materiale, liste, rubber-band) sunt componente de sistem folosite corect, fără cod de animație propriu. Orice altă animație se adaugă doar dacă S3 a fost atins la timp.

## Convenții de implementare (completate la A1 și A6)

- **`accessibilityIdentifier`**: `"<ecran>.<element>"` pe fiecare buton, câmp, card și tab (ex. `now.takenButton`, `alerts.card.<id>`, `scan.shutter`). Lista de mai jos e completată la fiecare etapă care adaugă un ecran.

  | Ecran | Identificatori (A1) |
  |---|---|
  | pornire | `root.loading` |
  | onboarding | `onboarding.progress`, `onboarding.role.senior`, `onboarding.role.caregiver`, `onboarding.demoButton`, `onboarding.nameField`, `onboarding.birthYearPicker`, `onboarding.wakeTime`, `onboarding.breakfastTime`, `onboarding.lunchTime`, `onboarding.dinnerTime` (fiecare cu `.picker` când e deschis), `onboarding.bedTime`, `onboarding.nextButton`, `onboarding.finishButton`, `onboarding.backButton`, `onboarding.error` |
  | Acum (senior) | `now.clock`, `now.dayButton`; A4: `now.timeline`, `now.timeline.<HH:MM>`, `now.momentLabel`, `now.statusLine`, `now.speakButton`, `now.dose.<med_id>`, `now.takenButton`, `now.laterButton`, `now.skippedButton`, `now.undoBanner`, `now.undoButton`, `now.doneLabel` (moment deschis din „Ziua de azi”), `now.dayDone`, `now.error`, `now.patientNotice` (+ `.text`, `.okButton`), `now.reminders` (+ `.allowButton`, `.laterButton`) |
  | Ziua de azi | `day.moment.<HH:MM>` (rândul deschide momentul), `day.error` |
  | tab-uri (aparținător) | conținutul: `tab.meds`, `tab.alerts`, `tab.graph`, `tab.feed`; butoanele din tab bar se caută după etichetă („Medicamente”, „Alerte”, „Graf”, „Noutăți”), SwiftUI nu le poate da identificator |
  | Medicamente | `meds.list`, `meds.row.<med_id>`, `meds.loading`, `meds.empty`, `meds.error`, `meds.retryButton`; A2: `meds.addButton`, `meds.emptyScanButton`, `meds.savedBanner`, `meds.savedBanner.showAlerts`; A3: `meds.row.<med_id>.alert` (cea mai gravă alertă), `meds.deleteButton.<med_id>` (swipe), `meds.undoBanner`, `meds.undoButton`, `meds.deleteError` |
  | Scanare (A2) | `scan.closeButton`, `scan.modePicker`, `scan.guidance`, `scan.shutter`, `scan.manualButton`, `scan.error`, `scan.retryButton`, `scan.unavailable`, `scan.unavailable.manualButton`; camera falsă (Debug): `scan.fakeCamera`, `scan.fake.usePage` |
  | Confirmare (A2) | `confirm.cancelButton`, `confirm.strengthWarning` (A3), `confirm.discardButton`, `confirm.saveButton`, `confirm.skipButton`, `confirm.error`, `confirm.expiredWarning`, `confirm.duplicateWarning`, `confirm.warnings`, `confirm.reviewBadge`, `confirm.brandField`, `confirm.strengthField`, `confirm.substance.<i>`, `confirm.substance.missing`, `confirm.searchCatalog`, `confirm.dose.morning` / `noon` / `evening` / `bedtime`, `confirm.asNeededToggle`, `confirm.foodPicker`, `confirm.prescriberField`, `confirm.specialtyField`, `confirm.expiryPicker`, `confirm.addExpiryButton`, `confirm.exportOCRButton` (Debug); căutarea în catalog: `kbsearch.list`, `kbsearch.result.<i>` |
  | Alerte (A3) | `alerts.list`, `alerts.loading`, `alerts.error`, `alerts.retryButton`, `alerts.empty`, `alerts.acbCard`, `alerts.card.<alert_id>` (și rândurile din cardurile restrânse), `alerts.moderateGroup`, `alerts.foodGroup` |
  | Detaliul alertei (A3) | `alertDetail`, `alertDetail.header`, `alertDetail.detail`, `alertDetail.recommendation`, `alertDetail.med.<med_id>`, `alertDetail.status`, `alertDetail.doctorNote`, `alertDetail.source`, `alertDetail.understoodButton` |
  | Detaliul medicamentului (A3) | `medDetail`, `medDetail.substances`, `medDetail.schedule`, `medDetail.alert.<alert_id>`, `medDetail.editButton` (deschide `ConfirmSheet` în modul de editare) |
  | Graf (A3) | `graph.web`, `graph.loading`, `graph.empty`, `graph.legend`, `graph.resetButton` |
  | Noutăți (placeholder) | `feed.placeholder` |
  | Setări | `settings.openButton` (rotița din bara de navigare), `settings.baseURLField`, `settings.checkConnectionButton`, `settings.connectionStatus`, `settings.rolePicker`, `settings.demoModeToggle`, `settings.useDemoPatientButton`, `settings.speakOnOpenToggle` (A4, doar pacient), `settings.signOutButton`, `settings.confirmSignOutButton`, `settings.doneButton` |
- **Logurile** aplicației: `Logger(subsystem: "ro.polygraph", category: <modul>)`. Categoriile sunt în `App/Log.swift` (`app`, `api`, `onboarding`, `settings`, `scan`, `graph`).
- **Tokenii în cod**: `Animation.pgStandard / pgQuick / pgMove / pgFlick`, `withPgAnimation`, `.pgAnimation(_:value:)` și `PgMotion.transition` (`Design/Motion.swift`); `Spacing`, `Radius`, `ControlHeight`, `PgColor` (inclusiv `PgColor.review`, fundalul câmpurilor „verificați”), `Severity.color / .label` (`Design/Tokens.swift`); `PressableButtonStyle`, `GuardedAction`, `SeniorButton` (`Design/Buttons.swift`). Reduce Motion în view-uri: `@Environment(\.pgReduceMotion)` (sistemul sau `PG_REDUCE_MOTION`).
- **Trecerea de accesibilitate (A6, punctul 5)**: rezultatele se notează aici.
- **Scanarea (A2)**: `PG_FAKE_SCAN` acceptă `sintrom`, `nurofen`, `expired`, `klacid_rx` (sau `fromilid_rx`), `unreadable`; orice alt nume = cutie fără cod. Poza vine din `DebugAssets/<nume>.jpg` dacă există, altfel e textul cutiei randat pe alb (ca OCR-ul de pe simulator să citească ceva). Regula „verificați” e în `Scan/MedDraft.swift` (`reviewFields`): doar cu `needs_review`, plus posologia goală, marcată mereu.
- **Aparținătorul (A3)**: navigarea din toate tab-urile trece prin `CaregiverRoute` (`Caregiver/CaregiverRoutes.swift`), cu destinațiile puse o singură dată pe rădăcina fiecărei stive (`.caregiverDestinations(zoom:)`); doar cardurile din tab-ul Alerte deschid detaliul cu zoom. Ștergerea cu „Anulează” e în `Meds/DeleteUndoQueue.swift` (5 s, apoi DELETE). La „Editează”, o concentrație schimbată de mână devine doza substanței când produsul are una singură; altfel sheet-ul trimite în catalog (`MedDraft.adjustedSubstances` / `strengthNeedsCatalog`). Împărțirea alertelor (grave / moderate / mâncare, fără `minor`) e în `Alerts/AlertSections.swift`. Graful: `Graph/graph.html` + `Graph/cytoscape.min.js` (3.35.0, MIT) din bundle, cu graful din `/analysis` trimis prin `window.pgRender(...)` și așezat de un layout radial determinist (`pgRadialPositions`: medicamentele pe primul inel, ordonate ca perechile care interacționează să fie vecine; substanțele pe raza medicamentului; clasele și alimentele în afară; etichetele claselor doar la zoom); „Recentrează” cheamă `window.pgResetView(animated)`; atingerile vin prin `messageHandlers.alert` (id-ul alertei) și `messageHandlers.med` (id-ul medicamentului). Pagina lui B6 cu `?embed=1` trebuie să trimită aceleași mesaje; după B6 se pune `GraphView.usesSharePage = true`.
