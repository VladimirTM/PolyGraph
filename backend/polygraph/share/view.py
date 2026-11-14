"""B6: datele portalului medicului de familie (lista de pacienți, fișa, fișa de tipărit).
Funcții pure; rutele sunt în polygraph/api/main.py."""

from __future__ import annotations

import re
from datetime import UTC, date, datetime, time, timedelta
from typing import Any
from zoneinfo import ZoneInfo

from polygraph.engine.analyze import is_active
from polygraph.engine.context import brand
from polygraph.engine.texts_ro import ro_name
from polygraph.kb import SEV_RANK

Json = dict[str, Any]
TZ = ZoneInfo("Europe/Bucharest")
GRAVE = ("critical", "major")

# aceleași etichete ca în aplicație (app/PolyGraph/Design/Tokens.swift)
SEVERITY_LABEL = {"critical": "Critică", "major": "Gravă", "moderate": "Moderată", "minor": "Minoră", "info": "De știut"}
KIND_LABEL = {
    "ddi": "Interacțiune între medicamente",
    "food": "Interacțiune cu alimente",
    "duplicate": "Dublură terapeutică",
    "elderly_pim": "Nepotrivit la vârstnici",
    "anticholinergic": "Încărcare anticolinergică",
    "timing": "Program greu de respectat",
    "expired": "Cutie expirată",
    "symptom": "Simptom raportat",
}
SOURCE_LABEL = {
    "ddinter": "DDInter 2.0",
    "curated": "Lista verificată PolyGraph",
    "beers": "AGS Beers 2023",
    "stopp": "STOPP/START v3",
    "acb": "Scala ACB",
    "rcp": "RCP",
    "schedule": "Programul calculat de PolyGraph",
    "app": "PolyGraph",
}
DECISION_LABEL = {"keep": "Menține", "change_at_visit": "Modific la consultație", "refer_specialist": "Trimit la specialist"}
# întrebări pentru consultație; niciuna nu spune „opriți” sau o doză
QUESTION = {
    "ddi": "{meds}: se menține asocierea și ce monitorizare propuneți?",
    "food": "{meds}: ce recomandări de alimentație îi dăm pacientei?",
    "duplicate": "{meds}: sunt intenționate amândouă?",
    "elderly_pim": "{meds}: există o alternativă mai potrivită la {age} de ani?",
    "anticholinergic": "Încărcarea anticolinergică (ACB {acb}): se poate reduce?",
    "timing": "{meds}: se poate simplifica programul de administrare?",
    "expired": "{meds}: e nevoie de o rețetă nouă?",
    "symptom": "Simptomele raportate: pot fi legate de {meds}?",
}
MAX_QUESTIONS = 7

# explicațiile din butonul „i” al rezumatului; fișa arată doar cifra și o frază simplă
ACB_INFO = (
    "Scala ACB adună efectul anticolinergic al fiecărui medicament (0–3 puncte pe medicament). "
    "Un total de 3 sau mai mult e considerat relevant la vârstnici: risc mai mare de confuzie, constipație și căderi."
)
ADHERENCE_INFO = (
    "Aderența: dozele confirmate cu „Am luat” în aplicație, din cele programate în ultimele 7 zile (azi, doar până acum). "
    "O doză neconfirmată poate fi luată, dar neînregistrată."
)
SLOTS = ("dimineața", "la prânz", "seara", "la culcare")
_QTY = r"(?:\d+(?:[.,/]\d+)?|½)"
_SCHEME = re.compile(rf"^\s*({_QTY}(?:\s*-\s*{_QTY}){{2,3}})\s*(.*)$")


def plural(n: int, one: str, many: str) -> str:
    """„1 medicament”, „9 medicamente”, „20 de medicamente”."""
    if n == 1:
        return f"1 {one}"
    return f"{n} {many}" if n == 0 or 0 < n % 100 < 20 else f"{n} de {many}"


def ro_date(raw: str | None) -> str:
    if not raw:
        return "–"
    try:
        return date.fromisoformat(raw[:10]).strftime("%d.%m.%Y")
    except ValueError:
        return raw


def _instant(raw: str) -> datetime:
    at = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    return at if at.tzinfo else at.replace(tzinfo=TZ)


def ro_moment(raw: str) -> str:
    try:
        return _instant(raw).astimezone(TZ).strftime("%d.%m.%Y, %H:%M")
    except ValueError:
        return raw


def med_name(med: Json) -> str:
    strength = (med.get("product") or {}).get("strength_text")
    return f"{brand(med)} {strength}" if strength else brand(med)


def prescriber(med: Json) -> str | None:
    p = med.get("prescriber") or {}
    if p.get("name") and p.get("specialty"):
        return f"{p['name']} ({p['specialty']})"
    return p.get("name") or p.get("specialty")


def plain_posology(raw: str) -> str:
    """Posologia în cuvinte: „1-0-1, după masă” → „1 dimineața, 1 seara · după masă”; „cp” scris întreg.
    Ce nu e în schema dimineață-prânz-seară rămâne cum l-a scris medicul."""
    text = raw
    m = _SCHEME.match(raw)
    if m:
        qty = [q.strip() for q in m.group(1).split("-")]
        parts = [f"{q} {SLOTS[i]}" for i, q in enumerate(qty) if q.strip("0.,") != ""]
        if parts:
            rest = m.group(2).lstrip(",; ").strip()
            text = ", ".join(parts) + (f" · {rest}" if rest else "")
    text = re.sub(r"\bcp\b", "comprimat", text)
    return re.sub(r"(?<![\d/])1/2(?![\d/])", "½", text)


def med_row(med: Json) -> Json:
    dosage = med.get("dosage") or {}
    posology = dosage.get("raw") or ""
    how = plain_posology(posology)
    if dosage.get("as_needed"):
        posology = f"{posology} (la nevoie)" if posology else "la nevoie"
        how = f"{how} (la nevoie)" if how else "la nevoie"
    subs = med.get("substances") or []
    return {
        "id": med["id"],
        "name": med_name(med),
        "dci": ", ".join(ro_name(s.get("inn"), s.get("dci")) for s in subs) or "–",
        "atc": ", ".join(s.get("atc") or "–" for s in subs) or "–",
        "posology": posology or "–",
        "how": how or "–",
        "prescriber": prescriber(med) or "fără rețetă / nespecificat",
        "who": f"Prescris de: {prescriber(med)}" if prescriber(med) else "Fără rețetă (sau prescriptor nespecificat)",
        "since": ro_date(med.get("start_date")),
    }


def alert_view(alert: Json, names: dict[str, str]) -> Json:
    source = alert["source"]
    res = alert.get("resolution")
    return {
        **alert,
        "severity_label": SEVERITY_LABEL[alert["severity"]],
        "kind_label": KIND_LABEL.get(alert["kind"], alert["kind"]),
        "meds": [names.get(m, m) for m in alert["med_ids"]],
        "source_label": SOURCE_LABEL.get(source["db"], source["db"]),
        "grave": alert["severity"] in GRAVE,
        "reviewed": alert["status"] == "reviewed_by_doctor",
        "decision_label": DECISION_LABEL.get((res or {}).get("decision") or "", None),
        "resolution_at": ro_moment(res["at"]) if res else None,
    }


def adherence(meds: list[Json], doses: list[Json], schedule_for, today: date, now: datetime) -> int | None:
    """Procentul dozelor programate în ultimele 7 zile (azi doar până acum) confirmate cu „Am luat”.
    None dacă în fereastră nu s-a înregistrat nicio doză: fără date nu afișăm 0%."""
    recorded = {}
    for d in doses:
        try:
            recorded[(d["med_id"], _instant(d["scheduled_at"]).astimezone(UTC))] = d["status"]
        except ValueError:
            continue
    start = datetime.combine(today - timedelta(days=6), time(0), TZ)
    if not any(start <= at <= now for _, at in recorded):
        return None
    expected = taken = 0
    for offset in range(6, -1, -1):
        day = today - timedelta(days=offset)
        for moment in schedule_for(day)["moments"]:
            at = datetime.combine(day, time.fromisoformat(moment["time"]), TZ)
            if at > now:
                continue
            for dose in moment["doses"]:
                expected += 1
                taken += recorded.get((dose["med_id"], at.astimezone(UTC))) == "taken"
    return round(100 * taken / expected) if expected else None


def recent_checkins(checkins: list[Json], today: date, events: list[Json] | None = None) -> list[Json]:
    """Check-in-urile din ultimele 7 zile, cele noi primele. La „Pot să iau…?” medicul vede și răspunsul dat, iar
    marcajul „semnalat familiei” apare și la întrebările care au ajuns în Noutăți (escalate rămâne false la ele)."""
    cut = today - timedelta(days=6)
    sent = {e["checkin_id"]: e for e in events or [] if e.get("checkin_id")}
    out = []
    for ci in checkins:
        try:
            when = _instant(ci["at"]).astimezone(TZ)
        except ValueError:
            continue
        if when.date() >= cut:
            event = sent.get(ci["id"])
            answer = ci.get("reply_text", "").removeprefix("Mulțumesc.").strip() if ci.get("intent") == "can_i_take" else ""
            out.append(
                {
                    **ci,
                    "when": when.strftime("%d.%m, %H:%M"),
                    "answer": answer or None,
                    "to_family": ci.get("escalate") or event is not None,
                    "grave": ci.get("escalate") or (event is not None and event["severity"] in ("critical", "major")),
                }
            )
    return list(reversed(out))


def schedule_view(schedule: Json, names: dict[str, str]) -> Json:
    return {
        "date": ro_date(schedule["date"]),
        "moments": [
            {
                "time": m["time"],
                "label": m["label"],
                "doses": [{**d, "name": names.get(d["med_id"], d["med_id"]), "qty": _qty(d["qty"])} for d in m["doses"]],
            }
            for m in schedule["moments"]
        ],
        "unsatisfied": [{**u, "meds": [names.get(i, i) for i in u["med_ids"]]} for u in schedule.get("unsatisfied") or []],
    }


def _qty(q: float) -> str:
    if q == 0.5:
        return "½"
    return str(int(q)) if float(q).is_integer() else str(q).replace(".", ",")


def questions(alerts: list[Json], age: int | None, acb: int) -> list[str]:
    """O întrebare per problemă, cele grave primele; restul tipurilor (fără interacțiunile moderate) după ele."""
    picked = [a for a in alerts if a["grave"]]
    picked += [a for a in alerts if not a["grave"] and a["kind"] not in ("ddi", "food") and SEV_RANK[a["severity"]] <= 2]
    out: list[str] = []
    for a in picked:
        q = QUESTION.get(a["kind"], "{meds}: ce recomandați?").format(
            meds=" + ".join(a["meds"]), age=age if age is not None else "această vârstă", acb=acb
        )
        if q not in out:
            out.append(q)
    return out[:MAX_QUESTIONS]


def _count(n: int, one: str, many: str) -> tuple[str, str]:
    value, _, label = plural(n, one, many).partition(" ")
    return value, label


def summary_stats(meds: int, doctors: int, grave: list[Json], acb: int, adh: int | None) -> list[Json]:
    """Cele patru cifre din capul fișei, fiecare cu o frază pe înțelesul oricui; termenii tehnici stau în „i”."""
    open_grave = sum(1 for a in grave if not a["reviewed"])
    meds_value, meds_label = _count(meds, "medicament", "medicamente")
    grave_value, grave_label = _count(len(grave), "alertă gravă", "alerte grave")
    if open_grave:
        grave_note, grave_tone = f"{open_grave} de revizuit", "attention"
    else:
        grave_note, grave_tone = ("toate revizuite" if grave else "nimic urgent"), None
    acb_note = "efect anticolinergic " + ("absent" if acb == 0 else "mic" if acb < 3 else "semnificativ")
    return [
        {"id": "meds", "value": meds_value, "label": meds_label, "note": f"de la {plural(doctors, 'medic', 'medici')}"},
        {"id": "grave", "value": grave_value, "label": grave_label, "note": grave_note, "tone": grave_tone},
        {"id": "acb", "value": str(acb), "label": "scor ACB", "note": acb_note, "info": ACB_INFO},
        {
            "id": "adherence",
            "value": f"{adh}%" if adh is not None else "–",
            "label": "doze luate",
            "note": "în ultimele 7 zile" if adh is not None else "încă nicio doză înregistrată",
            "info": ADHERENCE_INFO,
        },
    ]


def page_context(
    patient: Json,
    meds: list[Json],
    analysis: Json,
    checkins: list[Json],
    doses: list[Json],
    schedule_for,
    today: date,
    now: datetime,
    events: list[Json] | None = None,
) -> Json:
    active = [m for m in meds if is_active(m, today)]
    names = {m["id"]: med_name(m) for m in meds}
    alerts = sorted(
        (alert_view(a, names) for a in analysis["alerts"]),
        key=lambda a: (SEV_RANK[a["severity"]], a["status"] == "reviewed_by_doctor"),
    )
    grave = [a for a in alerts if a["grave"]]
    doctors = {(prescriber(m) or "").lower() for m in active} - {""}
    age = today.year - patient["birth_year"] if patient.get("birth_year") else None
    adh = adherence(active, doses, schedule_for, today, now)
    summary = [
        f"{plural(len(active), 'medicament', 'medicamente')} de la {plural(len(doctors), 'medic', 'medici')}",
        plural(len(grave), "alertă gravă", "alerte grave"),
        f"ACB {analysis['acb_total']}",
        f"aderență {adh}% în ultimele 7 zile" if adh is not None else "aderență: încă nicio doză înregistrată",
    ]
    stats = summary_stats(len(active), len(doctors), grave, analysis["acb_total"], adh)
    by_prescriber: dict[str, list[Json]] = {}
    for m in active:
        by_prescriber.setdefault(prescriber(m) or "Fără rețetă / nespecificat", []).append(med_row(m))
    return {
        "patient": patient,
        "age": age,
        "summary": summary,
        "stats": stats,
        "meds": [med_row(m) for m in active],
        "by_prescriber": sorted(by_prescriber.items(), key=lambda kv: kv[0].startswith("Fără")),
        "grave": grave,
        "other": [a for a in alerts if not a["grave"]],
        "other_label": plural(sum(1 for a in alerts if not a["grave"]), "alertă", "alerte"),
        "alerts": alerts,
        "acb": analysis["acb_total"],
        "graph": analysis["graph"],
        "checkins": recent_checkins(checkins, today, events),
        "schedule": schedule_view(schedule_for(today), names),
        "questions": questions(alerts, age, analysis["acb_total"]),
        "generated": now.astimezone(TZ).strftime("%d.%m.%Y, %H:%M"),
    }


def patient_card(patient: Json, meds: list[Json], analysis: Json, checkins: list[Json], today: date) -> Json:
    """Rândul unui pacient din lista medicului: cele nerevizuite și semnalele familiei îl urcă în listă."""
    active = [m for m in meds if is_active(m, today)]
    grave = [a for a in analysis["alerts"] if a["severity"] in GRAVE]
    open_grave = [a for a in grave if a["status"] != "reviewed_by_doctor"]
    recent = recent_checkins(checkins, today)
    escalated = [c for c in recent if c.get("escalate")]
    return {
        "patient": patient,
        "age": today.year - patient["birth_year"] if patient.get("birth_year") else None,
        "meds": len(active),
        "grave": len(grave),
        "open_grave": len(open_grave),
        "open_titles": [a["title"] for a in sorted(open_grave, key=lambda a: SEV_RANK[a["severity"]])][:2],
        "acb": analysis["acb_total"],
        "escalated": len(escalated),
        "last_checkin": recent[0]["when"] if recent else None,
        "sort": (-len(escalated), -len(open_grave), patient.get("name") or ""),
    }


WEEKDAYS = ("luni", "marți", "miercuri", "joi", "vineri", "sâmbătă", "duminică")
MONTHS = (
    "ianuarie", "februarie", "martie", "aprilie", "mai", "iunie",
    "iulie", "august", "septembrie", "octombrie", "noiembrie", "decembrie",
)  # fmt: skip


def portal_summary(cards: list[Json], today: date) -> Json:
    """Capul listei de pacienți: data, cele patru cifre și împărțirea în „de revizuit” / „fără nimic urgent”."""
    pending = sum(c["open_grave"] for c in cards)
    escalated = sum(c["escalated"] for c in cards)
    reviewed = sum(c["grave"] - c["open_grave"] for c in cards)
    attention = [c for c in cards if c["open_grave"] or c["escalated"]]
    with_pending = sum(1 for c in cards if c["open_grave"])
    patients_value, patients_label = _count(len(cards), "pacient", "pacienți")
    pending_value, pending_label = _count(pending, "alertă gravă", "alerte grave")
    escalated_value, escalated_label = _count(escalated, "simptom semnalat", "simptome semnalate")
    reviewed_value, reviewed_label = _count(reviewed, "alertă revizuită", "alerte revizuite")
    return {
        "date": f"{WEEKDAYS[today.weekday()]}, {today.day} {MONTHS[today.month - 1]}",
        "lead": (
            f"{plural(pending, 'alertă gravă', 'alerte grave')} de revizuit la {plural(with_pending, 'pacient', 'pacienți')}."
            if pending
            else "Totul e revizuit. Nicio alertă gravă nu vă așteaptă."
        ),
        "stats": [
            {"id": "patients", "value": patients_value, "label": patients_label, "note": "în listă"},
            {
                "id": "pending",
                "value": pending_value,
                "label": pending_label,
                "note": "de revizuit",
                "tone": "attention" if pending else None,
            },
            {
                "id": "escalated",
                "value": escalated_value,
                "label": escalated_label,
                "note": "de familie, 7 zile",
                "tone": "attention" if escalated else None,
            },
            {
                "id": "reviewed",
                "value": reviewed_value,
                "label": reviewed_label,
                "note": "trimisă familiei" if reviewed == 1 else "trimise familiei",
            },
        ],
        "attention": attention,
        "others": [c for c in cards if c not in attention],
    }


def review_event(alert: Json, decision: str, note: str, at: str, suffix: str) -> Json:
    """Evenimentul din Noutăți (A5) pentru o alertă revizuită de medicul de familie."""
    label = DECISION_LABEL[decision]
    return {
        "id": f"ev_review_{suffix}",
        "at": at,
        "type": "doctor_reviewed",
        "severity": alert["severity"],
        "title": f"Medicul de familie a revizuit: {alert['title']}",
        "body": f"Decizie: {label}." + (f" {note}" if note else ""),
        "med_ids": alert["med_ids"],
        "alert_id": alert["id"],
        "checkin_id": None,
    }
