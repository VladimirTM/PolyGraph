# demo/: materialele demo (Dev B)

Pozele cutiilor (`photos/`, `datamatrix/`, `extra/`), rețeta (`rx/`), transcrierile reale (`transcripts/`), textele OCR salvate din app (`ocr/`, A2), cache-ul LLM (`llm_cache/`, B3). Lista de făcut: `CHECKLIST_materiale.md`.

## Demo B3 fără medicamente fizice

Rulează `make demo-b3` din rădăcina proiectului. Comanda folosește catalogul construit cu `make kb`. La prima rulare, `uv` descarcă pachetele care lipsesc. După instalare, scenariul rulează offline.

1. Sintrom este identificat din text OCR simulat, cu litere confundate. Backend-ul citește GTIN-ul dintr-un DataMatrix sintetic generat ca JPEG.
2. După confirmare, aceeași imagine găsește produsul prin cache, fără text OCR.
3. Scanarea și confirmarea Nurofen afișează alerta majoră pentru perechea Sintrom–Nurofen.
4. Rețeta fictivă Fromilid produce posologia `1-0-1`, iar confirmarea afișează alerta critică pentru perechea Fromilid–simvastatină.
5. Un text necunoscut afișează mesajul de completare manuală.

Scenariul apelează rutele FastAPI reale, cu o bază de date în memorie și cheia Gemini dezactivată. Intrările sunt sintetice. Validarea OCR-ului pe iPhone rămâne în T-B3-02.

## Demo pe scenă (B7)

`make demo` pornește backend-ul pentru telefoane și afișează adresa de pus în setările aplicației. `make demo-check` rulează scenariul din `docs/PLAN.md` §7 prin API (`URL=…` pentru serverul pornit). Fotografiile din listă se iau din `photos/med_01.jpg` … `med_08.jpg` (sau `.png`); până atunci aplicația arată o imagine neutră.
