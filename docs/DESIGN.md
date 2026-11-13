# Designul PolyGraph: skill-ul `apple-design`, aplicat în SwiftUI

> Extras din `docs/PLAN.md`, secțiunea 2.4 (numerotarea e păstrată, ca trimiterile din prompturi să funcționeze). Dacă se schimbă ceva, se schimbă în ambele locuri.


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

## 2.4.1 Cele opt principii, aplicate la PolyGraph

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

## 2.4.2 Deciziile specifice pentru vârstnici (unde ne abatem conștient de skill)

- **Fără acțiuni doar prin gest în modul senior.** Tremorul face swipe-urile și long-press-urile nesigure: totul e buton mare (≥ 72 pt înălțime, pe toată lățimea). Gesturile (swipe-to-delete, sheet-uri glisabile) există doar în modul aparținător.
- **Feedback instant, commit protejat.** Butonul se micșorează imediat la atingere (§1); acțiunea pornește la ridicarea degetului, iar a doua apăsare pe aceeași doză în următoarea secundă e ignorată (și backend-ul e idempotent pe doză).
- **Microfonul: atingere ca să pornească, atingere sau liniște ca să se oprească**, nu „țineți apăsat”. Oprire automată după 2 s de liniște sau 60 s.
- **Suprafețe opace în modul senior.** Materialele translucide rămân doar în chrome-ul de sistem al modului aparținător.
- **Fără roșu de alarmă pentru pacient.** Alertele grave se văd la Ana și la farmacist; Maria vede un card liniștit cu „Am anunțat-o pe Ana”.

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
  | Acum (senior) | `now.clock`, `now.nextMomentCard`, `now.dayButton` |
  | Ziua de azi | `day.moment.<HH:MM>` |
  | tab-uri (aparținător) | conținutul: `tab.meds`, `tab.alerts`, `tab.graph`, `tab.feed`; butoanele din tab bar se caută după etichetă („Medicamente”, „Alerte”, „Graf”, „Noutăți”), SwiftUI nu le poate da identificator |
  | Medicamente | `meds.list`, `meds.row.<med_id>`, `meds.loading`, `meds.empty`, `meds.error`, `meds.retryButton` |
  | Alerte / Graf / Noutăți (placeholder) | `alerts.placeholder`, `graph.placeholder`, `feed.placeholder` |
  | Setări | `settings.openButton` (rotița din bara de navigare), `settings.baseURLField`, `settings.checkConnectionButton`, `settings.connectionStatus`, `settings.rolePicker`, `settings.demoModeToggle`, `settings.useDemoPatientButton`, `settings.signOutButton`, `settings.confirmSignOutButton`, `settings.doneButton` |
- **Logurile** aplicației: `Logger(subsystem: "ro.polygraph", category: <modul>)`. Categoriile sunt în `App/Log.swift` (`app`, `api`, `onboarding`, `settings`).
- **Tokenii în cod**: `Animation.pgStandard / pgQuick / pgMove / pgFlick`, `withPgAnimation`, `.pgAnimation(_:value:)` și `PgMotion.transition` (`Design/Motion.swift`); `Spacing`, `Radius`, `ControlHeight`, `PgColor`, `Severity.color / .label` (`Design/Tokens.swift`); `PressableButtonStyle`, `GuardedAction`, `SeniorButton` (`Design/Buttons.swift`). Reduce Motion în view-uri: `@Environment(\.pgReduceMotion)` (sistemul sau `PG_REDUCE_MOTION`).
- **Trecerea de accesibilitate (A6, punctul 5)**: rezultatele se notează aici.
