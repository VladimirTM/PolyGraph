import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "contracts"))
sys.path.insert(0, str(ROOT / "backend"))
sys.path.insert(0, str(ROOT / "kb"))
pytest_plugins = ["engine_helpers"]  # fixture-ul mini_kb (B2)


import pytest  # noqa: E402


@pytest.fixture(autouse=True)
def _checkin_llm_cache(tmp_path, monkeypatch):
    """Răspunsurile Gemini falsificate din teste nu ajung în cache-ul demo din repo (demo/llm_cache)."""
    from polygraph.voice import understand

    monkeypatch.setattr(understand, "CACHE", tmp_path / "llm_cache")
