# Vocabularul fix de simptome (contract)

Singurele coduri pe care le poate produce `POST /checkins` (`CheckIn.symptoms[].code`), fie din potrivirea pe sinonime (calea normală, B5), fie din rezerva Gemini (constrânsă la același enum). `validate.py` citește tabelul de mai jos: codurile sunt unice, în `snake_case`, fiecare are cel puțin 3 sinonime, iar `red_flag` e `da` sau `nu`.

- **Sinonimele** sunt în limbajul unui vârstnic, separate prin `;`, fără diacritice obligatorii (potrivirea normalizează textul). Se pot adăuga oricând (nu schimbă contractul); codurile noi se adaugă doar cu acordul amândurora.
- **`red_flag = da`** → `escalate = true` imediat, indiferent de corelări.
- **Sfatul** e textul de siguranță din `reply_text` (B5, punctul 3): generic, fără „opriți”, fără doze.

| cod | etichetă | sinonime | red_flag | sfat |
|---|---|---|---|---|
| dizziness_orthostatic | amețeală la ridicare | mi se învârte capul când mă ridic; mă ia cu amețeală când mă scol; amețesc când mă ridic din pat; mi se face negru în fața ochilor când mă ridic | nu | Ridicați-vă încet din pat: întâi stați puțin pe marginea patului. |
| dizziness | amețeală | amețeală; mi se învârte capul; sunt amețită; mă clatin | nu | Stați jos până trece și beți puțină apă. |
| bruising | vânătăi | vânătăi; am niște vânătăi; mi s-a învinețit mâna; pete vinete pe piele | nu | Arătați vânătăile medicului la următoarea vizită. |
| bleeding_gums | sângerare la gingii | îmi sângerează gingiile; sânge când mă spăl pe dinți; gingiile sângerează | nu | Spuneți medicului care vă urmărește tratamentul. |
| nosebleed | sângerare din nas | îmi curge sânge din nas; sângerez din nas; mi-a curs sânge pe nas | nu | Stați aplecat ușor în față și apăsați nasul 10 minute. |
| black_stool | scaun negru | scaun negru; scaunul e negru ca smoala; am avut scaun negru | da | Sunați-l acum pe medic sau la 112 dacă vă simțiți slăbită. |
| blood_in_urine | sânge în urină | urina e roșie; sânge în urină; fac pipi cu sânge | da | Sunați-vă medicul astăzi. |
| vomiting_blood | vărsături cu sânge | am vomitat sânge; vărsătură cu sânge; vărsătură ca zațul de cafea | da | Sunați la 112. |
| fall | cădere | am căzut; m-am împiedicat și am căzut; am alunecat și am căzut; am picat jos | da | Dacă v-ați lovit la cap sau vă doare ceva tare, sunați la 112. |
| confusion | confuzie | nu mai știu unde sunt; sunt încurcată; uit tot; mă încurc; nu mai înțeleg ce se întâmplă | da | Rugați pe cineva să rămână cu dumneavoastră și anunțați medicul. |
| drowsiness | somnolență | îmi e somn toată ziua; sunt somnoroasă; adorm pe scaun; sunt moleșită | nu | Nu conduceți și aveți grijă pe scări. |
| insomnia | insomnie | nu pot dormi; nu dorm noaptea; mă trezesc des noaptea; nu am somn | nu | Spuneți medicului la următoarea vizită. |
| muscle_pain | dureri musculare | mă dor mușchii; dureri în mușchi; mă dor picioarele fără motiv; am febră musculară | nu | Spuneți medicului dacă durerea e puternică sau urina e închisă la culoare. |
| muscle_weakness | slăbiciune musculară | nu am putere în picioare; mi-au slăbit mâinile; mă simt fără vlagă în mușchi | nu | Spuneți medicului care v-a dat pastila pentru colesterol. |
| dark_urine | urină închisă la culoare | urina e foarte închisă; fac pipi ca ceaiul negru; urina e maro | da | Sunați-vă medicul astăzi. |
| nausea | greață | mi-e greață; mi-e rău de la stomac; îmi vine să vomit | nu | Mâncați ușor și beți apă în înghițituri mici. |
| vomiting | vărsături | am vomitat; am dat afară; vărs | nu | Beți apă puțin câte puțin; dacă nu trece, sunați medicul. |
| stomach_pain | durere de stomac | mă doare stomacul; mă arde la stomac; am arsuri | nu | Spuneți medicului, mai ales dacă luați pastile pentru durere. |
| diarrhea | diaree | am diaree; merg des la toaletă; scaun moale | nu | Beți multe lichide. |
| constipation | constipație | sunt constipată; nu pot merge la toaletă; nu am scaun de câteva zile | nu | Beți apă și mâncați fructe; spuneți farmacistului. |
| dry_mouth | gură uscată | am gura uscată; mi se usucă gura; mi-e sete tot timpul | nu | Beți des câte puțină apă. |
| palpitations | palpitații | îmi bate inima tare; inima o ia la galop; simt bătăi neregulate; îmi zvâcnește inima | nu | Stați jos și odihniți-vă; dacă nu trece, sunați medicul. |
| chest_pain | durere în piept | mă doare în piept; mă strânge în piept; apăsare pe piept | da | Sunați la 112. |
| shortness_of_breath | lipsă de aer | nu am aer; respir greu; mă sufoc; gâfâi | da | Sunați la 112 dacă e brusc sau puternic. |
| swollen_ankles | glezne umflate | mi s-au umflat gleznele; picioarele umflate; mă strâng pantofii | nu | Țineți picioarele ridicate și spuneți medicului. |
| rash | erupție pe piele | am bubițe pe piele; mă mănâncă pielea; pete roșii pe piele; mâncărime | nu | Arătați pielea farmacistului sau medicului. |
| swelling_face | umflare a feței | mi s-a umflat fața; buzele umflate; limba umflată | da | Sunați la 112. |
| headache | durere de cap | mă doare capul; am dureri de cap; mă apasă capul | nu | Odihniți-vă; întrebați farmacistul înainte să luați ceva pentru durere. |
| tremor | tremur | îmi tremură mâinile; tremur; nu pot ține cana | nu | Spuneți medicului la următoarea vizită. |
| fatigue | oboseală | sunt obosită; nu am putere; sunt fără vlagă; mă simt sleită | nu | Odihniți-vă și spuneți medicului dacă ține mai multe zile. |
| low_mood | tristețe | sunt tristă; nu am chef de nimic; plâng des | nu | Vorbiți cu cineva drag sau cu medicul de familie. |
| urinary_retention | greutate la urinat | nu pot face pipi; urinez greu; abia urinez | da | Sunați-vă medicul astăzi. |
