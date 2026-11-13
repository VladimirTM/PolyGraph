"""Termen-limită total pentru apelurile de rețea (Gemini): `urlopen(timeout=…)` limitează doar fiecare operație de
socket, nu tot apelul (DNS-ul și un răspuns care vine picătură cu picătură pot depăși timeout-ul). În demo, o scanare sau
un check-in nu trebuie să aștepte mai mult decât termenul, oricât de proastă e rețeaua din sală."""

from __future__ import annotations

import logging
from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import TimeoutError as FuturesTimeout

LOG = logging.getLogger("uvicorn.error")
_POOL = ThreadPoolExecutor(max_workers=4, thread_name_prefix="llm")


def within[T](seconds: float, fn: Callable[[], T], label: str) -> T | None:
    """Rezultatul lui `fn()` sau None dacă nu vine în `seconds` ori aruncă o excepție (apelantul are rezerva lui)."""
    future = _POOL.submit(fn)
    try:
        return future.result(timeout=seconds)
    except FuturesTimeout:
        # firul abandonat se termină singur la timeout-ul socket-ului; cererea nu-l mai așteaptă
        LOG.warning("%s: fără răspuns în %.0f s, trec pe rezervă", label, seconds)
    except Exception as exc:  # noqa: BLE001  (orice eroare de rețea sau de format → rezerva)
        LOG.warning("%s: %s, trec pe rezervă", label, type(exc).__name__)
    return None
