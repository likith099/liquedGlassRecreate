# Development tracker

Updated: September 20, 2026. This is the current status and restart point. Public usage lives in [README](../README.md), design in [architecture](architecture.md), and historical test evidence in [verification](verification.md). Local `artifacts/` results are gitignored and may be absent in another checkout.

## Current handoff

- F13 scope preparation complete: `@likith99/react-native-adaptive-liquid-glass`, using the user-provided `likith99` npm settings scope. Public registry/access metadata, demo imports, lockfile, CocoaPods links, docs and standalone consumer paths are updated. Typecheck, 32 JS tests, and a fresh 77-file scoped consumer (autolinking, both bundles, both native builds) pass. [Scope record](../artifacts/scope-verification.json). Native identifiers/behavior are unchanged; npm authentication now confirms account `likithnmp` is an owner of organization `likith99`. User explicitly authorized publishing 0.1.0; publication is in progress. Remaining physical-device/performance gaps stay documented.

- September 20 review: B0–B3 features are implemented. B4 remains the active compatibility/release gate. The older installed simulator is **iOS 18.6**, not 18.5.
- Existing Claude changes retained: MIT files/metadata, RN peer range `>=0.81.0 <0.87.0`, iOS floor **15.1**, menu availability guards, deployment-target tab reconciliation, and example scene lifecycle. The 0.1.0 candidate is MIT licensed; the user has now authorized its first public npm release.
- B4 contract for this review: preserve public props and native iOS 26 action feedback; route older-iOS surfaces to UIKit system blur, use opaque material for Reduce Transparency/explicit forceFallback, retain ordinary older-iOS containers and other control fallbacks. No Android rendering change. Reuse the native dirty-prop gate to avoid rebuilding effects during unchanged layout.
- Acceptance: JS/type checks; older-iOS native material/reuse test; app surface interaction, controls, menus/toolbars, tabs, slider and accessibility checks on 18.6; affected surface/action checks on 26.5. Inspect screenshots and actual test results.
- The previous accessibility failure queried a UIKit segmented control on a React fallback; the test now branches by runtime. The unchanged menu dismissal test now passes on 18.6 and 26.5; the earlier failure was not reproduced.
- Current scoped package passed a fresh 77-file independent consumer including B4 blur changes ([record](../artifacts/package-smoke.json)). Archive SHA-256: `4baca972b97e140cfffdc0e264a945d3e4832e6693a7d51067719bb5cf40c5c0`. Refresh again only if package source changes before release.
- Performance architecture avoids JS-driven material frames and retains native controls, but no representative physical Release CPU/GPU/frame/memory profile exists. See [performance review](performance.md).
- Remaining acceptance: iOS 15–17 runtime, physical older devices, VoiceOver/TalkBack, RTL, iPad, settings transitions, oldest supported Android and Release/archive checks. Physical older-device work remains deferred; simulator testing is now requested.
- [September 20 evidence and source hashes](../artifacts/b4-review-verification.json). Current evidence: typecheck and 10 JS suites / 32 tests pass; 8 selected iOS 18.6 tests pass including the new blur/reuse test, surface touch, accessibility/large text, controls, tabs, slider and menu/toolbar batch. Four selected 26.5 tests pass; both xcodebuild commands exit 0. Android Debug build and focused control runtime checks pass.
- Immediate next action after this review: profile Release builds on representative physical devices, exercise Reduce Transparency/Motion transitions and broader device/accessibility gaps, then verify distribution builds at the final candidate and refresh the scoped consumer if source changes.

## B3 implementation contract

- API: retain existing props; grow default native button/menu/toolbar/tab heights by one line height per unit of system font scale (explicit style wins). Selectors keep their options side by side at every text size with wrapping labels; above 1.3 font scale iOS uses the React group instead of UISegmentedControl. Selected IDs and event rules stay controlled.
- Ownership: UIKit/SwiftUI and Material retain native rendering, touch, menus and tab navigation. Preserve native disabled behavior; UIKit has no public tab disabled-trait API, while Android exposes disabled semantics. React fallbacks expose individual actions, selected/disabled/busy states, and at least 48-point segment targets.
- Integration/checks: dedicated adaptive lab, JS state/layout regressions, iOS accessibility-tree/large-text checks and existing tabs regression; Android action/button/selector and adaptive-layout runtime checks. Inspect theme/large-text/RTL captures, then refresh the separate packed consumer on both platforms.
- Gaps: spoken VoiceOver/TalkBack, physical-device acceptance, older iOS and wider RN versions require explicit evidence; automation does not establish them. B3 results are historical; current release gaps are in the handoff above.

## Feature inventory

“Implemented” means the API and platform paths exist, not that every device/accessibility scenario is verified. Evidence applies to the recorded revision and scope.

| ID | Feature | Implementation | Evidence and remaining gaps |
| --- | --- | --- | --- |
| F01 | GlassView / GlassPressable | Implemented: native material and React children on iOS; standard fallback surfaces/pressables | iOS interaction and fallback checks; Android surface inspection. Full accessibility/settings review pending. |
| F02 | GlassContainer / optional merging | Implemented; off by default | iOS separate → merged → separate UI checks. Standard Android layout counterpart. |
| F03 | GlassActionCluster | Implemented; native material response and stretching glyphs | User accepted current tint/readability. Native regression and physical cancellation/hitch checks passed. Complete Android action-group runtime pass remains pending. |
| F04 | Native title GlassButton | Implemented; SwiftUI glass button, loading/disabled states; Android pressable counterpart | JS and iOS native/fallback interaction checks passed. Dedicated Android interaction coverage remains pending. |
| F05 | GlassSegmentedControl | Implemented; UIKit selector and controlled Android button group | JS and iOS selection/replacement/disabled checks passed. Dedicated Android interaction coverage remains pending. |
| F06 | GlassSlider | Implemented; UISlider / SeekBar, controlled values and gesture events | JS and iOS/Android runtime checks passed; packed-consumer build passed at the slider revision. More interruption/accessibility paths remain to test. |
| F07 | GlassMenuButton | Implemented; native menus on both platforms | Flat-menu regression passed again in B1. Earlier physical-iPhone result covers the flat revision. [API](menus.md), [earlier record](../artifacts/menu-verification.json). Standalone consumer now includes menus, toolbar, and tabs; see B2 package record. |
| F08 | Native toolbar | Implemented — B1 | Native builds and iOS/Android action, overflow, narrow layout, disabled, replacement, and open-menu dismissal checks passed. [API](toolbars.md), [B1 record](../artifacts/b1-verification.json). Physical acceptance/shared-background visual comparison pending. |
| F09 | Menu sections and submenus | Implemented — B1 | One submenu level plus sections; JS tree/disabled-ancestor checks and native iOS/Android hierarchy/controlled-checkmark tests passed. Full accessibility and older-device review pending. |
| F10 | Native tab bar | Implemented — B2 | Native builds and iOS/Android selection, disabled activation, badges, reorder/replacement, and remount checks passed. [API](tabs.md). B3 reviewed disabled-tab reporting: UIKit has no public API for it, so a disabled iOS tab still reports itself enabled. Android reports it. |
| F11 | Navigation integration examples | Implemented — B2 | React Navigation adapter and real demo verified: preventDefault, reselection, retained state, programmatic navigation, Android back history. No router dependency in the package. |
| F12 | Accessibility and adaptive layout | Implemented — B3 | Both platforms verified: iOS accessibility-tree and large-text checks, Android controls/large-dark/standard-light phases, JS regressions, captures inspected. One documented platform defect: iOS disabled-tab traits. Spoken VoiceOver/TalkBack, RTL, Reduce Motion/Transparency and physical devices remain unverified. |
| F14 | Older iOS support and backward compatibility | In progress — B4 | Floor is 15.1; deployment-target reconciliation is implemented. The 18.6 runtime exercises fallbacks; blur/menu/accessibility checks pass on 18.6; older-device acceptance remains B4. [Support matrix](compatibility.md). |
| F13 | Packaging and distribution | Packaged — final release gates open | 77-file archive installed into a fresh standalone consumer: typecheck, both bundles, autolinking and both native builds passed, without Expo or React Navigation. [Record](../artifacts/package-smoke.json). MIT licensed with repository, author and podspec metadata set. Not yet published; `npm publish` needs an npm login and an explicit go-ahead. RN range is 0.81–0.86; build evidence exists at 0.81.5 and 0.86.3. |

## Batches and acceptance

| Batch | Scope | Completion evidence |
| --- | --- | --- |
| B0 — existing controls and flat menus | F01–F07 implemented; known coverage gaps retained above | Existing evidence is reusable only for unchanged behavior. No blanket “fully tested” claim. |
| B1 — toolbars and menu hierarchy | Completed: F08–F09 | API/event tests, both native builds, toolbar activation, submenu selection, disabled states, dismissal, narrow overflow, and item replacement passed. [Evidence](../artifacts/b1-verification.json). |
| B2 — tab navigation | Completed: F10–F11 | Shared API/adapter tests, both native builds and navigation runtime checks; badge/selection visuals inspected. Physical acceptance and broad adaptive layout review remain B3. |
| B4 — older iOS support | F14: lower the floor to iOS 15.1, run the pre-26 fallback path, recheck menu dismissal, accept on a physical older device | Open. Scope and constraints in [compatibility](compatibility.md). Blocks the first publish, because the shipped floor decides which devices a consuming app can still reach. |
| B3 — release preparation | Completed: F12–F13 | Accessibility/layout pass on both platforms, affected regressions, user-reported large-text and tab-indicator fixes, and a refreshed 76-file tarball installed and built in a separate consumer. [Evidence](../artifacts/b3-verification.json). Remaining coverage is manual acceptance; publication requires separate user authorization. |

Per the user's latest instruction, complete each batch's code on both platforms before running tests/builds. Verification follows the implementation milestone; fix discovered failures and rerun only the affected checks. Dependency setup and reading platform APIs are development work, not test execution.

Optional backlog, outside these batches: intrinsic native sizing beyond the planned layouts, slider tick marks/neutral-track styles, per-corner shapes, declarative native scenes for cross-element morphing, wider React Native versions, and old-architecture support. Custom gesture physics is not planned; prioritize native behavior as requested. Investigate feasibility before promising optional features.

## Validation policy

| Change | Checks after implementation | Milestone checks |
| --- | --- | --- |
| Docs/tracking only | Local links and consistency | No app rebuild, test-suite run, or repack |
| TS API/events/state | Typecheck and relevant existing/meaningful new tests | Full inexpensive JS suite once stable; native tests if behavior crosses the bridge |
| Swift/Kotlin host or Fabric spec | Compile affected native platform; target changed events/state | Runtime checks for affected components on changed platforms; inspect visual changes |
| Shared material/touch behavior | Target reference/action regression and cancellation behavior | Physical-device comparison for perceptual changes; retain user acceptance separately |
| Packaging/autolinking/dependencies | Inspect generated registration and package contents | Reuse standalone-consumer harness at coherent candidate; build both platforms |

Use `npm run typecheck` and `npm test` for shared checks; native commands and harnesses are documented in [README](../README.md#checks). Reuse build caches and the existing Metro server on port 8093. Run codegen/Pods when native registration or dependencies require it, not as an automatic step for every edit.

Do not rerun a passing check unless subsequent changes affect its scope, a failure remains unresolved, or release verification requires a fresh result. Do not skip required checks to save tokens. Record failed attempts only when their cause helps future work, with the correction and final outcome.

## Durable decisions

| ID | Decision |
| --- | --- |
| D01 | No Expo Modules and no third-party glass runtime dependency. Reference modules are research only. |
| D02 | Use public native iOS rendering/interaction and standard Android counterparts. Do not promise private Apple effects. |
| D03 | Glass merging defaults off; explicit opt-in enables it. |
| D04 | Accepted action feedback: icons stay inside the native glass content; native touch lighting/stretch; default dark-mode black material tint at 0.65 alpha, clear in light mode, caller tint overrides. This shades resting and pressed material, not a numeric highlight-intensity control. No custom highlight/motion replacement. |
| D05 | Older-iOS device tests deferred by user; availability guards/fallbacks remain required. |
| D06 | Track each feature, batch related development, and reuse relevant verification to reduce repeated reading, builds, and testing. No token-savings percentage is measured or promised. |
| D07 | Superseded on September 18, 2026: the user chose MIT and public npm. The package carries an MIT LICENSE, repository/author metadata and a matching podspec. Publishing the first version still needs an explicit go-ahead and an npm login. Broader compatibility claims remain separate. |
| D08 | Finish both platform implementations, integration, documentation, and test code before executing batch verification. Then test the completed iOS/Android code and address failures. |

## Evidence index

- Current B3: [batch record, findings and hashes](../artifacts/b3-verification.json), iOS result `artifacts/B3Accessibility.xcresult`, logs `artifacts/b3-ios-tests.log` and `artifacts/b3-jest-full.log`. Android captures are still the September 14 ones and predate the script fix.
- Earlier B2: [batch record and hashes](../artifacts/b2-verification.json), [Android interaction record](../artifacts/b2-android-verification.json), iOS results `artifacts/B2TabsBehaviorTests.xcresult` and `artifacts/B2TabsBadgeSnapshot.xcresult`.

- Earlier B1 verification: [batch record and source hashes](../artifacts/b1-verification.json), [Android interaction record](../artifacts/b1-android-verification.json), iOS result `artifacts/B1ToolbarMenus.xcresult`.
- Earlier flat-menu verification: [menu record](../artifacts/menu-verification.json), iOS results `artifacts/NativeMenuIOS.xcresult` / `NativeMenuDevice.xcresult`. Android's `menu-android-verification.json` is refreshed by later flat regression runs.
- Accepted action behavior: [feedback record](../artifacts/action-feedback-verification.json); details under “Accepted interaction baseline” and “Native neutral tint” in [verification history](verification.md).
- Standalone consumer: [package smoke record](../artifacts/package-smoke.json). Compare its archive hash with the batch record; the path is reused.
- Latest full JS suite: 10 suites / 32 tests pass in the September 20 review (`artifacts/b4-review-jest.log`); typecheck also passes.
- Current tarball: `artifacts/likith99-react-native-adaptive-liquid-glass-0.1.0.tgz`. Compare its hash against `package-smoke.json` before reusing evidence. Older unscoped archives are historical.

## B3 build and runtime lessons

- iOS 27 hard-traps an app that has not adopted the UIScene lifecycle. The demo used the old `UIApplicationDelegate` window pattern with no `UIApplicationSceneManifest`, which iOS 26 only reported as a runtime issue, so it ran there and every simulator check passed. On iOS 27 it raised `EXC_BREAKPOINT` inside `__UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption` during scene creation, before any UI, so the app sat on the splash screen. The demo now declares a scene manifest and a `SceneDelegate` that owns the window and starts React Native into it. This is the example app, not the package; a consumer app on iOS 27 must adopt scenes itself.
- Reproduce device-only crashes on a matching simulator runtime first. The iOS 27.0 simulator reproduced this exactly and made it debuggable, where the device gave no synced crash report and `devicectl --console` returned nothing.

- Debug builds on a physical iPhone need Metro's address, not `localhost`. The demo's AppDelegate forced `jsLocation = "localhost:8093"`, which on a device points at the phone, so the bundle never arrived and the app sat on the splash screen. React Native's bundling phase writes the Mac's address into `ip.txt` for Debug device builds; `packagerLocation()` now reads it and keeps port 8093, and the simulator still uses localhost. Mac and device must share a network. A Release build embeds the bundle and needs no Metro, which suits device acceptance runs.

- This workspace can run a stale test bundle: `build-for-testing` against an iOS 26.5 destination wrote a `iphonesimulator27.0` xctestrun beside the older 26.5 one, and `test-without-building` then ran the previous day's binary. Reported failure line numbers matched superseded source, and explicitly installing the app and runner did not help. Use one `xcodebuild test` invocation and confirm line numbers match the current file before believing a failure.
- `XCUIElement.isHittable` is false for a disabled control, so it cannot scroll one into view. Check frame containment instead, and wait for a pushed screen to mount before scrolling — an early probe followed by one-directional swipes scrolls past anything near the top of a scroll view.
- UIAutomator clips bounds to the window. A control scrolled halfway in reports a short box sitting on the fold and its children can vanish from the dump, so a reveal helper must require real clearance rather than a nonzero height.
- Check the SDK headers before publishing native accessibility metadata. `UITab` conforms only to `UIAccessibilityIdentification`; assignments to undeclared accessibility properties compile through the informal `NSObject` category and silently do nothing.
- The Android emulator needs several GB free and fails with a plain disk-space error. Below about 5 GB free RAM it silently falls back to software rendering and wedges System UI into an ANR; pass `-gpu host -memory 2048` and shut the iOS simulators down first.
- React Native ignores the developer force-RTL setting, and a Play Store emulator image cannot change the system locale without root. Per-app locales through `cmd locale` did not mirror this app either. Exercise RTL on a rootable google_apis AVD or a physical device.

## B1 build lessons to reuse

- The original Xcode workspace read stalled in NSFileCoordinator. A temporary `artifacts/B1Validation.xcworkspace` containing absolute references to the same app and Pods projects built and tested successfully with the existing DerivedData. No signing or source project settings were changed. Use the normal workspace first; the temporary workspace is a local diagnostic workaround.
- Embedded Android Toolbar needs a host-width action budget and a forced posted native measurement after menu changes during layout. A request issued inside onLayout can otherwise be cleared before new action children receive bounds. Keep the toolbar instance; rebuild its item list only when configuration or width changes.
- UIAutomator can report a null root without failing its command. The shared helper retries and requires a fresh dump; never reuse stale XML. The demo's timed replacement allows 20 seconds for automation to open the menu. Targeted follow-up modes avoid repeating the unaffected flat regression.

## B2 build and runtime lessons

- Preserve Android menu items for metadata-only updates. Rebuilding on badge changes disturbed the native active indicator; retaining items fixed the inspected result.
- Modern UIKit tabs need UITab.isEnabled (iOS 18.4+); native disabled appearance/tap blocking work, but XCTest's enabled property is unreliable here. Test activation and event counts; retain VoiceOver announcements as an explicit gap.
- One simulator run used an older loaded test despite a rebuilt binary. Build-for-testing, explicitly install the app and runner, then test-without-building when diagnostic changes fail to appear. Do not infer current behavior from stale runs.
- Disable compiler indexing and limit parallel jobs when disk pressure prevents Xcode index writes. A fresh focused iOS capture resolved an incomplete repeated screenshot; inspect exported artifacts before claiming visual success.
- Standalone consumer reuses its independent build cache through ALG_CONSUMER_DIR and installs a hash-named tarball to prevent reuse of older same-version file dependencies.

## Updating this tracker

At the start of a batch, mark its rows in progress and write the immediate next action in Current handoff. On completion, update implementation status, link concise evidence, and retain any untested cases. Keep one current handoff rather than appending repeated session summaries. Update API docs when public behavior changes; append to verification history only for meaningful new results or regressions. Read historical logs only when a specific unresolved issue requires them.
