"""Utilitare comune pentru construirea kb/kb.sqlite (B1)."""

from __future__ import annotations

import re
import unicodedata
from pathlib import Path

KB_DIR = Path(__file__).resolve().parent
ROOT = KB_DIR.parent
RAW_DIR = KB_DIR / "raw"
RULES_DIR = KB_DIR / "rules"
DB_PATH = KB_DIR / "kb.sqlite"
BRANDS_PATH = ROOT / "app" / "PolyGraph" / "Resources" / "brands.txt"
SYMPTOMS_PATH = ROOT / "contracts" / "symptoms.md"


def strip_accents(text: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFKD", text) if not unicodedata.combining(c))


def norm(text: str | None) -> str:
    """Litere mici, fără diacritice, doar litere / cifre / spații."""
    if not text:
        return ""
    text = strip_accents(text).lower().replace("µ", "u")
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def norm_dci(text: str) -> str:
    """Cheia unei componente DCI din catalog: majuscule, fără diacritice, spații simple."""
    text = strip_accents(text).upper()
    text = re.sub(r"\s+", " ", text)
    return text.strip(" .,;")


# Cuvintele care denumesc sarea sau hidratarea, nu substanța activă. Se încearcă întâi
# potrivirea pe numele complet (ex. „calcii carbonas” e chiar substanța), apoi fără ele.
SALT_WORDS = {
    "natrium",
    "natricum",
    "dinatrium",
    "dinatricum",
    "kalium",
    "kalicum",
    "calcicum",
    "magnesicum",
    "hydrochloridum",
    "hydrochloricum",
    "dihydrochloridum",
    "hydrobromidum",
    "hydrochlorid",
    "mesilas",
    "besilas",
    "besylas",
    "maleas",
    "hydrogenomaleas",
    "fumaras",
    "hemifumaras",
    "succinas",
    "tartras",
    "hydrogenotartras",
    "bitartras",
    "citras",
    "sulfas",
    "hydrogenosulfas",
    "acetas",
    "phosphas",
    "dihydrogenophosphas",
    "propionas",
    "dipropionas",
    "valeras",
    "butyras",
    "furoas",
    "nitras",
    "lactas",
    "gluconas",
    "tosilas",
    "embonas",
    "pivalas",
    "hyclas",
    "monohydricum",
    "dihydricum",
    "trihydricum",
    "anhydricum",
    "hemihydricum",
    "sesquihydricum",
    "monohydrat",
    "axetil",
    "medoxomilum",
    "medoxomil",
    "cilexetil",
    "decanoas",
    "enantas",
    "palmitas",
    "stearas",
    "bromidum",
    "erbuminum",
    "arginine",
    "argininum",
    "trometamolum",
    "sodium",
    "potassium",
    "hydrochloride",
    "magnesium",
    "calcium",
    "succinate",
    "propionat",
    "propionate",
    "fumarate",
    "maleate",
    "mesylate",
    "besylate",
    "tartrate",
    "citrate",
    "sulfate",
    "acetate",
    "tromethamin",
    "trometamol",
    "tromethamine",
    "etexilatum",
    "etexilate",
    "disoproxil",
    "dihydrate",
    "monohydrate",
}

# Denumirile INN europene → cele din DDInter (americane). Folosite la legare și la regulile pe INN.
INN_ALIASES = {
    "paracetamol": "acetaminophen",
    "glibenclamide": "glyburide",
    "chlorphenamine": "chlorpheniramine",
    "dicycloverine": "dicyclomine",
    "clorazepate": "clorazepic acid",
    "meclozine": "meclizine",
    "thioctic acid": "lipoic acid",
    "ibandronic acid": "ibandronate",
    "beclometasone": "beclomethasone dipropionate",
    "salbutamol": "albuterol",
    "adrenaline": "epinephrine",
    "noradrenaline": "norepinephrine",
    "pethidine": "meperidine",
    "colecalciferol": "cholecalciferol",
    "ciclosporin": "cyclosporine",
    "rifampicin": "rifampin",
    "aciclovir": "acyclovir",
    "valaciclovir": "valacyclovir",
    "hyoscine": "scopolamine",
    "isoprenaline": "isoproterenol",
    "dosulepin": "dothiepin",
    "mesalazine": "mesalamine",
    "amfetamine": "amphetamine",
    "cefalexin": "cephalexin",
    "levomepromazine": "methotrimeprazine",
    "glyceryl trinitrate": "nitroglycerin",
    "nitroglycerinum": "nitroglycerin",
    "ergocalciferol": "ergocalciferol",
    "metamizole": "metamizole",
    "bendroflumethiazide": "bendroflumethiazide",
    "lignocaine": "lidocaine",
    "acetylcysteine": "acetylcysteine",
    "dexketoprofen": "dexketoprofen",
    "fluticasone propionate": "fluticasone",
}

SPECIAL_WORDS = {
    "natrii": "sodium",
    "natrium": "sodium",
    "kalii": "potassium",
    "kalium": "potassium",
    "ferrosi": "ferrous",
    "ferri": "ferric",
    "aluminii": "aluminium",
    "argenti": "silver",
    "hct": "hydrochlorothiazide",
    "zinci": "zinc",
}

SUFFIXES = [
    ("inum", "ine"),
    ("onum", "one"),
    ("olum", "ol"),
    ("icum", "ic"),
    ("idum", "ide"),
    ("atum", "ate"),
    ("ium", "ium"),
    ("um", ""),
    ("ii", "ium"),
    ("as", "ate"),
]


def _latin_word(word: str) -> str:
    if word in SPECIAL_WORDS:
        return SPECIAL_WORDS[word]
    for suffix, repl in SUFFIXES:
        if word.endswith(suffix) and len(word) > len(suffix) + 2:
            return word[: -len(suffix)] + repl
    return word


def latin_to_english(words: list[str]) -> str:
    """Stem-ul englezesc al unei DCI latine: „acidum alendronicum” → „alendronic acid”."""
    acid = "acidum" in words or "acid" in words
    words = [w for w in words if w not in ("acidum", "acid")]
    out = [_latin_word(w) for w in words]
    if acid:
        out.append("acid")
    return " ".join(out)


def latin_variants(dci_component: str) -> list[str]:
    """Variantele englezești de încercat, în ordinea preferinței."""
    words = norm(re.sub(r"\(.*?\)", " ", dci_component)).split()
    if not words:
        return []
    variants = [latin_to_english(words)]
    stripped = [w for w in words if w not in SALT_WORDS]
    if stripped and stripped != words:
        variants.append(latin_to_english(stripped))
    variants.append(" ".join(words))  # denumiri deja românești / englezești (ex. „ETINILESTRADIOL”)
    for v in list(variants):
        if v in INN_ALIASES:
            variants.append(INN_ALIASES[v])
        if v.endswith("ic acid"):  # „ibandronic acid” ↔ „ibandronate”
            variants.append(v[: -len("ic acid")] + "ate")
    seen: list[str] = []
    for v in variants:
        if v and v not in seen:
            seen.append(v)
    return seen


def skeleton(text: str) -> str:
    """Forma „scheletică” a unui nume, ca ortografiile latină / română / engleză să coincidă."""
    out = []
    for w in norm(text).split():
        for a, b in (("ch", "k"), ("ph", "f"), ("th", "t"), ("rh", "r"), ("ae", "e"), ("y", "i"), ("c", "k"), ("x", "ks")):
            w = w.replace(a, b)
        w = w.rstrip("ae") or w
        out.append(w)
    return " ".join(out)


def split_dci(dci_raw: str | None) -> list[str]:
    """Despică DCI-ul compus: „COMBINATII (A+B)” / „A + B” → [A, B]. „COMBINATII” fără listă → []."""
    if not dci_raw:
        return []
    text = norm_dci(dci_raw)
    m = re.match(r"^COMBINATII\s*\((.*)\)\s*$", text)
    if m:
        text = m.group(1)
    elif text.startswith("COMBINATII"):
        return []
    parts = [norm_dci(p) for p in text.split("+")]
    return [p for p in parts if p and p != "COMBINATII"]


FORM_WORDS = {
    "solutie",
    "injectabila",
    "perfuzabila",
    "comprimate",
    "comprimat",
    "filmate",
    "capsule",
    "sirop",
    "crema",
    "unguent",
    "picaturi",
    "suspensie",
    "pulbere",
    "granule",
    "plicuri",
    "spray",
    "gel",
}


def brand_norm(name: str | None) -> str:
    """Brandul normalizat: litere mici, fără diacritice, fără concentrație, formă și paranteze."""
    if not name:
        return ""
    text = re.sub(r"\(.*?\)", " ", name)
    text = strip_accents(text).lower()
    # concentrația începe la primul număr („25 mg”, „0,5mg/ml”, „10%”)
    text = re.split(r"\s\d", " " + text, maxsplit=1)[0]
    words = [w for w in re.sub(r"[^a-z0-9+/&\-\s]", " ", text).split() if w not in FORM_WORDS]
    return " ".join(words).strip(" -/+")
