#!/usr/bin/env bash
# Turul de review pe simulator (etapa Q, docs/PLAN.md „Q0”). `make review Q=Q1` sau tools/review/run.sh Q1.
# Rezultatul: .review/<QN>/ cu shots/, frames/, app.log, backend-*.log, result.xcresult și index.md.
#
# Testele se împart pe SIMS simulatoare care rulează în paralel; fiecare simulator trece testele lui prin toate
# variantele (configurațiile din app/Review.xctestplan) și are backend-ul lui (`make demo`, DEMO_MODE=1, bază de
# date proprie), ca testele să nu-și strice datele între ele.
# Variabile opționale:
#   SIMS=3                                  câte simulatoare în paralel (1 = secvențial)
#   CONFIGS="Light Dark AX Motion Contrast" doar câteva variante
#   ONLY="testDay testFeed"                 doar câteva teste din tur
#   TOUR=ReviewTour                         clasa de teste (EdgeCaseTour = turul agresiv de la Q3)
#   NO_VIDEO=1                              fără video și cadre pentru „Am luat” / microfon
#   AUDIT=0                                 fără auditul de accesibilitate (doar la depanarea unui test)
#   PORT=8000                               portul de la care se caută porturi libere
set -uo pipefail

Q="${1:-Q0}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/.review/$Q"
DERIVED="$ROOT/.review/DerivedData"
PY=(python3 -I "$ROOT/tools/review/review.py")
START=$(date +%s)
N=${SIMS:-3}
TOUR="${TOUR:-ReviewTour}"
[[ -f "$ROOT/app/PolyGraphUITests/$TOUR.swift" ]] || { printf '✗ Nu există app/PolyGraphUITests/%s.swift\n' "$TOUR" >&2; exit 1; }
read -r -a CONFIG_LIST <<<"${CONFIGS:-Light Dark AX Motion Contrast}"

log() { printf '▸ %s\n' "$*"; }
die() { printf '✗ %s\n' "$*" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"

# --- simulatoarele -----------------------------------------------------------------------------------------
UDIDS=()
while IFS=$'\t' read -r udid name; do
    UDIDS+=("$udid")
    log "Simulator ${#UDIDS[@]}: $name ($udid)"
done < <("${PY[@]}" sims "$N")
[[ ${#UDIDS[@]} -eq $N ]] || die "Nu găsesc $N simulatoare iPhone"

for udid in "${UDIDS[@]}"; do xcrun simctl boot "$udid" 2>/dev/null; done
for udid in "${UDIDS[@]}"; do
    xcrun simctl bootstatus "$udid" -b >/dev/null || die "Simulatorul $udid nu pornește"
    xcrun simctl status_bar "$udid" override --time 9:41 --batteryLevel 100 --batteryState charged \
        --cellularBars 4 --wifiBars 3 --dataNetwork wifi
    xcrun simctl ui "$udid" increase_contrast disabled
    xcrun simctl ui "$udid" appearance light
done

# --- backend-urile -----------------------------------------------------------------------------------------
read -r -a PORTS <<<"$("${PY[@]}" free-ports "$N" "${PORT:-8000}")" || die "Nu găsesc porturi libere"
BACKEND_PIDS=()
cleanup() {
    for pid in ${BACKEND_PIDS[@]+"${BACKEND_PIDS[@]}"}; do kill "$pid" 2>/dev/null; done
    # make → uv → python: oprim și ce ascultă pe porturile noastre
    for port in "${PORTS[@]}"; do lsof -t -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | xargs kill 2>/dev/null; done
    for i in "${!UDIDS[@]}"; do
        xcrun simctl ui "${UDIDS[$i]}" increase_contrast disabled 2>/dev/null
        xcrun simctl status_bar "${UDIDS[$i]}" clear 2>/dev/null
        # clonele se opresc (memorie); simulatorul principal rămâne pornit
        [[ $i -gt 0 ]] && xcrun simctl shutdown "${UDIDS[$i]}" 2>/dev/null
    done
}
trap cleanup EXIT

# kb.sqlite e generat (gitignored): într-un worktree nou îl luăm din checkout-ul principal
if [[ ! -f kb/kb.sqlite ]]; then
    MAIN=$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')
    [[ -f "$MAIN/kb/kb.sqlite" && "$MAIN" != "$ROOT" ]] && ln -s "$MAIN/kb/kb.sqlite" kb/kb.sqlite
fi
if [[ -f kb/kb.sqlite && -f backend/polygraph/api/main.py ]]; then
    BACKEND=demo; log "Backend: make demo (DEMO_MODE=1) pe porturile ${PORTS[*]}"
else
    BACKEND=mock; log "Backend: make mock (lipsește kb/kb.sqlite) pe porturile ${PORTS[*]}"
fi
uv sync --project backend --quiet 2>/dev/null
for i in "${!PORTS[@]}"; do
    data="$OUT/backend-$((i + 1))"
    mkdir -p "$data"
    PG_APP_DB="$data/app.sqlite" PG_MEDIA_DIR="$data/media" \
        make "$BACKEND" PORT="${PORTS[$i]}" >"$OUT/backend-$((i + 1)).log" 2>&1 &
    BACKEND_PIDS+=($!)
done
for i in "${!PORTS[@]}"; do
    url="http://127.0.0.1:${PORTS[$i]}"
    for _ in $(seq 1 120); do
        curl -fsS "$url/health" >/dev/null 2>&1 && break
        kill -0 "${BACKEND_PIDS[$i]}" 2>/dev/null || break
        sleep 0.5
    done
    curl -fsS "$url/health" >/dev/null 2>&1 \
        || { tail -20 "$OUT/backend-$((i + 1)).log"; die "Backend-ul de pe $url nu răspunde la /health"; }
done

# --- build -------------------------------------------------------------------------------------------------
log "Build for testing"
(cd app && xcodebuild build-for-testing -project PolyGraph.xcodeproj -scheme PolyGraph \
    -destination "id=${UDIDS[0]}" -derivedDataPath "$DERIVED" -quiet) >"$OUT/build.log" 2>&1 \
    || { tail -30 "$OUT/build.log"; die "Build-ul aplicației pică: blocker (vezi $OUT/build.log)"; }

BUILT=$(ls -t "$DERIVED"/Build/Products/PolyGraph_PolyGraph_iphonesimulator*.xctestrun | head -1)
APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/PolyGraph.app"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_PATH/Info.plist")
for i in "${!UDIDS[@]}"; do
    # Schema e autogenerată, deci `-testPlan Review` nu e disponibil: test plan-ul devine un .xctestrun
    "${PY[@]}" xctestrun "$BUILT" app/Review.xctestplan "$DERIVED/Build/Products/Review-$Q-$((i + 1)).xctestrun" \
        "PG_BASE_URL=http://127.0.0.1:${PORTS[$i]}" "PG_REVIEW_AUDIT=${AUDIT:-1}" || die "Nu pot genera .xctestrun din Review.xctestplan"
    xcrun simctl install "${UDIDS[$i]}" "$APP_PATH"
    xcrun simctl privacy "${UDIDS[$i]}" grant microphone "$BUNDLE_ID" 2>/dev/null
done

# testele, împărțite după durata măsurată (review.py split); simulatorul 1 face și filmarea
SHARD_TESTS=()
while IFS= read -r line; do SHARD_TESTS+=("$line"); done < <(
    "${PY[@]}" split "$N" "app/PolyGraphUITests/$TOUR.swift" ${ONLY:-})

run_tests() {  # <shard> <eticheta> <teste> <configurații…>
    local i="$1" label="$2" tests="$3"; shift 3
    local args=() t c
    for t in $tests; do args+=("-only-testing:PolyGraphUITests/$TOUR/$t"); done
    for c in "$@"; do args+=("-only-test-configuration" "$c"); done
    xcodebuild test-without-building -xctestrun "$DERIVED/Build/Products/Review-$Q-$((i + 1)).xctestrun" \
        -destination "id=${UDIDS[$i]}" -resultBundlePath "$OUT/result-$label.xcresult" "${args[@]}" \
        >"$OUT/test-$label.log" 2>&1
    printf '  %-12s %s\n' "$label" \
        "$(grep -E 'Executed [0-9]+ tests?' "$OUT/test-$label.log" | tail -1 | sed 's/^[[:space:]]*//')"
}

run_video() {  # <shard>: „Am luat” și inelul microfonului, filmate în Light și Motion
    local i="$1" video="$OUT/animations.mp4" configs=() t0
    for c in Light Motion; do [[ " ${CONFIG_LIST[*]} " == *" $c "* ]] && configs+=("$c"); done
    [[ ${#configs[@]} -gt 0 ]] || return
    xcrun simctl io "${UDIDS[$i]}" recordVideo --codec=h264 --force "$video" 2>"$OUT/video.log" &
    local rec=$!
    for _ in $(seq 1 50); do grep -q "Recording started" "$OUT/video.log" 2>/dev/null && break; sleep 0.1; done
    t0=$(python3 -c 'import time; print(time.time())')
    run_tests "$i" video "testTakenAndUndo testVoiceCheckInFake" "${configs[@]}"
    kill -INT "$rec" 2>/dev/null
    wait "$rec" 2>/dev/null
    "${PY[@]}" frames "$video" "$t0" "$OUT/test-video.log" "$OUT/frames" >/dev/null
}

run_shard() {
    local i="$1" tests="${SHARD_TESTS[$1]}" plain=() c
    [[ -n "$tests" ]] || return
    for c in "${CONFIG_LIST[@]}"; do [[ "$c" != Contrast ]] && plain+=("$c"); done
    [[ ${#plain[@]} -gt 0 ]] && run_tests "$i" "$((i + 1))-main" "$tests" "${plain[@]}"
    # Increase Contrast e o setare a simulatorului, deci Contrast rulează separat, după ce o pornim
    if [[ " ${CONFIG_LIST[*]} " == *" Contrast "* ]]; then
        xcrun simctl ui "${UDIDS[$i]}" increase_contrast enabled
        run_tests "$i" "$((i + 1))-contrast" "$tests" Contrast
        xcrun simctl ui "${UDIDS[$i]}" increase_contrast disabled
    fi
    # filmarea folosește testele din ReviewTour
    if [[ $i -eq 0 && -z "${NO_VIDEO:-}" && "$TOUR" == ReviewTour ]] && command -v ffmpeg >/dev/null; then run_video "$i"; fi
}

# --- turul -------------------------------------------------------------------------------------------------
log "Turul: ${CONFIG_LIST[*]} pe $N simulatoare"
SHARD_PIDS=()
for i in "${!UDIDS[@]}"; do run_shard "$i" & SHARD_PIDS+=($!); done
for pid in "${SHARD_PIDS[@]}"; do wait "$pid"; done

# --- rezultatele -------------------------------------------------------------------------------------------
RESULTS=()
for r in "$OUT"/result-[0-9]*.xcresult; do [[ -d "$r" ]] && RESULTS+=("$r"); done
[[ ${#RESULTS[@]} -gt 0 ]] || die "Niciun rezultat de test (vezi $OUT/test-*.log)"
if [[ ${#RESULTS[@]} -gt 1 ]]; then
    xcrun xcresulttool merge "${RESULTS[@]}" --output-path "$OUT/result.xcresult" >/dev/null \
        && rm -rf "${RESULTS[@]}"
else
    mv "${RESULTS[0]}" "$OUT/result.xcresult"
fi
xcrun xcresulttool export attachments --path "$OUT/result.xcresult" --output-path "$OUT/export" >/dev/null
"${PY[@]}" shots "$OUT/export" "$OUT/shots" >/dev/null && rm -rf "$OUT/export"

for i in "${!UDIDS[@]}"; do
    xcrun simctl spawn "${UDIDS[$i]}" log show --last 30m --style compact \
        --predicate 'subsystem == "ro.polygraph"' >"$OUT/app-$((i + 1)).log" 2>&1
done

"${PY[@]}" index "$OUT" "$Q" "$(($(date +%s) - START))" "$OUT/result.xcresult"
log "Gata: $OUT/index.md"
