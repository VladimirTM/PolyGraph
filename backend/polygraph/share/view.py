"""B6: datele portalului medicului de familie (lista de pacienți, fișa, fișa de tipărit).
Funcții pure; rutele sunt în polygraph/api/main.py."""

from __future__ import annotations

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


def med_row(med: Json) -> Json:
    dosage = med.get("dosage") or {}
    posology = dosage.get("raw") or ""
    if dosage.get("as_needed"):
        posology = f"{posology} (la nevoie)" if posology else "la nevoie"
    subs = med.get("substances") or []
    return {
        "id": med["id"],
        "name": med_name(med),
        "dci": ", ".join(ro_name(s.get("inn"), s.get("dci")) for s in subs) or "–",
        "atc": ", ".join(s.get("atc") or "–" for s in subs) or "–",
        "posology": posology or "–",
        "prescriber": prescriber(med) or "fără rețetă / nespecificat",
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
    by_prescriber: dict[str, list[Json]] = {}
    for m in active:
        by_prescriber.setdefault(prescriber(m) or "Fără rețetă / nespecificat", []).append(med_row(m))
    return {
        "patient": patient,
        "age": age,
        "summary": summary,
        "meds": [med_row(m) for m in active],
        "by_prescriber": sorted(by_prescriber.items(), key=lambda kv: kv[0].startswith("Fără")),
        "grave": grave,
        "other": [a for a in alerts if not a["grave"]],
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
