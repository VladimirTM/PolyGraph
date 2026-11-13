"""Înțelegerea unui check-in deja transcris pe telefon (B5): text → intent, simptome codificate, medicamentul întrebat.

Calea principală e deterministă: sinonimele din contracts/symptoms.md, potrivite fuzzy (rapidfuzz) pe n-grame din
textul normalizat (litere mici, fără diacritice, pentru că dictarea le poate pierde). Gemini intervine doar ca rezervă,
când nu s-a găsit niciun simptom și textul are mai mult de 5 cuvinte, cu răspunsul constrâns la enum-ul de coduri;
un răspuns cu un cod din afara vocabularului e respins întreg.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from dataclasses import dataclass, field
from functools import cache
from pathlib import Path
from typing import Any
from urllib.request import Request, urlopen

from dotenv import dotenv_values
from rapidfuzz import fuzz

from polygraph.deadline import within
from polygraph.kb import ROOT, Kb, norm

sys.path.insert(0, str(ROOT / "contracts"))
import validate as contracts  # noqa: E402  (contracts/validate.py citește tabelul din symptoms.md)

Json = dict[str, Any]

THRESHOLD = 85
SHORT = 5  # sinonimele de cel mult atâtea litere („vars”, „tremur”) se potrivesc doar exact
LLM_MIN_WORDS = 5
LLM_TIMEOUT = 5
CACHE = ROOT / "demo" / "llm_cache"

INTENSE = {"foarte", "tare", "rau", "groaznic", "ingrozitor", "insuportabil", "puternic", "puternica", "mult"}
MILD = {"putin", "usor", "pic", "uneori", "cateodata"}
STANDING = re.compile(r"\b(ridic\w*|scol\w*|in picioare)\b")

CAN_I_TAKE = re.compile(r"\b(pot|putem|am voie|e voie|e bine|ar fi bine)\s+(sa\s+)?(iau|ia|lua|beau|bea)\b")
WHICH_PILL = re.compile(
    r"\b(ce|care)\s+(pastila|pastile|pastilele|medicament|medicamente|medicamentul)\b"
    r"|\bce\s+(trebuie\s+sa\s+)?iau\s+(acum|azi|astazi|acuma)\b"
)

# Cuvinte uzuale care seamănă cu nume comerciale: singure nu se potrivesc pe tot catalogul.
COMMON_WORDS = {
    "sindrom",
    "calciu",
    "fier",
    "magneziu",
    "vitamina",
    "vitamine",
    "ceai",
    "apa",
    "lapte",
    "cafea",
    "sirop",
    "pastila",
    "pastile",
    "medicament",
    "medicamentul",
    "ceva",
    "doctor",
    "doctorul",
    "seara",
    "dimineata",
    "acum",
    "azi",
    "astazi",
    "pentru",
    "durere",
    "dureri",
    "capul",
    "stomac",
    "inima",
    "somn",
    "ulei",
    "miere",
    "lamaie",
    "suc",
    "vin",
    "bere",
}


@dataclass
class Symptom:
    code: str
    label: str
    severity: str
    red_flag: bool
    advice: str


@dataclass
class Understanding:
    intent: str
    symptoms: list[Symptom] = field(default_factory=list)
    drug_query: Json | None = None  # {text, source: patient | catalog, brand, med_id}
    used_llm: bool = False


@cache
def vocabulary() -> dict[str, Json]:
    codes, errors = contracts.symptom_codes()
    if errors:
        raise RuntimeError("contracts/symptoms.md: " + "; ".join(errors))
    return codes


@cache
def _synonyms() -> tuple[tuple[str, tuple[str, ...]], ...]:
    return tuple((code, tuple(norm(s) for s in v["synonyms"])) for code, v in vocabulary().items())


def _sentences(text: str) -> list[list[str]]:
    return [toks for part in re.split(r"[.!?;\n]+", text) if (toks := norm(part).split())]


def _negated(tokens: list[str], start: int, end: int, synonym: str) -> bool:
    if synonym.split()[0] == "nu":
        return False
    return "nu" in tokens[max(0, start - 1) : end]


CLAUSE_BREAK = {"si", "dar", "iar", "apoi"}


def _severity(tokens: list[str], start: int, end: int) -> str:
    """Intensitatea din cuvintele din jur, în aceeași propoziție coordonată („tare” din „inima tare și respir greu”)."""
    left = tokens[max(0, start - 3) : start]
    while any(t in CLAUSE_BREAK for t in left):
        left = left[1:]
    right = []
    for t in tokens[end : end + 3]:
        if t in CLAUSE_BREAK:
            break
        right.append(t)
    around = set(left) | set(right)
    if around & INTENSE:
        return "severe"
    if around & MILD:
        return "mild"
    return "moderate"


def find_symptoms(text: str) -> list[Symptom]:
    """Simptomele din text, în ordinea în care apar. Determinist, fără rețea."""
    vocab = vocabulary()
    found: list[tuple[int, int, str]] = []  # (propoziție, poziție, cod), pentru ordinea din text
    seen: set[str] = set()
    out: dict[str, Symptom] = {}
    for si, tokens in enumerate(_sentences(text)):
        hits: list[tuple[int, int, int, int, str]] = []  # (lungime, scor, start, end, cod)
        for code, syns in _synonyms():
            for syn in syns:
                k = len(syn.split())
                for w in (k, k + 1):
                    for i in range(0, len(tokens) - w + 1):
                        window = " ".join(tokens[i : i + w])
                        if len(syn) <= SHORT:
                            score = 100 if syn in window.split() or syn == window else 0
                        else:
                            score = int(fuzz.ratio(syn, window))
                        if score >= THRESHOLD and not _negated(tokens, i, i + w, syn):
                            hits.append((k, score, i, i + w, code))
        # Un fragment aparține unui singur simptom: câștigă sinonimul cel mai lung („am vomitat sânge” > „am vomitat”).
        taken: list[tuple[int, int, str]] = []
        for _, _, start, end, code in sorted(hits, key=lambda h: (-h[0], -h[1], h[2])):
            if any(start < e and s < end and c != code for s, e, c in taken):
                continue
            taken.append((start, end, code))
        sentence = " ".join(tokens)
        for start, end, code in sorted(taken, key=lambda t: t[0]):
            if code == "dizziness" and STANDING.search(sentence):
                code = "dizziness_orthostatic"  # amețeala spusă lângă „când mă ridic”, în aceeași propoziție
            if code in seen:
                continue
            seen.add(code)
            v = vocab[code]
            out[code] = Symptom(code, v["label"], _severity(tokens, start, end), v["red_flag"], v["advice"])
            found.append((si, start, code))
    if "dizziness_orthostatic" in out:
        out.pop("dizziness", None)
    return [out[c] for _, _, c in sorted(found) if c in out]


def detect_intent(text: str, has_symptoms: bool) -> str:
    t = norm(text)
    if CAN_I_TAKE.search(t):
        return "can_i_take"
    if WHICH_PILL.search(t):
        return "which_pill_now"
    return "symptom_report" if has_symptoms else "other"


# ---------------------------------------------------------------- medicamentul despre care se întreabă


def phonetic(word: str) -> str:
    """Schelet de consoane cu sunetele apropiate contopite: „sindrom” și „Sintrom” dau aceeași cheie."""
    w = norm(word).replace(" ", "")
    if not w:
        return ""
    w = w.replace("x", "cs").replace("ph", "f").replace("th", "t").replace("y", "i")
    table = str.maketrans({"d": "t", "b": "p", "g": "k", "c": "k", "q": "k", "v": "f", "w": "f", "z": "s", "h": None})
    head, rest = w[0].translate(table) or w[0], w[1:].translate(table)
    rest = re.sub(r"[aeiou]", "", rest)
    return re.sub(r"(.)\1+", r"\1", head + rest)


def _med_names(med: Json) -> list[str]:
    names = []
    brand = norm((med.get("product") or {}).get("brand"))
    if brand:
        names.append(brand.split()[0])
    for s in med.get("substances") or []:
        for n in (s.get("inn"), s.get("dci")):
            n = norm(n)
            if n:
                names.append(n.split()[0])
    return [n for n in names if len(n) >= 4]


def _patient_match(tok: str, meds: list[Json]) -> tuple[int, Json] | None:
    best: tuple[int, Json] | None = None
    for med in meds:
        for name in _med_names(med):
            score = int(fuzz.ratio(tok, name))
            if phonetic(tok) == phonetic(name):
                score = max(score, 90)  # dictarea scrie „sindrom” pentru Sintrom
            if score >= 80 and (best is None or score > best[0]):
                brand = (med.get("product") or {}).get("brand")
                best = (score, {"text": tok, "source": "patient", "brand": brand, "med_id": med["id"]})
    return best


def _catalog_match(tok: str, kb: Kb) -> Json | None:
    if tok in COMMON_WORDS or tok in _symptom_words():
        return None
    for hit in kb.search(tok, limit=5):
        names = {norm(hit["brand"]).split()[0]} | {
            norm(x).split()[0] for sub in hit["substances"] for x in (sub["inn"], sub["dci"]) if norm(x)
        }
        if tok in names:
            return {"text": tok, "source": "catalog", "brand": tok.capitalize(), "med_id": None}
    return None


def match_drug(text: str, meds: list[Json], kb: Kb | None = None) -> Json | None:
    """Medicamentul întrebat: cuvintele de după „pot să iau” (sau tot textul, fără întrebare), întâi în lista
    pacientului (prag permisiv + fonetic), apoi în catalog (strict, doar potrivire exactă, fără cuvinte uzuale)."""
    t = norm(text)
    m = CAN_I_TAKE.search(t)
    tokens = [w for w in (t[m.end() :].split()[:3] if m else t.split()) if len(w) >= 4]
    for tok in tokens:
        hit = _patient_match(tok, meds)
        if hit:
            return hit[1]
        if m and kb is not None:
            found = _catalog_match(tok, kb)
            if found:
                return found
    return None


@cache
def _symptom_words() -> frozenset[str]:
    return frozenset(w for _, syns in _synonyms() for s in syns for w in s.split())


# ---------------------------------------------------------------- rezerva Gemini


def llm_schema() -> Json:
    return {
        "type": "object",
        "properties": {"symptoms": {"type": "array", "items": {"type": "string", "enum": sorted(vocabulary())}}},
        "required": ["symptoms"],
    }


def parse_llm(raw: str) -> list[str]:
    """Codurile din răspunsul modelului; orice cod din afara vocabularului respinge tot răspunsul."""
    try:
        data = json.loads(raw)
    except ValueError:
        return []
    codes = data.get("symptoms") if isinstance(data, dict) else None
    if not isinstance(codes, list) or not all(isinstance(c, str) for c in codes):
        return []
    if any(c not in vocabulary() for c in codes):
        return []
    return list(dict.fromkeys(codes))


def _gemini(text: str) -> str | None:
    config = dotenv_values(ROOT / ".env") | dotenv_values(ROOT / "backend" / ".env") | dict(os.environ)
    key = config.get("GEMINI_API_KEY")
    model = config.get("GEMINI_MODEL") or "gemini-3.1-flash-lite"
    if not key or not re.fullmatch(r"[\w.-]+", model):
        return None
    labels = "; ".join(f"{c}: {v['label']}" for c, v in vocabulary().items())
    prompt = (
        "Un vârstnic spune cum se simte. Alege doar simptomele pe care le spune explicit, din lista de coduri. "
        f"Dacă nu spune niciun simptom, listă goală.\nCoduri: {labels}\nText: {text}"
    )
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0, "responseMimeType": "application/json", "responseJsonSchema": llm_schema()},
    }
    request = Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": key},
    )
    # B7: tot apelul are cel mult LLM_TIMEOUT; după termen rămâne rezultatul sinonimelor (niciun simptom).
    return within(LLM_TIMEOUT, lambda: _fetch(request), "gemini check-in")


def _fetch(request: Request) -> str:
    with urlopen(request, timeout=LLM_TIMEOUT) as response:
        body = json.load(response)
    return "".join(p.get("text", "") for p in body["candidates"][0]["content"]["parts"])


def _cache_path(text: str) -> Path:
    return CACHE / f"checkin-{hashlib.sha256(norm(text).encode()).hexdigest()}.json"


def symptoms_from_llm(text: str) -> list[Symptom]:
    # cache-ul demo (make demo-warm): transcrierile de la repetiții răspund la fel și fără internet
    path = _cache_path(text)
    try:
        codes = parse_llm(path.read_text(encoding="utf-8"))
    except OSError:
        codes = []
    if not codes:
        raw = _gemini(text)
        codes = parse_llm(raw) if raw else []
        if codes:
            try:
                CACHE.mkdir(parents=True, exist_ok=True)
                path.write_text(json.dumps({"symptoms": codes}), encoding="utf-8")
            except OSError:
                pass
    vocab = vocabulary()
    return [Symptom(c, vocab[c]["label"], "moderate", vocab[c]["red_flag"], vocab[c]["advice"]) for c in codes]


def understand(text: str, meds: list[Json] | None = None, kb: Kb | None = None) -> Understanding:
    symptoms = find_symptoms(text)
    intent = detect_intent(text, bool(symptoms))
    used_llm = False
    # O întrebare („pot să iau…”, „ce pastilă…”) fără simptome nu are nevoie de rezervă.
    if not symptoms and intent == "other" and len(norm(text).split()) > LLM_MIN_WORDS:
        symptoms = symptoms_from_llm(text)
        used_llm = bool(symptoms)
        intent = detect_intent(text, used_llm)
    return Understanding(
        intent=intent,
        symptoms=symptoms,
        drug_query=match_drug(text, meds or [], kb),
        used_llm=used_llm,
    )
