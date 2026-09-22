# Next-release acceptance

The public 0.1.0, 0.1.1 and 0.1.2 releases exist. This matrix defined acceptance for
0.1.2, without claiming that earlier releases passed it.
The source of truth for publish eligibility is the tracked
[`release/acceptance.json`](../release/acceptance.json), not local agent notes.

## Release integration

The owner selected an **iPhone-first 0.1.2 release** and subsequently authorized
SwiftUI runtime testing, broad regression verification and publication once passing.
This supersedes the earlier no-testing instruction. Use installed simulators only;
VoiceOver and unavailable older physical devices remain deferred.

The tag workflow requires matching package version, tag and reviewed-source digest,
plus completed `ios-source-review`, `ios-swiftui-runtime`, `ios-fallback-runtime`
and Release `packed-consumer` entries. Schema 2 uses `scope: "iphone-first"`.
Remaining manual/device categories may have documented owner deferrals; these are
not passes. Each entry needs reviewer, date, summary and durable evidence. Current
results are in [0.1.2 verification](../release/verification-0.1.2.md).

Shared CI checks and both native Release build jobs must still succeed before OIDC
publishing starts. They run on GitHub after a tag push, following local candidate verification. Branch workflow dispatch cannot publish. The
trusted-publisher identity and workflow filename remain unchanged. 0.1.2 passed
these hosted gates and was published on September 22, 2026; see the verification report.

Use `node scripts/check-release-acceptance.mjs --print-digest` after final source
changes and update the acceptance record. This identifies reviewed source, not
executed test coverage. A changed source digest, unmatched tag/version, missing
source review or unexplained pending category blocks publication. Local evidence
must be a committed report outside `artifacts/` and `.agent/`, or a durable HTTPS
result. The script checks record completeness, not the truth of a test result.

## Deferred verification plan

| Record key | Future exercise and evidence (deferred for 0.1.2) |
| --- | --- |
| `ios-current-profile` | Physical current iPhone, Release, 3 repeated interaction runs; CPU, memory, hitches/frame-time results and an Instruments rendering trace. Record model, OS, refresh rate, thermal state, workload and comparison against opaque surfaces. |
| `ios-older-profile` | Same Release workload on representative older physical iPhone using blur. |
| `android-profile` | Same workload on lower-end physical Android; profileable Release, Perfetto/Android Studio trace and memory after repeated navigation. |
| `ios-15-17-runtime` | An actual iOS 15–17 runtime: launch, blur, forced opaque/none, native controls, rejected selection, menus, tabs, slider cancellation, foreground/background. 18.6 does not satisfy this row. |
| `android-minimum-runtime` | Lowest supported host Android API (demo: 24), with menus, tabs, slider and disabled/rejected interactions. |
| `voiceover` (deferred) | User explicitly deferred this work. Not a blocking requirement for the next release; no spoken VoiceOver compatibility claim. Existing accessibility behavior is retained. |
| `talkback` | Physical Android: equivalent focus/activation/slider/menu tests with TalkBack; record spoken output. |
| `rtl-ios` / `rtl-android` | Genuine RTL app/system locale, cold launch and `adaptive-environment` reporting RTL; inspect order, navigation, slider direction and wrapped labels. A force-RTL setting with an LTR app is not a pass. |
| `ipad` | Portrait/landscape, tab layout and selection, menus/popovers, large text and narrow multitasking window. Simulator rotation alone is partial coverage. |
| `ios-accessibility-settings` | While mounted: Reduce Transparency and Reduce Motion on/off, light/dark and largest text; readable opaque material, controlled state retained, package animations suppressed. Restore original settings. |
| `android-accessibility-settings` | Light/dark, largest font/display scale and disabled animations while mounted; state and targets retained. Restore settings. |
| `ios-distribution` | Release archive, embedded JS, signed export/install and cold launch without Metro; validate distribution signing in the host app. An unsigned archive is only a build check. |
| `android-distribution` | Release AAB/APK, embedded JS, real upload/release signing, install and cold launch without Metro. The demo debug key is not Play Store acceptance. |
| `packed-consumer` | Fresh scoped tarball; autolinking, TypeScript, both production JS bundles and native Release builds in a separate consumer. Record archive hash. |

## Repeatable commands

Run these at a coherent release candidate and reuse build caches. The owner has
authorized the current verification pass; do not download new simulator runtimes.

```sh
npm run test:release-tools
npm run typecheck
npm test
node scripts/check-pack.mjs
# iOS 0.87 source-mode workaround, before building:
(cd example/ios && RCT_USE_PREBUILT_RNCORE=0 pod install)
npm run build:release:ios
# Set JAVA_HOME and ANDROID_HOME for your installation first:
npm run build:release:android
RCT_USE_PREBUILT_RNCORE=0 ALG_BUILD_CONFIGURATION=Release node scripts/verify-package.mjs
```

The native build scripts write logs and JSON results into `artifacts/`. The iOS
script produces an **unsigned** xcarchive. The Android script produces a Release
APK/AAB using the example's existing debug key. Both are useful build checks;
neither is signed distribution acceptance.

Discover current device IDs with `xcrun devicectl list devices` and `adb devices`.
For the physical Release baseline, use the existing signing team in Xcode and run:

```sh
xcodebuild -workspace example/ios/LiquidGlassLab.xcworkspace -scheme LiquidGlassLab \
  -configuration Release -destination 'platform=iOS,id=YOUR_DEVICE_ID' \
  -derivedDataPath artifacts/PhysicalReleaseDerivedData \
  -resultBundlePath artifacts/PhysicalReleaseProfile.xcresult \
  -only-testing:LiquidGlassLabUITests/GlassInteractionTests/testPhysicalReleaseInteractionProfile \
  -collect-test-diagnostics never -parallel-testing-enabled NO test
```

Use a new result-bundle path per run. If the test runner has no development profile,
supply the existing team with `DEVELOPMENT_TEAM=<team>` and allow Xcode to provision
it with `-allowProvisioningUpdates`. This does not change project signing settings.
The physical metric test skips simulator or
Debug configurations. Its CPU/memory/hitch measurements cover one action workload;
it does not substitute for a full scrolling/GPU/long-run-memory profile. Add an
Instruments **Animation Hitches**, **Time Profiler** or **Metal System Trace**
capture for those questions. Compare each display's actual frame budget, not only
an average; record regressions and inspect outliers before optimizing.

For iPad run `testIPadRotationAndTabLayout` on an iPad destination, followed by the
existing `testAdaptiveLargeText` and `testToolbarAndMenuBatch`. For 18.6 run the B4
fallback tests again when the React Native runtime changes. These supplement,
rather than establish, all of the future coverage above. For iOS RTL, run
`testActionClusterMirrorsLayoutDirection` and `testArabicLocaleLayoutAndSelection`.
For Android API 33+, install the example Release APK and run
`python3 scripts/verify-android-rtl.py`; it restores the original per-app locale.

Android's Release manifest enables shell profiling without enabling debug mode.
Use [Android's profileable Release workflow](https://developer.android.com/studio/profile/build-run-manually).
Apple explicitly recommends assistive-technology testing in addition to
[automated accessibility audits](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app).

## Current limits

Existing evidence covers the iOS 18.6 fallback simulator and iPad/iPhone 26.5
simulators; it does not prove execution on iOS 15–17. No physical older device or
new simulator is required for this release. Current candidate execution is recorded in the linked verification report. VoiceOver, TalkBack, further profiles, narrow iPad windows
and signed app distribution remain deferred without compatibility claims. No
store upload or npm publication occurs merely by preparing this record.
