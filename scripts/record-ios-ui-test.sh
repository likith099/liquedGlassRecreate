#!/usr/bin/env bash
# Records the simulator screen while UI tests run, for frame-by-frame acceptance analysis.
#
#   scripts/record-ios-ui-test.sh <simulator-udid> <name> <test…>
#
# Writes artifacts/<name>.mp4, artifacts/<name>.log (xcodebuild output with ALG-MARK /
# ALG-RECT lines) and artifacts/<name>.start (epoch seconds of the first recorded frame).
# Analyse with scripts/trace-glass.py.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UDID="$1"; NAME="$2"; shift 2
VIDEO="$ROOT/artifacts/$NAME.mp4"; LOG="$ROOT/artifacts/$NAME.log"; START="$ROOT/artifacts/$NAME.start"
STDERR="$ROOT/artifacts/$NAME.recorder.txt"
mkdir -p "$ROOT/artifacts"; rm -f "$VIDEO" "$START"
# A stale installed runner can execute old test code after a rebuild.
xcrun simctl uninstall "$UDID" org.local.LiquidGlassLabUITests.xctrunner >/dev/null 2>&1 || true
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$VIDEO" 2> "$STDERR" &
RECORDER=$!
for _ in $(seq 1 100); do grep -q 'Recording started' "$STDERR" 2>/dev/null && break; sleep 0.05; done
python3 -c 'import time; print(f"{time.time():.4f}")' > "$START"
NODE="${NODE:-$(command -v node || echo /Users/likith_k/.nvm/versions/node/v24.15.0/bin/node)}"
"$NODE" "$ROOT/scripts/run-ios-ui-tests.mjs" --simulator "$UDID" --result "$ROOT/artifacts/$NAME.xcresult" --log "$LOG" "$@"
STATUS=$?
kill -INT "$RECORDER" 2>/dev/null; wait "$RECORDER" 2>/dev/null
echo "Recording: $VIDEO (start $(cat "$START")), tests exit $STATUS"
exit $STATUS
