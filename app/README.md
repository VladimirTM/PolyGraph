# app/: aplicația iOS (Dev A)

Proiectul Xcode `PolyGraph.xcodeproj` (SwiftUI, iOS 18+, doar iPhone, portret, fără dependențe externe). Se creează **de om, din Xcode** la P0; agenții doar adaugă fișiere în `app/PolyGraph/`.

**P0, pașii manuali (o dată, ~10 min):**
1. Xcode → File → New → Project → iOS → App. Product Name `PolyGraph`, Organization Identifier `ro.polygraph`, Interface SwiftUI, Language Swift, Testing System: Swift Testing. Salvat în acest folder (`app/`), **fără** „Create Git repository”.
2. Ținta: iOS Deployment Target 18.0, iPhone only, doar Portrait; Build Settings → Swift Language Version 5.
3. Folderul `PolyGraph/` trebuie să fie *synchronized folder* (implicit în Xcode 16+; icon albastru). Așa fișierele noi intră automat în țintă, fără `project.pbxproj` editat de mână.
4. Signing: fiecare își alege Team-ul local (semnarea din `Signing.local.xcconfig`, gitignored, vine la A1).
5. ⌘R pe ambele iPhone-uri (Developer Mode, Trust). Apoi commit pe un branch, cu `xcuserdata` ignorat (e deja în `.gitignore`).

Modelele: `make models` → `PolyGraph/Models/Contracts.swift` (generat, nu se editează). Mock-ul: `make mock` pe Mac, iar în app baseURL = IP-ul Mac-ului, port 8000, token `demo-token` pentru `pat_demo`.

**A1, pașii manuali din Xcode (o dată, ~3 min; agenții nu ating `project.pbxproj`):**
1. `cp app/Signing.local.xcconfig.example app/Signing.local.xcconfig` și completați Team ID-ul și sufixul (Vladimir îl are deja creat local).
2. Project `PolyGraph` → Info → Configurations: la **Debug** și **Release**, pe rândul țintei `PolyGraph`, alegeți `PolyGraph` (fișierul `PolyGraph.xcconfig`).
3. Ținta `PolyGraph` → Build Settings → căutați și **ștergeți** (selectați rândul, tasta Delete) valorile scrise direct în țintă pentru `Development Team` și `Product Bundle Identifier`, ca să vină din xcconfig (rândul trebuie să nu mai fie bold).
4. Ținta `PolyGraph` → General → Minimum Deployments: **iOS 18.0** (acum e 18.6). Ținta `PolyGraphTests` → **18.0** (acum e 27.2, deci testele nu rulează pe simulatoare mai vechi) și Supported Destinations doar iPhone.
5. ⌘B, apoi ⌘U (sau `make check-ios`). Info.plist-ul primește cheile din `Config/Info.plist` (camera, microfonul, vorbirea, rețeaua locală, ATS pentru serverul din LAN).

Structura `PolyGraph/`: `App/` (pornire, `AppStore`, setări, `DebugEnvironment`, ceasul), `Design/` (tokeni, butoane, formatări), `Models/` (`Contracts.swift` generat + extensii), `API/` (clientul), `Onboarding/`, `Senior/`, `Caregiver/`, `Meds/`, `Alerts/`, `Graph/`, `Settings/`. `Scan/`, `Voice/`, `Share/` și `DebugAssets/` apar la etapele care le umplu (A2, A5, A6).

**Turul pe simulator (Q0):** în schema de Debug, variabilele `PG_*` din plan (tabelul Q0) pornesc aplicația direct în modul cerut, de ex. `PG_SKIP_ONBOARDING=1 PG_ROLE=caregiver PG_BASE_URL=http://127.0.0.1:8000`.
