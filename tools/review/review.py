"""Ajutoarele lui run.sh (fără dependențe, python3 din sistem).

review.py sims <N>                             primul iPhone cu cel mai nou iOS + N-1 clone (UDID, nume)
review.py free-ports <N> <port>                N porturi libere de la <port> în sus
review.py split <N> <ReviewTour.swift> [teste…]   testele împărțite pe N simulatoare (un rând per simulator)
review.py xctestrun <built.xctestrun> <plan> <out> KEY=VAL…
                                               o configurație de test per configurație din test plan
review.py shots <export_dir> <shots_dir>       atașamentele exportate, cu numele date de teste
review.py frames <video> <start> <log> <dir>   cadrele de după fiecare `PG_REVIEW_TAP` din log
review.py index <out_dir> <QN> <seconds> <result.xcresult>…
                                               index.md: capturile pe flux și variantă, auditul, durata
"""

from __future__ import annotations

import json
import plistlib
import re
import shlex
import shutil
import socket
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

VARIANTS = ["Light", "Dark", "AX", "Motion", "Contrast"]
FRAME_OFFSETS_MS = [0, 100, 200, 300, 500, 800]
UI_TARGET = "PolyGraphUITests"


def sims(count: str = "1") -> None:
    """Primul iPhone cu cel mai nou iOS, plus (pentru rularea în paralel) clone cu același model și iOS,
    create o singură dată și refolosite: „<model> (review N)”."""

    def available() -> dict:
        out = subprocess.run(
            ["xcrun", "simctl", "list", "devices", "available", "-j"], capture_output=True, text=True, check=True
        ).stdout
        return json.loads(out)["devices"]

    def version(runtime: str) -> tuple[int, ...]:
        m = re.search(r"iOS-(\d+(?:-\d+)*)$", runtime)
        return tuple(int(p) for p in m[1].split("-")) if m else ()

    devices = available()
    runtimes = sorted((r for r in devices if version(r)), key=version, reverse=True)
    primary = next(
        ((r, d) for r in runtimes for d in devices[r] if d["name"].startswith("iPhone") and "(review" not in d["name"]),
        None,
    )
    if not primary:
        sys.exit("Niciun simulator iPhone disponibil (Xcode → Settings → Components).")
    runtime, device = primary
    print(device["udid"], device["name"], sep="\t")
    for n in range(2, int(count) + 1):
        name = f"{device['name']} (review {n})"
        clone = next((d for d in devices[runtime] if d["name"] == name), None)
        if clone:
            udid = clone["udid"]
        else:
            udid = subprocess.run(
                ["xcrun", "simctl", "create", name, device["deviceTypeIdentifier"], runtime],
                capture_output=True,
                text=True,
                check=True,
            ).stdout.strip()
        print(udid, name, sep="\t")


def free_ports(count: str, start: str) -> None:
    found = []
    for port in range(int(start), int(start) + 200):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                s.bind(("0.0.0.0", port))
            except OSError:
                continue
        found.append(port)
        if len(found) == int(count):
            print(*found)
            return
    sys.exit(f"Nu găsesc {count} porturi libere de la {start} în sus.")


# Durata unui test într-o variantă, măsurată la Q0 (secunde); doar pentru împărțirea pe simulatoare.
TEST_SECONDS = {
    "testOnboarding": 45,
    "testScanPrescriptionFake": 30,
    "testShare": 33,
    "testScanBoxFake": 29,
    "testSettingsDemo": 26,
    "testCaregiverAlertsAndDetail": 25,
    "testVoiceCheckInFake": 24,
    "testBackendDown": 23,
    "testScanUnreadable": 21,
    "testCaregiverMeds": 20,
    "testDay": 20,
    "testGraph": 18,
    "testFeed": 18,
    "testTakenAndUndo": 16,
    "testSeniorNowMorning": 11,
    "testSeniorNowNoon": 11,
    "testSeniorNowEvening": 11,
}
VIDEO_SECONDS = 25  # pe simulatorul 1, după tur: 2 teste × 2 variante, raportat la o variantă din 5


def split(count: str, source: str, *only: str) -> None:
    """Cel mai lung test întâi, pe simulatorul cel mai liber; simulatorul 1 pornește cu filmarea."""
    tests = list(only) or re.findall(r"func (test\w+)\(\)", Path(source).read_text())
    loads = [0] * int(count)
    loads[0] = VIDEO_SECONDS
    shards: list[list[str]] = [[] for _ in loads]
    for test in sorted(tests, key=lambda t: -TEST_SECONDS.get(t, 20)):
        i = loads.index(min(loads))
        shards[i].append(test)
        loads[i] += TEST_SECONDS.get(test, 20)
    for shard in shards:
        print(" ".join(shard))


def xctestrun(built: str, plan_path: str, out: str, *pairs: str) -> None:
    """Schema PolyGraph e autogenerată (xcshareddata/ e ignorat în git), deci `-testPlan Review` nu o găsește.
    Construim din Review.xctestplan un .xctestrun echivalent, doar cu ținta de UI."""
    with open(built, "rb") as f:
        run = plistlib.load(f)
    plan = json.loads(Path(plan_path).read_text())
    extra = dict(p.split("=", 1) for p in pairs)
    defaults = plan.get("defaultOptions", {})
    base = next(t for c in run["TestConfigurations"] for t in c["TestTargets"] if t.get("BlueprintName") == UI_TARGET)
    configs = []
    for config in plan["configurations"]:
        options = {**defaults, **config.get("options", {})}
        target = json.loads(json.dumps(base))
        env = {e["key"]: e["value"] for e in options.get("environmentVariableEntries", [])}
        target["EnvironmentVariables"] = {**target.get("EnvironmentVariables", {}), **env, **extra}
        args = [a for e in options.get("commandLineArgumentEntries", []) for a in shlex.split(e["argument"])]
        target["CommandLineArguments"] = target.get("CommandLineArguments", []) + args
        target["UserAttachmentLifetime"] = options.get("userAttachmentLifetime", "keepAlways")
        target["SystemAttachmentLifetime"] = options.get("systemAttachmentLifetime", "deleteOnSuccess")
        target["TestTimeoutsEnabled"] = options.get("testTimeoutsEnabled", True)
        target["DefaultTestExecutionTimeAllowance"] = options.get("defaultTestExecutionTimeAllowance", 180)
        configs.append({"Name": config["name"], "IsEnabled": True, "TestTargets": [target]})
    run["TestConfigurations"] = configs
    with open(out, "wb") as f:
        plistlib.dump(run, f)


def shots(export_dir: str, shots_dir: str) -> None:
    src, dst = Path(export_dir), Path(shots_dir)
    dst.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((src / "manifest.json").read_text())
    count = 0
    for test in manifest:
        for item in test.get("attachments", []):
            exported = src / item["exportedFileName"]
            # „<nume>_<index>_<UUID>.<ext>”: păstrăm numele dat în test
            human = item.get("suggestedHumanReadableName") or item["exportedFileName"]
            stem = re.sub(r"_\d+_[0-9A-F-]{36}(?=\.[^.]+$|$)", "", human)
            ext = Path(item["exportedFileName"]).suffix
            if not stem.endswith(ext):
                stem += ext
            if exported.is_file():
                shutil.move(str(exported), dst / stem)
                count += 1
    print(f"{count} atașamente în {dst}")


def frames(video: str, start: str, log: str, out_dir: str) -> None:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    t0 = float(start)
    taps = re.findall(r"PG_REVIEW_TAP (\S+) (\S+) ([\d.]+)", Path(log).read_text(errors="replace"))
    seen: dict[str, int] = defaultdict(int)
    for flow, variant, at in taps:
        key = f"{flow}-{variant}"
        seen[key] += 1
        suffix = f"-{seen[key]}" if seen[key] > 1 else ""
        for ms in FRAME_OFFSETS_MS:
            offset = max(0.0, float(at) - t0 + ms / 1000)
            subprocess.run(
                [
                    "ffmpeg",
                    "-loglevel",
                    "error",
                    "-y",
                    "-ss",
                    f"{offset:.3f}",
                    "-i",
                    video,
                    "-frames:v",
                    "1",
                    str(out / f"{key}{suffix}-{ms:03d}ms.png"),
                ],
                check=False,
            )
    print(f"{len(taps)} atingeri, cadre în {out}")


def test_counts(results: list[str]) -> dict[str, int]:
    counts: dict[str, int] = defaultdict(int)
    for path in results:
        proc = subprocess.run(
            ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", path, "--compact"],
            capture_output=True,
            text=True,
            check=False,
        )
        if proc.returncode == 0:
            summary = json.loads(proc.stdout)
            for key in ("passedTests", "failedTests", "skippedTests"):
                counts[key] += summary.get(key, 0)
    return counts


def index(out_dir: str, q: str, seconds: str, *results: str) -> None:
    out = Path(out_dir)
    shots_dir = out / "shots"
    name_re = re.compile(r"^(?P<flow>[A-Za-z]+)-(?P<n>\d\d)-(?P<step>[A-Za-z]+)-(?P<variant>[A-Za-z]+)")
    grid: dict[str, dict[str, list[str]]] = defaultdict(lambda: defaultdict(list))
    audit_by_variant: dict[str, int] = defaultdict(int)
    audit_by_type: dict[str, int] = defaultdict(int)
    absent: dict[str, set[str]] = defaultdict(set)
    for path in sorted(shots_dir.glob("*")):
        if path.suffix == ".png" and (m := name_re.match(path.name)):
            grid[m["flow"]][m["variant"]].append(path.name)
        elif path.name.endswith(".audit.json") and (m := name_re.match(path.name)):
            issues = json.loads(path.read_text())
            audit_by_variant[m["variant"]] += len(issues)
            for issue in issues:
                audit_by_type[issue.get("type", "?")] += 1
        elif "-notes-" in path.name and path.suffix == ".json":
            notes = json.loads(path.read_text())
            for what in notes.get("absent", []):
                absent[what].add(notes.get("variant", "?"))

    shot_total = sum(len(v) for f in grid.values() for v in f.values())
    variants_seen = [v for v in VARIANTS if any(v in f for f in grid.values())]
    audit_total = sum(audit_by_variant.values())
    tests = test_counts(list(results))
    mins, secs = divmod(int(float(seconds)), 60)

    lines = [
        f"# {q} · turul de review pe simulator",
        "",
        f"- Durata: **{mins} min {secs:02d} s**",
        f"- Capturi: **{shot_total}**, în {len(variants_seen)}/5 variante ({', '.join(variants_seen) or '—'})",
        f"- Erori de audit (performAccessibilityAudit): **{audit_total}**"
        + (
            " (" + ", ".join(f"{v} {audit_by_variant[v]}" for v in VARIANTS if v in audit_by_variant) + ")"
            if audit_total
            else ""
        ),
        (
            f"- Teste: {tests.get('passedTests', 0)} trecute, {tests.get('failedTests', 0)} picate,"
            f" {tests.get('skippedTests', 0)} sărite"
        ),
        (
            "- Fișiere: `shots/` (capturi, `.elements.json`, `.audit.json`, `-notes-`), `frames/`, `app-N.log`,"
            " `backend-N.log`, `result.xcresult`"
        ),
        "",
        "## Capturi pe flux și variantă",
        "",
        "| Flux | " + " | ".join(VARIANTS) + " |",
        "|---|" + "---|" * len(VARIANTS),
    ]
    for flow in sorted(grid):
        lines.append(f"| {flow} | " + " | ".join(str(len(grid[flow].get(v, []))) for v in VARIANTS) + " |")

    if audit_by_type:
        lines += ["", "## Auditul de accesibilitate, pe tip", ""]
        lines += [f"- {t}: {n}" for t, n in sorted(audit_by_type.items(), key=lambda x: -x[1])]

    lines += ["", "## Absente (ecrane sau elemente care n-au apărut)", ""]
    if absent:
        lines += [f"- `{what}` ({', '.join(v for v in VARIANTS if v in absent[what])})" for what in sorted(absent)]
    else:
        lines.append("- niciunul")

    frames_dir = out / "frames"
    if frames_dir.is_dir() and any(frames_dir.iterdir()):
        lines += ["", "## Cadre din video (ms după atingere)", ""]
        for png in sorted(frames_dir.glob("*.png")):
            lines.append(f"- [`{png.name}`](frames/{png.name})")

    lines += ["", "## Lista capturilor", ""]
    for flow in sorted(grid):
        lines.append(f"### {flow}")
        lines.append("")
        for variant in VARIANTS:
            for name in grid[flow].get(variant, []):
                lines.append(f"- [{name}](shots/{name})")
        lines.append("")

    (out / "index.md").write_text("\n".join(lines) + "\n")
    print(f"index.md: {shot_total} capturi, {audit_total} erori de audit, {mins} min {secs:02d} s")


if __name__ == "__main__":
    commands = {
        "sims": sims,
        "free-ports": free_ports,
        "split": split,
        "xctestrun": xctestrun,
        "shots": shots,
        "frames": frames,
        "index": index,
    }
    if len(sys.argv) < 2 or sys.argv[1] not in commands:
        sys.exit(__doc__)
    commands[sys.argv[1]](*sys.argv[2:])
