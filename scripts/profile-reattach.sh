#!/usr/bin/env bash
# G1: Time Profiler over 10 re-attach cycles of 20 glass surfaces (testAcceptanceSurfaceProfile).
#   scripts/profile-reattach.sh <simulator-udid>
# Writes artifacts/b25-g1.trace and artifacts/b25-g1-profile.log.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; UDID="$1"; TRACE="$ROOT/artifacts/b25-g1.trace"
rm -rf "$TRACE"
xcrun simctl uninstall "$UDID" org.local.LiquidGlassLabUITests.xctrunner >/dev/null 2>&1 || true
NODE="${NODE:-/Users/likith_k/.nvm/versions/node/v24.15.0/bin/node}"
"$NODE" "$ROOT/scripts/run-ios-ui-tests.mjs" --simulator "$UDID" --result "$ROOT/artifacts/b25-g1.xcresult" --log "$ROOT/artifacts/b25-g1-profile.log" testAcceptanceSurfaceProfile &
TESTS=$!
for _ in $(seq 1 600); do grep -q 'profile-ready' "$ROOT/artifacts/b25-g1-profile.log" 2>/dev/null && break; sleep 0.5; done
xcrun xctrace record --template 'Time Profiler' --device "$UDID" --attach LiquidGlassLab --time-limit 18s --output "$TRACE" > "$ROOT/artifacts/b25-g1-xctrace.txt" 2>&1
wait $TESTS; echo "tests exit $?; trace $TRACE"
