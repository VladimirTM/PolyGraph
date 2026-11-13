# DDInter 2.0: fișierele descărcate (12.11.2026)

Sursa: https://ddinter2.scbdd.com/download/ · Licența datelor descărcabile: CC BY-NC-SA 4.0 (doar uz necomercial).

- 8 fișiere, câte unul pe grupa ATC: A, B, D, H, L, P, R, V (fiecare conține interacțiunile care implică un medicament din grupa respectivă; perechile se repetă între fișiere).
- Coloane: `DDInterID_A, Drug_A, DDInterID_B, Drug_B, Level` (numele în engleză). **Fără mecanism și fără recomandări**: textele se iau de pe site, doar pentru perechile folosite.
- 222.383 de rânduri, 160.235 de perechi unice, 1.939 de substanțe. Nivelurile: Moderate 130.367, Unknown 47.182, Major 33.896, Minor 10.938.
- **Acenocumarolul (Sintrom) are toate cele 116 interacțiuni cu nivelul `Unknown`.** Warfarina, din aceeași clasă (B01AA), are niveluri (ex. warfarină + ibuprofen = Major).
- Interacțiunile cu alimentele și dublurile terapeutice nu sunt în fișierele descărcabile; se completează de mână în `kb/curated_dfi.csv`.
- Rezultatul pe perechile din scenariul demo: `demo_pairs_report.csv`.
