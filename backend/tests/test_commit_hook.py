"""T-P0-03: hook-ul commit-msg respinge mesajele fără co-author și pe cele cu mențiuni AI."""

import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
HOOK = ROOT / ".githooks" / "commit-msg"
MIHNEA = "Co-authored-by: Remetan Mihnea-Florin <mihnearemetan@gmail.com>"


def run(tmp_path, message: str, user: str = "VladimirTM") -> int:
    msg = tmp_path / "MSG"
    msg.write_text(message)
    env = {"PATH": "/usr/bin:/bin", "GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "user.name", "GIT_CONFIG_VALUE_0": user}
    return subprocess.run(["bash", str(HOOK), str(msg)], env=env, cwd=ROOT, capture_output=True).returncode


@pytest.mark.parametrize(
    ("message", "accepted"),
    [
        (f"Add contracts\n\n{MIHNEA}\n", True),
        (f"Add AGENTS.md and CLAUDE.md\n\n{MIHNEA}\n", True),
        ("Add contracts\n", False),
        (f"Add contracts\n\nGenerated with Claude Code\n{MIHNEA}\n", False),
        (f"Add contracts\n\nCo-authored-by: Claude <noreply@anthropic.com>\n{MIHNEA}\n", False),
        (f"Add contracts.\n\n{MIHNEA}\n", False),
        (f"{'x' * 73}\n\n{MIHNEA}\n", False),
    ],
)
def test_vladimir(tmp_path, message, accepted):
    assert (run(tmp_path, message) == 0) is accepted


def test_mihnea_needs_vladimir(tmp_path):
    vlad = "Co-authored-by: VladimirTM <vladimirghimpau@gmail.com>"
    assert run(tmp_path, f"Add engine\n\n{vlad}\n", user="Remetan Mihnea-Florin") == 0
    assert run(tmp_path, f"Add engine\n\n{MIHNEA}\n", user="Remetan Mihnea-Florin") != 0
