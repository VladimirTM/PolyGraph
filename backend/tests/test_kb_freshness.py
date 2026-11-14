"""Q3F0: `make demo` spune când kb.sqlite e mai vechi decât sursele scrise de mână (Q3-01)."""

from __future__ import annotations

import os
import sqlite3
from pathlib import Path

from polygraph.demo.serve import kb_status

BUILT = "2026-11-14 07:36:03"  # UTC, ca datetime('now') din kb/build.py
BUILT_EPOCH = 1_794_641_763  # aceeași clipă


def make_kb(tmp_path: Path, built_at: str | None = BUILT) -> tuple[Path, Path]:
    kb_dir = tmp_path / "kb"
    (kb_dir / "rules").mkdir(parents=True)
    for name in ("ro_products_extra.csv", "curated_ddi.csv", "curated_dfi.csv", "overrides.csv", "rules/timing.yaml"):
        (kb_dir / name).write_text("x\n")
        os.utime(kb_dir / name, (BUILT_EPOCH - 3600, BUILT_EPOCH - 3600))
    kb = kb_dir / "kb.sqlite"
    with sqlite3.connect(kb) as conn:
        conn.execute("CREATE TABLE kb_meta(key TEXT PRIMARY KEY, value TEXT)")
        if built_at:
            conn.execute("INSERT INTO kb_meta VALUES ('built_at', ?)", (built_at,))
    os.utime(kb, (BUILT_EPOCH, BUILT_EPOCH))
    return kb, kb_dir


def test_missing_kb(tmp_path):
    assert kb_status(tmp_path / "kb.sqlite", tmp_path).startswith("✗ kb.sqlite lipsește")


def test_fresh_kb(tmp_path):
    kb, kb_dir = make_kb(tmp_path)
    assert kb_status(kb, kb_dir) == "✓ kb.sqlite la zi"


def test_source_edited_after_build(tmp_path):  # T-Q3F0-01
    kb, kb_dir = make_kb(tmp_path)
    os.utime(kb_dir / "ro_products_extra.csv", (BUILT_EPOCH + 3600, BUILT_EPOCH + 3600))
    os.utime(kb_dir / "rules" / "timing.yaml", (BUILT_EPOCH + 60, BUILT_EPOCH + 60))
    status = kb_status(kb, kb_dir)
    assert status.startswith("✗ kb.sqlite e mai vechi decât")
    assert "ro_products_extra.csv" in status and "rules/timing.yaml" in status
    assert status.endswith("rulați make kb")


def test_source_saved_in_the_build_second_is_not_newer(tmp_path):
    kb, kb_dir = make_kb(tmp_path)
    os.utime(kb_dir / "curated_ddi.csv", (BUILT_EPOCH + 0.5, BUILT_EPOCH + 0.5))
    assert kb_status(kb, kb_dir) == "✓ kb.sqlite la zi"


def test_without_built_at_uses_the_file_mtime(tmp_path):
    kb, kb_dir = make_kb(tmp_path, built_at=None)
    assert kb_status(kb, kb_dir) == "✓ kb.sqlite la zi"
    os.utime(kb_dir / "overrides.csv", (BUILT_EPOCH + 10, BUILT_EPOCH + 10))
    assert "overrides.csv" in kb_status(kb, kb_dir)
