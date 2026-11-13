# Reguli pentru agenții de cod (PolyGraph)

Citește întâi [`CONTRIBUTING.md`](CONTRIBUTING.md) și tot folderul `contracts/` (sursa de adevăr; nu-l modifica decât dacă task-ul o cere explicit). Planul, cu prompturile fiecărei etape, e în [`docs/PLAN.md`](docs/PLAN.md).

- **UI:** pentru orice modificare de UI (`app/` sau paginile din `backend/polygraph/share/`), citește întâi `.claude/skills/apple-design/SKILL.md` și `docs/DESIGN.md`. Componenta de sistem care face deja ce cere skill-ul are prioritate față de cod propriu; abaterile pentru vârstnici din `docs/DESIGN.md` (2.4.2) au prioritate față de skill. Nu scrie animații proprii unde există o componentă de sistem.
- **iOS:** SwiftUI, iOS 18+, Swift language mode 5, **fără dependențe externe (nici SPM)**. Nu crea și nu edita niciodată `project.pbxproj`: proiectul folosește foldere sincronizate, deci fișierele noi din `app/PolyGraph/` intră singure în țintă. Dacă e nevoie de o setare de proiect, spune-i omului ce să schimbe din Xcode.
- **Bucla de verificare:** după fiecare modificare rulează `xcodebuild build` (sau `make check-ios`) și, pentru Python, `make check`; repară singur erorile. Nu preda niciodată cod care nu compilează. La o eroare repetată de două ori, schimbă abordarea (o componentă de sistem mai simplă), nu insista.
- **Modelele Swift** se generează cu `make models` din `contracts/schema/`; nu le edita de mână.
- **Siguranța conținutului:** niciun text nu spune „opriți”, „nu mai luați” sau o doză nouă; fiecare alertă are sursa; în modul senior, fără roșu și fără jargon.
- **Git:** branch nou din `main` actualizat (numele e în promptul etapei), commit-uri mici în engleză la imperativ, cu `Co-authored-by` pentru celălalt membru și **fără co-author sau mențiuni AI**. La final: `make check`, push, `gh pr create --base main`.
- **Comentarii** doar unde explică de ce.
