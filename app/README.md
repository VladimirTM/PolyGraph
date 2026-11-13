# app/: aplicația iOS (Dev A)

Proiectul Xcode `PolyGraph.xcodeproj` (SwiftUI, iOS 18+, doar iPhone, portret, fără dependențe externe). Se creează **de om, din Xcode** la P0; agenții doar adaugă fișiere în `app/PolyGraph/`.

**P0, pașii manuali (o dată, ~10 min):**
1. Xcode → File → New → Project → iOS → App. Product Name `PolyGraph`, Organization Identifier `ro.polygraph`, Interface SwiftUI, Language Swift, Testing System: Swift Testing. Salvat în acest folder (`app/`), **fără** „Create Git repository”.
2. Ținta: iOS Deployment Target 18.0, iPhone only, doar Portrait; Build Settings → Swift Language Version 5.
3. Folderul `PolyGraph/` trebuie să fie *synchronized folder* (implicit în Xcode 16+; icon albastru). Așa fișierele noi intră automat în țintă, fără `project.pbxproj` editat de mână.
4. Signing: fiecare își alege Team-ul local (semnarea din `Signing.local.xcconfig`, gitignored, vine la A1).
5. ⌘R pe ambele iPhone-uri (Developer Mode, Trust). Apoi commit pe un branch, cu `xcuserdata` ignorat (e deja în `.gitignore`).

Modelele: `make models` → `PolyGraph/Models/Contracts.swift` (generat, nu se editează). Mock-ul: `make mock` pe Mac, iar în app baseURL = IP-ul Mac-ului, port 8000, token `demo-token` pentru `pat_demo`.
