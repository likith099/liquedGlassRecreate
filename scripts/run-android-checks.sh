#!/usr/bin/env bash
# Runs the Android verification scripts against the installed demo, each from a fresh launch.
#
#   scripts/run-android-checks.sh [check…]      e.g. scripts/run-android-checks.sh menu features
#
# Default: every check. Needs the demo installed on ANDROID_SERIAL (default emulator-5554) and
# python3 with Pillow; a debug build also needs Metro serving the example on port 8093 (a release
# build carries its JavaScript). ADB defaults to adb on PATH.
# ANDROID_LAUNCH_WAIT (seconds, default 8) is the pause after each launch; slow emulators need more.
# Emulator UI checks can stall on a slow frame, so each check gets one retry; a retry is reported.
# A failed attempt saves a screenshot, the UI tree and the error log lines next to its log.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export ADB="${ADB:-$(command -v adb || echo "$HOME/Library/Android/sdk/platform-tools/adb")}"
export ANDROID_SERIAL="${ANDROID_SERIAL:-emulator-5554}"
WAIT="${ANDROID_LAUNCH_WAIT:-8}"
checks=("$@")
[ ${#checks[@]} -eq 0 ] && checks=(menu toolbar tabs context-menu features slider accessibility rtl)
mkdir -p "$ROOT/artifacts"
adb_() { "$ADB" -s "$ANDROID_SERIAL" "$@"; }
adb_ reverse tcp:8093 tcp:8093 >/dev/null 2>&1 || true

failed=()
for check in "${checks[@]}"; do
  for attempt in 1 2; do
    adb_ logcat -c >/dev/null 2>&1
    adb_ shell am start -S -n com.liquidglasslab/.MainActivity >/dev/null
    sleep "$WAIT"
    base="$ROOT/artifacts/android-$check-$attempt"
    log="$base.log"
    if python3 "$ROOT/scripts/verify-android-$check.py" > "$log" 2>&1; then
      if [ "$attempt" -eq 1 ]; then echo "PASS $check"; else echo "PASS $check (on retry)"; fi
      break
    fi
    echo "FAIL $check (attempt $attempt):"
    grep -v 'null root node' "$log" | tail -5
    adb_ exec-out screencap -p > "$base.png" 2>/dev/null
    adb_ shell uiautomator dump /sdcard/alg-failure.xml >/dev/null 2>&1 && adb_ exec-out cat /sdcard/alg-failure.xml > "$base.xml"
    adb_ logcat -d -v time AndroidRuntime:E ReactNativeJS:V ReactNative:W '*:S' > "$base.logcat.txt" 2>&1
    [ "$attempt" -eq 2 ] && failed+=("$check")
  done
done

if [ ${#failed[@]} -gt 0 ]; then
  echo "Failed: ${failed[*]}"
  exit 1
fi
echo "All Android checks passed."
