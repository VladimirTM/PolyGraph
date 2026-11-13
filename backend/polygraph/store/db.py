"""Persistența aplicației: SQLite `app.sqlite` (pacienți, medicamente, doze, check-in-uri, starea alertelor, link-uri
de partajare, cache GTIN). Obiectele de contract se țin ca JSON; analiza nu se salvează, se recalculează la cerere
și se îmbină cu `alert_state` (status / resolution puse de aparținător sau de farmacist).

Calea: PG_APP_DB (implicit backend/app.sqlite, gitignored); „:memory:” pentru teste.
"""

from __future__ import annotations

import json
import os
import secrets
import sqlite3
import threading
from pathlib import Path
from typing import Any

Json = dict[str, Any]
DEFAULT_DB = Path(__file__).resolve().parents[2] / "app.sqlite"

SCHEMA = """
CREATE TABLE IF NOT EXISTS patients(
    id TEXT PRIMARY KEY, token TEXT NOT NULL UNIQUE, data TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE TABLE IF NOT EXISTS meds(
    patient_id TEXT NOT NULL REFERENCES patients(id) ON DELETE CASCADE, id TEXT NOT NULL, data TEXT NOT NULL,
    position INTEGER NOT NULL, PRIMARY KEY (patient_id, id)
);
CREATE TABLE IF NOT EXISTS doses(
    patient_id TEXT NOT NULL REFERENCES patients(id) ON DELETE CASCADE, med_id TEXT NOT NULL, scheduled_at TEXT NOT NULL,
    data TEXT NOT NULL, PRIMARY KEY (patient_id, med_id, scheduled_at)
);
CREATE TABLE IF NOT EXISTS checkins(
    patient_id TEXT NOT NULL REFERENCES patients(id) ON DELETE CASCADE, id TEXT NOT NULL, at TEXT NOT NULL,
    data TEXT NOT NULL, PRIMARY KEY (patient_id, id)
);
CREATE TABLE IF NOT EXISTS alert_state(
    patient_id TEXT NOT NULL REFERENCES patients(id) ON DELETE CASCADE, alert_id TEXT NOT NULL,
    status TEXT NOT NULL, resolution TEXT, PRIMARY KEY (patient_id, alert_id)
);
CREATE TABLE IF NOT EXISTS share_tokens(
    token TEXT PRIMARY KEY, patient_id TEXT NOT NULL REFERENCES patients(id) ON DELETE CASCADE, expires_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS gtin_cache(gtin TEXT PRIMARY KEY, product TEXT NOT NULL);
"""


class Store:
    def __init__(self, path: str | Path | None = None):
        self.path = str(path or os.environ.get("PG_APP_DB") or DEFAULT_DB)
        self._lock = threading.RLock()
        self._conn = sqlite3.connect(self.path, check_same_thread=False)
        self._conn.execute("PRAGMA foreign_keys = ON")
        self._conn.executescript(SCHEMA)
        self._conn.commit()

    def _q(self, sql: str, args: tuple = ()) -> list[tuple]:
        with self._lock:
            return self._conn.execute(sql, args).fetchall()

    def _x(self, sql: str, args: tuple = ()) -> int:
        with self._lock:
            cur = self._conn.execute(sql, args)
            self._conn.commit()
            return cur.rowcount

    # ---------------------------------------------------------------- pacienți

    def create_patient(self, patient: Json, token: str | None = None) -> str:
        token = token or secrets.token_urlsafe(18)
        self._x("INSERT INTO patients(id, token, data) VALUES (?, ?, ?)", (patient["id"], token, _dump(patient)))
        return token

    def delete_patient(self, pid: str) -> None:
        self._x("DELETE FROM patients WHERE id = ?", (pid,))

    def get_patient(self, pid: str) -> Json | None:
        row = self._q("SELECT data FROM patients WHERE id = ?", (pid,))
        return json.loads(row[0][0]) if row else None

    def patient_id_for_token(self, token: str) -> str | None:
        row = self._q("SELECT id FROM patients WHERE token = ?", (token,))
        return row[0][0] if row else None

    def update_patient(self, pid: str, patient: Json) -> None:
        self._x("UPDATE patients SET data = ? WHERE id = ?", (_dump(patient), pid))

    # ---------------------------------------------------------------- medicamente

    def list_meds(self, pid: str) -> list[Json]:
        return [json.loads(r[0]) for r in self._q("SELECT data FROM meds WHERE patient_id = ? ORDER BY position", (pid,))]

    def get_med(self, pid: str, mid: str) -> Json | None:
        row = self._q("SELECT data FROM meds WHERE patient_id = ? AND id = ?", (pid, mid))
        return json.loads(row[0][0]) if row else None

    def free_med_id(self, pid: str, wanted: str | None) -> str:
        """Id-ul cerut dacă e liber și valid, altfel următorul med_NN liber."""
        taken = {r[0] for r in self._q("SELECT id FROM meds WHERE patient_id = ?", (pid,))}
        if wanted and wanted not in taken:
            return wanted
        n = len(taken) + 1
        while f"med_{n:02d}" in taken:
            n += 1
        return f"med_{n:02d}"

    def add_med(self, pid: str, med: Json) -> None:
        pos = self._q("SELECT coalesce(max(position), 0) + 1 FROM meds WHERE patient_id = ?", (pid,))[0][0]
        self._x("INSERT INTO meds(patient_id, id, data, position) VALUES (?, ?, ?, ?)", (pid, med["id"], _dump(med), pos))

    def update_med(self, pid: str, med: Json) -> None:
        self._x("UPDATE meds SET data = ? WHERE patient_id = ? AND id = ?", (_dump(med), pid, med["id"]))

    def delete_med(self, pid: str, mid: str) -> bool:
        return self._x("DELETE FROM meds WHERE patient_id = ? AND id = ?", (pid, mid)) > 0

    def replace_meds(self, pid: str, meds: list[Json]) -> None:
        self._x("DELETE FROM meds WHERE patient_id = ?", (pid,))
        for m in meds:
            self.add_med(pid, m)

    # ---------------------------------------------------------------- check-in-uri (scrise de B5; citite de graf)

    def add_checkin(self, pid: str, checkin: Json) -> None:
        self._x(
            "INSERT OR REPLACE INTO checkins(patient_id, id, at, data) VALUES (?, ?, ?, ?)",
            (pid, checkin["id"], checkin["at"], _dump(checkin)),
        )

    def list_checkins(self, pid: str) -> list[Json]:
        return [json.loads(r[0]) for r in self._q("SELECT data FROM checkins WHERE patient_id = ? ORDER BY at", (pid,))]

    # ---------------------------------------------------------------- starea alertelor

    def alert_states(self, pid: str) -> dict[str, Json]:
        return {
            aid: {"status": status, "resolution": json.loads(res) if res else None}
            for aid, status, res in self._q("SELECT alert_id, status, resolution FROM alert_state WHERE patient_id = ?", (pid,))
        }

    def set_alert_state(self, pid: str, alert_id: str, status: str, resolution: Json | None = None) -> None:
        self._x(
            "INSERT OR REPLACE INTO alert_state(patient_id, alert_id, status, resolution) VALUES (?, ?, ?, ?)",
            (pid, alert_id, status, _dump(resolution) if resolution else None),
        )


def _dump(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"))
