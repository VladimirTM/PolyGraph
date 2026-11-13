# PolyGraph: instrucțiuni pentru Claude Code

Regulile sunt aceleași ca pentru ceilalți agenți: urmează [`AGENTS.md`](AGENTS.md) (care trimite la `CONTRIBUTING.md`, `contracts/` și `docs/PLAN.md`).

Pe scurt:
- Pentru orice modificare de UI (`app/` sau `backend/polygraph/share/`): citește întâi `.claude/skills/apple-design/SKILL.md` și `docs/DESIGN.md`.
- Nu edita `project.pbxproj`; fără dependențe externe în iOS; `xcodebuild build` după fiecare modificare.
- `contracts/` e sursa de adevăr; nu-l schimba decât dacă task-ul o cere.
- Commit-uri fără co-author sau mențiuni AI (atribuirea automată e dezactivată în `.claude/settings.json`; hook-ul `commit-msg` respinge mesajele care o conțin).
