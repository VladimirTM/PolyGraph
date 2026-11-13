# PolyGraph: lista materialelor demo (cutii, poze, rețetă)

Se face înainte de hackathon, doar cu telefonul și imprimanta: fără cod. Fișierele merg în `demo/` din repo.

## 1. Cutiile

| # | Medicament | Doza ideală | Rol în demo | Prioritate | Am cutia | EXP în viitor? |
|---|---|---|---|---|---|---|
| 01 | **Sintrom** | 4 mg | scanat **live**; alerta principală (cu Nurofen) | **obligatoriu** | ☐ | ☐ |
| 02 | **Nurofen** (Forte / Ultra / Immedia) | 400 mg | scanat **live** | **obligatoriu** | ☐ | ☐ |
| 03 | Simvastatină (orice producător) | **40 mg** | poză în „Acum”; alertă cu amlodipină | foarte bine | ☐ | ☐ |
| 04 | Amlodipină (orice producător) | **10 mg** | poză în „Acum” | foarte bine | ☐ | ☐ |
| 05 | **Euthyrox** | 75 mcg | poză în „Acum”; programul (separat de calciu) | foarte bine | ☐ | ☐ |
| 06 | Calciu + D3 | orice | poză; completat în `kb/ro_products_extra.csv` | dacă se găsește | ☐ | ☐ |
| 07 | Omeprazol | 20 mg | poză | dacă se găsește | ☐ | ☐ |
| 08 | Amitriptilină | 25 mg | poză; alerta Beers și ACB | dacă se găsește | ☐ | ☐ |
| 09 | Fromilid (sau altă claritromicină) | 500 mg | **nu** se scanează cutia: se scanează rețeta | opțional (poza) | ☐ | ☐ |

**Dozele care contează.** Simvastatină 40 mg și amlodipină 10 mg dau alerta „simvastatină peste limita de 20 mg cu amlodipină”. Cu simvastatină 20 mg alerta dispare. Dacă nu ai 40 mg, spune-mi ce doză ai și ajustăm `expected_alerts.json`.

**Cutii expirate.** O cutie veche cu EXP depășit va produce alerta „expirat” în demo. Alege pentru cele două cutii scanate live (01, 02) ambalaje cu EXP în viitor. La celelalte nu contează, pentru că ele vin din fixture.

**DataMatrix.** Ambalajele din 2019 încoace îl au. O cutie mai veche poate să nu-l aibă: pe ea demo-ul merge doar cu poza.

## 2. Pozele (cu iPhone-ul, 1–2 minute pe cutie)

**Fața cutiei:** cutia pe o masă plată, lumină de zi sau difuză, fără reflexii pe fața lucioasă, telefonul paralel cu cutia, tot textul citibil.
**Codul DataMatrix:** o poză apropiată, focalizată, cu tot codul în cadru. Dacă lângă cod sunt tipărite `PC`, `SN`, `LOT`, `EXP`, fotografiază-le și pe ele și notează-le mai jos.

Nume de fișier (în `demo/photos/` și `demo/datamatrix/`):

```
demo/photos/01_sintrom_fata.jpg        demo/datamatrix/01_sintrom_cod.jpg
demo/photos/02_nurofen_fata.jpg        demo/datamatrix/02_nurofen_cod.jpg
demo/photos/03_simvastatina_fata.jpg   ...
```

Datele de pe cutiile scanate live (completezi de pe cutie; GTIN/PC = șirul de cifre lângă „PC”):

| Cutia | PC / GTIN | SN | LOT | EXP |
|---|---|---|---|---|
| 01 Sintrom | | | | |
| 02 Nurofen | | | | |

## 3. Rețeta

- Fișier: `reteta_demo_fromilid.pdf` (Fromilid 500 mg, 1-0-1, 7 zile; medic și pacient fictive; marcată „document fictiv”).
- Tipărire: A4, scala 100%, alb-negru e ok, hârtie albă, fără „fit to page” care micșorează textul.
- Pentru A2, fotografiază-o din aplicație cu **Rețetă** (VNDocumentCamera): pe masă, lumină bună, foaia întreagă în cadru. Fă 2–3 variante (dreaptă, ușor înclinată, cu umbră) pentru testele de OCR.

## 4. Dacă folosiți alte medicamente („random”)

- **Pentru testele de OCR și de scanare** merge orice cutie românească: mai multe cutii diferite înseamnă mai multe teste. Pune-le în `demo/extra/` (față + cod). Cutiile cu text mic, lucioase sau curbate sunt cele mai utile la A2 și B3.
- **Pentru scenariul demo** înlocuiți un medicament doar cu unul care nu schimbă alertele principale. Cele care **trebuie păstrate**: Sintrom + Nurofen (sângerare), simvastatină 40 mg + amlodipină 10 mg, Euthyrox + calciu (orar) și, în rețetă, claritromicina (alerta critică cu simvastatina).
- **Înlocuibile fără probleme:** omeprazol, amitriptilină (schimbă doar alertele Beers / ACB și câteva moderate) și pozele pentru restul.
- Orice schimbare: trimite-mi lista cutiilor pe care le ai și recalculez alertele așteptate din datele DDInter, înainte să atingem fixture-urile.
