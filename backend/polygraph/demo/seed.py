"""Istoricul pacientului demo, recreat la fiecare `/demo/reset` (B7): dozele din ultimele 7 zile, cu 2 ratate,
și un check-in vechi fără simptome; plus doza ratată simulată din modul demo (`/demo/missed-dose`).

Ziua de azi rămâne neatinsă: ecranul „Acum” al Mariei pornește de la prima doză a zilei, ca în scenariul din secțiunea 7.
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from datetime import UTC, date, datetime, time, timedelta
from typing import Any
from zoneinfo import ZoneInfo

from polygraph.store import Store
from polygraph.voice.correlate import unwell_hint

Json = dict[str, Any]
TZ = ZoneInfo("Europe/Bucharest")
LOG = logging.getLogger("uvicorn.error")
HISTORY_DAYS = 7
# (acum câte zile, medicamentul): dozele pe care Maria nu le-a confirmat; restul sunt „Am luat”
MISSED = ((2, "med_06"), (5, "med_03"))
OLD_CHECKIN = {
    "id": "ci_demo_old",
    "days_ago": 3,
    "time": "10:05",
    "transcript": "Azi mă simt bine, am dormit bine și am ieșit puțin la plimbare.",
}


def dose_key(at: datetime) -> str:
    """Cheia de idempotență din POST /doses (aceeași oră, indiferent de fusul scris de telefon)."""
    return at.astimezone(UTC).isoformat()


def _z(at: datetime) -> str:
    return at.astimezone(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _instant(raw: str) -> datetime | None:
    try:
        at = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        return None
    return at if at.tzinfo else at.replace(tzinfo=TZ)


def _brands(meds: list[Json], med_ids: list[str]) -> str:
    names = {m["id"]: (m.get("product") or {}).get("brand") or m["id"] for m in meds}
    return ", ".join(names.get(mid, mid) for mid in med_ids)


def missed_event(patient: Json, meds: list[Json], moment: Json, day: date, med_ids: list[str], suffix: str) -> Json:
    at = datetime.combine(day, time.fromisoformat(moment["time"]), TZ) + timedelta(hours=1)
    return {
        "id": f"ev_missed_{suffix}",
        "at": at.replace(microsecond=0).isoformat(),
        "type": "dose_missed",
        "severity": "info",
        "title": f"{patient.get('name') or 'Pacientul'} n-a confirmat dozele de la {moment['time']}",
        "body": f"{_brands(meds, med_ids)}, {moment['label'][:1].lower()}{moment['label'][1:]}.",
        "med_ids": med_ids,
        "alert_id": None,
        "checkin_id": None,
    }


def seed_history(
    store: Store, pid: str, patient: Json, meds: list[Json], schedule_for: Callable[[date], Json], today: date
) -> None:
    missed = {(today - timedelta(days=d), mid) for d, mid in MISSED}
    for offset in range(HISTORY_DAYS, 0, -1):
        day = today - timedelta(days=offset)
        for moment in schedule_for(day)["moments"]:
            at = datetime.combine(day, time.fromisoformat(moment["time"]), TZ)
            skipped = []
            for dose in moment["doses"]:
                if (day, dose["med_id"]) in missed:
                    skipped.append(dose["med_id"])
                    continue
                store.record_dose(
                    pid,
                    dose_key(at),
                    {
                        "med_id": dose["med_id"],
                        "scheduled_at": at.isoformat(),
                        "status": "taken",
                        "recorded_at": _z(at + timedelta(minutes=4)),
                    },
                )
            if skipped:
                store.add_event(pid, missed_event(patient, meds, moment, day, skipped, f"{day:%m%d}_{moment['time'][:2]}"))

    when = datetime.combine(today - timedelta(days=OLD_CHECKIN["days_ago"]), time.fromisoformat(OLD_CHECKIN["time"]), TZ)
    caregiver = patient.get("caregiver_name")
    store.add_checkin(
        pid,
        {
            "id": OLD_CHECKIN["id"],
            "at": when.isoformat(),
            "transcript": OLD_CHECKIN["transcript"],
            "intent": "other",
            "symptoms": [],
            "correlations": [],
            "escalate": False,
            "reply_text": f"Mulțumesc. {unwell_hint(caregiver)}",
        },
    )


def simulate_missed_dose(store: Store, pid: str, patient: Json, meds: list[Json], schedule: Json, now: datetime) -> Json:
    """Ultimul moment de azi care a trecut (sau primul, dimineața devreme), cu dozele neconfirmate → eveniment în Noutăți.
    Nu scrie nimic în doze: o doză ratată e una pentru care nu s-a apăsat nimic."""
    day = date.fromisoformat(schedule["date"])
    moments = schedule["moments"]
    if not moments:
        raise LookupError("Azi nu e programată nicio doză.")
    past = [m for m in moments if datetime.combine(day, time.fromisoformat(m["time"]), TZ) <= now]
    moment = past[-1] if past else moments[0]
    at = datetime.combine(day, time.fromisoformat(moment["time"]), TZ)
    taken = {d["med_id"] for d in store.list_doses(pid) if d["status"] == "taken" and _instant(d["scheduled_at"]) == at}
    med_ids = [d["med_id"] for d in moment["doses"] if d["med_id"] not in taken] or [d["med_id"] for d in moment["doses"]]
    event = missed_event(patient, meds, moment, day, med_ids, now.strftime("%H%M%S") + "_sim")
    event["at"] = now.replace(microsecond=0).isoformat()
    store.add_event(pid, event)
    LOG.info("DOZĂ      ratată (simulată) la %s: %s", moment["time"], _brands(meds, med_ids))
    return event
