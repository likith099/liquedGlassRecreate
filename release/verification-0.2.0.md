# 0.2.0 release verification

October 22, 2026. **Published 0.2.0**, tagged `v0.2.0` at commit `d92495a`.
The [release workflow](https://github.com/likith099/liquedGlassRecreate/actions/runs/39793774837)
completed successfully. [npm](https://www.npmjs.com/package/@likith99/react-native-adaptive-liquid-glass/v/0.2.0)
reports `latest: 0.2.0`; the registry archive is byte-identical to the locally tested archive.
The owner authorized completing the 0.2.0 handoff, regression checks and publication.

## Scope

The release adds grouped and morphing controls, shared header controls, badges, native
navigation headers, progressive scroll edges, configurable hard bands, search integration and
tab improvements. The final batch makes the hard boundary wait for title collapse, consolidates
the demo into Components and Navigation & headers, and fixes asymmetric Select/Edit morphs.
The package remains bare React Native with public native APIs and no reference-glass runtime.

The Select/Edit fix retains one SwiftUI glass shape per slot. Previously each label had a
different glass identity, allowing an outgoing Edit capsule to disappear into the adjacent Share
control before Select emerged. Only the glyph now blurs/fades; the persistent material resizes
with the same spring in both directions. Older iOS and Android use their existing control paths.

## Completed checks

- Workspace TypeScript passes. Jest: 24 suites/145 tests in the initial run plus the corrected
  App suite's two tests, 25 suites/147 tests covered. Release-tool tests: 11 passed.
- iOS 26.5, iPhone 17 Pro Max simulator, Debug: 67 distinct tests pass, with four explicit
  platform/device skips. Evidence spans the targeted R1/R2 runs, the interrupted initial broad
  run, its continuation and the affected six-test B35 rerun. The interrupted run is not a suite
  pass. Gallery changes required fixture corrections for scrolling, outside-menu taps and the
  accessibility-size section picker; all affected iOS 26 tests subsequently passed.
- B35 targeted simulator run: six tests, zero failures (245.736 seconds): shared header controls,
  header pairing scenarios, motion, morph badges, largest text and menu-panel placement.
- Physical iPhone 13 Pro, iOS 26.7.1, Release: native build succeeds. Hard-boundary test passes
  all six combinations of native/morph and large-below/large-in-bar/compact titles with a pinned
  filter (143.247 seconds). Boundary brightness is 0 at the top and 48 when collapsed. Band
  presets and blur check pass (51.962 seconds).
- Physical recording: Select → Edit takes approximately 0.530 seconds (24 sampled frames),
  Edit → Select approximately 0.541 seconds (35 frames). Glass remains present in every sampled
  frame; trailing-edge drift is 0 points. Widths reverse between 77.33 and 58.67 points. The
  original owner recording fails the continuity check. Times include action dispatch and are
  approximate; they do not establish exact system-app equivalence.
- Physical hard-boundary recording: 73–81 sampled frames per title mode during each collapse;
  no missing-line frames after appearance in any of the six modes.

- Physical shared-header rerun passes (39.454 seconds), including swipe-back with a 0.2 second
  hold beyond the completion threshold. Its recording contains glass in all 53 sampled swipe
  frames, with 0 trailing-edge drift. Standalone motion also passes (45.353 seconds), including
  a 500 ms JavaScript stall. The free morph recording has glass in every sampled frame, width
  43.33→77.33 points and 0 trailing-edge drift. Initial physical swipe failure was a cancelled
  synthetic navigation gesture, confirmed in the video; the package did not need gesture changes.
  Evidence: `B35DeviceSwipe`, `b35-phone-swipe-final.json`, `b35-phone-morph-free.json`.

- iOS 18.6 subset: ten tests passed (two initial header-control checks, eight affected checks
  after correcting the gallery selector query). Covers native blur/reuse, surface interaction,
  progressive header, search/title transitions, hard-boundary timing and band presets. The
  initial button-only query did not match the fallback radio element; the cancelled run is
  not a suite pass. Evidence: `R1R2Older` (partial), `R1R2OlderFixed` (8/8, 242.633 s).
- Standalone packed consumer, Release: independent dependency tree, both platform bundles,
  TypeScript, native iOS build and native Android build pass. Neither Expo nor React Navigation
  is installed in that consumer. Package inspection passes: 499 files, 1,194,056 unpacked bytes.
  Archive SHA-256: `df418035ebfd49ddcc7603bda2ef22acd784c7f3dd0b44553c472ca270497c0b`.
  Evidence: `r1-r2-packed-release.log`, `package-smoke.json`, `r1-r2-check-pack.log`.

- Android demo Debug build passes (7 seconds), Pixel 10 Pro XL emulator, Android 17/API 37.
  All 15 verification scripts have passing results: menu, toolbar, tabs, context-menu,
  conversation-menu, menu-panel, features, slider, accessibility, RTL, upgrade, acceptance,
  navigation, scroll-header and header-review. The initial run passed 13 and failed two fixture
  assumptions (menu-panel bubble below the fold, presence tap on inverted clipped bounds).
  Corrected menu-panel/upgrade/features rerun passes all three, shell exit 0. Features and slider
  also passed their initial runner's retries. No Android production fix beyond R1 was needed.
  Large-font picker and clipped-node visibility helpers follow the consolidated demo layout.
  Evidence: `r1-r2-android-build.log`, `r1-r2-android-full.log` (initial exit 1),
  `r1-r2-android-fixes.log` (exit 0), per-check Android logs and JSON results.

Local evidence (ignored, not shipped): `r1-r2-ios2`, `r1-r2-fixes`, `R1R2Full` (cancelled),
`R1R2Continue`, `b35-morph`, `B35Device`; `b35-phone-push.json`, `b35-phone-return.json`,
`b35-phone-hard-summary.json`, and `b35-device-attachments/`. Recordings with timestamp/decode
warnings are excluded from timing claims; the quoted animation evidence is the physical
device's retained XCTest video.

## Remaining manual acceptance

Physical older-iOS performance, physical Android performance, an actual iOS 15–17 runtime,
minimum Android API, iPad, spoken VoiceOver/TalkBack, complete mounted accessibility-setting
switching and store-distribution signing remain documented deferrals in `acceptance.json`.
Automated semantic/RTL and font/theme checks are partial evidence, not complete manual acceptance.
Owner visual acceptance of the updated demo and animation is not inferred from tests.

## Release identity

The standalone consumer tested archive SHA-256 is recorded above. The final reviewed source
is identified by `release/acceptance.json`. No production source change followed native verification;
subsequent edits corrected test helpers and documentation.

Reviewed source digest: `e5872404fb5e1a1142838a19e0b29efaf46b86996558567d2382e7c8c488d6d1`.
The npm SLSA provenance statement names `.github/workflows/release.yml`, `refs/tags/v0.2.0`
and source commit `d92495a6d1fb2724588fb05c6c74c5d1f97f4bed`. Its SHA-512 subject matches the
downloaded registry archive; the SHA-256 is the tested archive hash above.
Local registry evidence: `npm-0.2.0-metadata.json`, `npm-0.2.0-attestations.json`,
`npm-published-0.2.0.tgz`.
