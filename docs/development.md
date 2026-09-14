# Development tracker

Updated: September 13, 2026. This is the current status and restart point. Public usage lives in [README](../README.md), design in [architecture](architecture.md), and historical test evidence in [verification](verification.md). Local `artifacts/` results are gitignored and may be absent in another checkout.

## Current handoff

- Latest implemented and runtime-verified batch: `B2` — GlassTabBar and React Navigation integration (`F10`–`F11`). Both platform implementations, demo, docs, and test code were completed before executing tests/builds, as requested.
- Delivered: controlled native tabs, stable IDs, native icons, numeric/dot badges, disabled tabs, reselection, rejected-selection reconciliation, reordering/replacement, and controller lifecycle. iOS uses contained UITabBarController / UITab on iOS 18.4+; Android uses Material BottomNavigationView 1.13.0. The screen owns safe-area spacing.
- Integration: demo-only React Navigation 7 adapter uses route keys and preventable tabPress events. The router owns retained screen state, programmatic navigation, and Android back history. The library does not require React Navigation or Expo.
- Evidence: TypeScript; 8 suites / 28 JS tests; full iOS simulator navigation test and focused badge screenshot test; Android full navigation checks. Final badge/indicator screenshots inspected on both platforms. Final packed-consumer refresh is being completed before handoff.
- Next batch: `B3` — accessibility/adaptive layout and remaining Android control coverage, then candidate packaging checks. Prioritize native disabled-tab announcements: UIKit 26.5 dims and blocks disabled tabs but XCTest reports them as enabled. Functional tap/event rejection passes; VoiceOver behavior remains unverified.
- Physical-device acceptance of tabs/toolbars, full accessibility/settings/RTL/large-text coverage, and wider RN compatibility remain pending. Older-iOS physical testing is deferred by the user; retain availability checks.
- Supported/tested scope remains React Native 0.86 / Fabric, no Expo Modules. Local unpublished 0.1.0; no publication or license choice authorized. The accepted action-cluster feedback and default-off merging are unchanged.

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
| F10 | Native tab bar | Implemented — B2 | Native builds and iOS/Android selection, disabled activation, badges, reorder/replacement, and remount checks passed. [API](tabs.md). Native disabled-tab accessibility reporting needs B3 review. |
| F11 | Navigation integration examples | Implemented — B2 | React Navigation adapter and real demo verified: preventDefault, reselection, retained state, programmatic navigation, Android back history. No router dependency in the package. |
| F12 | Accessibility and adaptive layout | Planned — B3 | VoiceOver/TalkBack, large text, Reduce Motion/Transparency, light/dark themes, and interrupted interactions. |
| F13 | Packaging and compatibility | Partial — B3 | B2 standalone consumer covers all exports without Expo or React Navigation. Recheck for later candidate changes. License/source metadata and wider RN support remain undecided. |

## Batches and acceptance

| Batch | Scope | Completion evidence |
| --- | --- | --- |
| B0 — existing controls and flat menus | F01–F07 implemented; known coverage gaps retained above | Existing evidence is reusable only for unchanged behavior. No blanket “fully tested” claim. |
| B1 — toolbars and menu hierarchy | Completed: F08–F09 | API/event tests, both native builds, toolbar activation, submenu selection, disabled states, dismissal, narrow overflow, and item replacement passed. [Evidence](../artifacts/b1-verification.json). |
| B2 — tab navigation | Completed: F10–F11 | Shared API/adapter tests, both native builds and navigation runtime checks; badge/selection visuals inspected. Physical acceptance and broad adaptive layout review remain B3. |
| B3 — release preparation | F12–F13 plus remaining Android checks | Accessibility/layout pass, affected regressions, refreshed tarball and separate consumer install/build on both platforms. Record deferred device/version coverage explicitly. Publication requires separate user authorization. |

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
| D07 | Local package only; publishing, licensing, and broader compatibility claims are separate decisions. |
| D08 | Finish both platform implementations, integration, documentation, and test code before executing batch verification. Then test the completed iOS/Android code and address failures. |

## Evidence index

- Earlier B1 verification: [batch record and source hashes](../artifacts/b1-verification.json), [Android interaction record](../artifacts/b1-android-verification.json), iOS result `artifacts/B1ToolbarMenus.xcresult`.
- Earlier flat-menu verification: [menu record](../artifacts/menu-verification.json), iOS results `artifacts/NativeMenuIOS.xcresult` / `NativeMenuDevice.xcresult`. Android's `menu-android-verification.json` is refreshed by later flat regression runs.
- Accepted action behavior: [feedback record](../artifacts/action-feedback-verification.json); details under “Accepted interaction baseline” and “Native neutral tint” in [verification history](verification.md).
- Standalone consumer: [package smoke record](../artifacts/package-smoke.json). Compare its archive hash with the batch record; the path is reused.
- Latest full JS suite: 8 suites / 28 tests passed in B2. Subsequent corrections affected native tab state/layout and the iOS test harness; shared TS/JS behavior is unchanged.
- Local tarball: `artifacts/react-native-adaptive-liquid-glass-0.1.0.tgz`; its current hash is in the B2 record. The path is reused, so compare hashes before attributing older test evidence to it.

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
