"""Etichetele românești ale claselor ATC nivel 4 afișate în graf (kb nu are denumirile ATC).

Lista acoperă pacientul demo și clasele uzuale la vârstnici; o clasă lipsă apare cu codul ei.
"""

ATC4_RO = {
    "A02BC": "inhibitori de pompă de protoni",
    "A02BA": "antagoniști H2",
    "A10BA": "biguanide",
    "A10BB": "sulfoniluree",
    "A11CC": "vitamina D",
    "A12AA": "calciu",
    "A12AX": "calciu în combinații",
    "B01AA": "antagoniști ai vitaminei K",
    "B01AC": "antiagregante plachetare",
    "B01AF": "inhibitori direcți ai factorului Xa",
    "C01AA": "glicozide digitalice",
    "C03CA": "diuretice de ansă",
    "C07AB": "beta-blocante selective",
    "C08CA": "blocante ale canalelor de calciu",
    "C09AA": "inhibitori ai enzimei de conversie",
    "C09CA": "sartani",
    "C10AA": "statine",
    "H03AA": "hormoni tiroidieni",
    "J01FA": "macrolide",
    "J01MA": "fluorochinolone",
    "M01AE": "antiinflamatoare (derivați de acid propionic)",
    "M01AB": "antiinflamatoare (derivați de acid acetic)",
    "M01AH": "coxibi",
    "N02BB": "pirazolone (metamizol)",
    "N02BE": "anilide (paracetamol)",
    "N05BA": "benzodiazepine (anxiolitice)",
    "N05CD": "benzodiazepine (somnifere)",
    "N05CF": "somnifere de tip Z",
    "N06AA": "antidepresive triciclice",
    "N06AB": "inhibitori selectivi ai recaptării serotoninei",
}


def atc4_label(atc4: str) -> str:
    return ATC4_RO.get(atc4, atc4)
