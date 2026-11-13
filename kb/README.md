# kb/: baza de cunoștințe (Dev B)

Reguli scrise de mână (`rules/*.yaml`), interacțiuni verificate (`curated_ddi.csv`, `curated_dfi.csv`), OTC-urile lipsă din catalog (`ro_products_extra.csv`). Datele brute (DDInter, catalogul MS) stau în `kb/raw/` și **nu** intră în git (doar README-urile lor); fiecare le are local. `make kb` (B1) construiește `kb/kb.sqlite`.
