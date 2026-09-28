# 0.1.3 verification

**Status (September 28, 2026): release candidate verified on `main`. Not yet published.** The
sections after this summary are the dated history of how the candidate was built; where they say
something is untested or open, this summary supersedes them.

## Candidate

- Source: version 0.1.3 as merged in pull request #1 (`8f59ce5`), plus the acceptance branch: the README rewrite, new docs pages and the expanding-pill shadow fix.
- Reviewed source digest: `d0aa22f786aa398366847dcf863e3f9909ebae1db53fd156d30a4f4ffa834f8a`.
- Contents: the consumer review (R1–R21 in the shared review tracker), new components
  (`GlassIconButton`, `GlassContextMenu`, `GlassExpandingTabs`, `GlassSearchField`,
  `GlassScrollEdge`, `GlassToast`, `GlassBadge`), tab image sources and per-tab colours on both
  platforms, and the iOS 26 toolbar dismissal fix. See `packages/liquid-glass/CHANGELOG.md`.
- Decisions: peer ranges stay `react-native >=0.81.0` / `react >=19.0.0` with no upper bound (R15).
  Tab minimize-on-scroll and a tab long-press event were dropped (R20). The intermittent
  first-tap report (R3) is deferred past 0.1.3.

## Evidence

| Check | Result |
| --- | --- |
| TypeScript, Jest | Clean; 20 suites / 92 tests and 6 tier snapshots (glass, blur, solid × light, dark). |
| Package contents | `check-pack` passed: 317 files. |
| Packed consumer (Release) | Passed on the final source: 317-file archive, SHA-256 `02a19f6104864592e791561587e20007b6aa7356bc9aabc2ef941091e8edeba5`; consumer TypeScript, both production bundles, iOS and Android native Release builds. No Expo or navigation dependency. (An earlier run from `8f59ce5`, before the README and pill changes, also passed.) |
| iOS 26.5 simulator (iPhone 17 Pro Max) | Tab artwork and tints, visual tiers, tab lifecycle and first tap, tab navigation, drag lens; icon buttons and programmatic menus; toolbar dismissal (zero opaque frames in 5 recorded dismissals); context menu; badges, segments and FAB; search, toast and scroll edge; expanding pills; SwiftUI cluster merging and RTL; adaptive accessibility; slider. All passed. |
| iOS 18.6 simulator (iPhone 16 Pro Max) | Tab artwork and tints, visual tiers (blur), tab lifecycle, tab navigation, expanding pills, badges, context menu and fallback, toolbar and menus. All passed. |
| Android 36 emulator (Pixel 10 Pro XL), debug and release builds | Menus, toolbar, tabs, context menu, the 0.1.3 features (icon buttons, segments, badges, pills, search, toast, tab images and colours), slider, accessibility (large text, dark) and real-locale RTL. All passed. |
| GitHub Actions on the candidate | [Run 36371512636](https://github.com/likith099/liquedGlassRecreate/actions/runs/36371512636): iOS device tests on an iOS 26.5 simulator and all eight Android checks on an API 35 emulator (release build), every Android check first time. CI (typecheck, Jest, pack check) passed on the pull request and again on `main` after the merge. |

Bugs found during verification and fixed before this candidate: the Android context menu never
opened from a long press on its content (React Native views claimed the touch), the Android search
field capitalised queries, and Android pills without `androidIcon` were silently empty (now a
development warning). While taking the README screenshots, the iOS 26 pill row turned out to clip
the glass shadow into a hard grey band; the row no longer clips, and the pill tests passed again on
26.5 and 18.6.

## Not established

Physical-device profiling, spoken VoiceOver and TalkBack, iOS 15–17 runtimes, the Android minimum
API, iPad beyond the simulator checks, and signed store distribution remain documented deferrals in
`release/acceptance.json`. Emulator and simulator results are not device acceptance.

Each simulator and emulator result above is the latest run of that test. The platform code each one covers has not changed since, and the GitHub run exercised the final code on both platforms.

## History

## Change

Adds `GlassContextMenu` around React content. UIKit owns long-press recognition,
the retained-content preview and native menu presentation. Android owns long-click
and its anchored PopupMenu, leaving the content in place. Existing menu buttons,
toolbars and action clusters keep their public behavior. Fabric's ALGMenu host now
mounts React children; consumers must rebuild both native apps.

Menu tree validation, controlled checkmarks and stale-selection guards are shared
with existing menus. No private APIs, Expo dependencies, custom movement physics,
or new package runtime dependencies were introduced. UIKit's context-menu APIs
predate the supported iOS 15.1 floor. Menu placement and appearance remain under
system control; Android does not simulate the iOS lift.

## Candidate checks

- TypeScript: passed.
- JavaScript: 12 suites / 36 tests passed, including content retention and invalid,
  removed and disabled action rejection. `artifacts/b6-jest-fallback.log`.
- Release tooling: 10 tests passed. `artifacts/b6-release-tools.log`.
- Package contents: passed, 80 files, no build output.
- Android Debug build: passed before the September 27 scope correction. Runtime
  attempts did not pass; the test could not find the message target after navigation.
  No Android runtime or visual acceptance is claimed.
- iOS simulator build passed. Native context-menu and shared plain-fallback tests
  passed on iPhone 17 Pro Max / iOS 26.5 (62.529s and 51.970s respectively).
  Existing menu/toolbar regression passed (146.022s); overall Xcode test exit 0.
  Native and fallback screenshots were visually inspected: the message is readable
  and retained above both menus. Screenshots: `docs/images/context-menu.png` and
  `docs/images/context-menu-fallback.png`.
  Log: `artifacts/b6-ios-fallback-tests.log`, result: `artifacts/B6ContextFallback.xcresult`.
- iOS 18.6 / iPhone 16 Pro Max: native and shared fallback tests passed (57.477s,
  47.930s), Xcode test exit 0. `artifacts/b6-ios-older-tests.log`,
  `artifacts/B6ContextOlder.xcresult`. Light-mode screenshots inspected; both retain
  readable content. Current-iOS screenshots above cover dark mode.
- Total scoped native UI tests: five passed. Both context-menu tests exercise
  tap vs long press, selection, disabled action/trigger, controlled saved state,
  submenu, outside dismissal, replacement and unmount. These do not establish
  physical-device acceptance, spoken accessibility or arbitrary nested gestures.
- Reviewed source digest: `ebbc0c9c601a9434a09e32c2dcc98e521c337179afabf6e94a9c554790ade38f`.
- TypeScript, package contents, local documentation links and whitespace checks passed.
  No full standalone consumer or new Release archive was built under the revised
  simulator-only/storage-constrained scope. `release/acceptance.json` still records
  0.1.2 and does not authorize publishing this candidate.

## Toolbar dismissal fix (September 27, after the checks above)

On iOS 26, `GlassToolbar` Sort/ellipsis controls showed an opaque disk for about
a second after a menu closed: 0.74 s and 0.96 s measured on 26.5. A standalone
UIToolbar shows the dismissal morph through a portal in its hosted item glass,
and that glass renders opaque until UIKit finishes the morph. The iOS 26 glass
path now uses `UIButton.Configuration.glass()` buttons that own their menus,
laid out outside the UIToolbar. Shared glass uses one `UIGlassEffect` capsule.
Fallback, Reduce Transparency and pre-26 keep the standard UIToolbar. The public
API is unchanged; Android is unchanged.

- Recorded `testToolbarDismissalMaterial` on 26.5 passed: zero opaque frames across
  five dismissals, individual and shared modes. Resting appearance compared to
  baseline. `artifacts/b6-dismiss-baseline.*`, `artifacts/b6-dismiss-fixed2.*`.
- `testToolbarAndMenuBatch` passed on 26.5 (147.4 s) and 18.6 (107.9 s);
  `testAdaptiveLargeText` passed on 26.5. `testAdaptiveControlAccessibility` fails
  at its tab-bar reveal with and without this change (pre-existing, open).
- The source digest above predates this change; recompute it for acceptance.
  Owner visual acceptance of the toolbar is pending.

## Consumer review, phase 1 (September 27)

The review's P0 tab-bar bugs are fixed, along with the small surface APIs. See
`packages/liquid-glass/CHANGELOG.md`.
- **Tab bar:** selection waits for attachment and uses the tab UIKit holds. The legacy array is never
  installed over an adopted `UITab` list. Images come from cached artwork. The standard bar
  appearance applies below 26.
- **Surfaces:** `GlassPressable` gains `interactive` and `colorScheme`, every component's ref is
  typed `GlassHostRef`, and a development warning covers `spacing` without `mergingEnabled`.

Checks:
- `testTabBarLifecycleAndFirstTap` passed on 26.5 and 18.6, and `testNativeTabNavigationBatch`
  passed on 26.5.
- Jest: 13 suites / 57 tests passed; typecheck is clean.
- Screenshots were inspected for the selected-image fix.
- R3 (intermittent dropped first tap) is not reproduced and remains open. The inset-guidance
  change is deferred.

## Consumer review, phase 2 (September 27)

- Adds `GlassIconButton` (glass on iOS 26, gray below 26 and under Reduce Transparency, a ripple
  circle on Android).
- Adds `onOpen` / `onClose` and a `GlassMenuHandle` ref with `open()` on menu buttons.
- `testIconButtonsAndProgrammaticMenu` passed on 26.5 and 18.6; the toolbar/menu batch passed on
  26.5; Jest 62 tests passed.
- The Android implementation matches the generated codegen interface but has not been compiled or
  run. That must happen before 0.1.3 acceptance.

## Consumer review, phase 3 (September 27)

- `useGlassTier()`, `GlassFallbackThemeProvider` (defaults unchanged) and `fallbackMaterial`.
- iOS tab artwork (asset names) and per-tab selected and inactive colours.
- The tab artwork/tint and tab lifecycle tests passed on 26.5 and 18.6, and the captures were
  inspected. Jest: 66 tests passed.
- iOS 26 unselected labels keep the system style. Android per-tab colours and
  `ImageSourcePropType` images are not implemented.

## Consumer review, phase 4: packaging (September 27)

- The package ships compiled `lib/module` + `lib/typescript` (react-native-builder-bob) with an
  exports map.
- The standalone consumer check passed with the Android native compile skipped
  (`ALG_SKIP_ANDROID_NATIVE=1`): 247 files, sha256 `0eea3e77…c1b0`, typecheck, both release bundles,
  iOS native build.
- A CI workflow runs typecheck, tests and pack checks on PRs.
- Open before acceptance: the Android Gradle compile (Phase 2 Kotlin, Material override) and the
  owner's decision on the peer-range cap.

## Consumer review, phase 5: new components (September 27)

- Adds `GlassBadge`, counted and per-option tinted segments, a prominent `GlassIconButton` (FAB),
  `GlassToastProvider`, `GlassScrollEdge`, `GlassSearchField` and `GlassExpandingTabs`.
- Removes the reserved `__toggle` action ID.
- Corrects the iOS tab-bar inset guidance (measured).
- Adds a surfaces reference page.
- Each component has a dedicated UI test that passed on iOS 26.5 and 18.6, with captures inspected.
- Full iOS 26.5 UI suite: 27 passed, 4 skipped by design, 1 pre-existing failure
  (`testAdaptiveControlAccessibility`), and 1 flaky test, since hardened (3/3 passes).
- Jest: 18 suites / 79 tests passed; check-pack passed (312 files).
- Android: new components use JS fallbacks. The Kotlin changes from phase 2 are uncompiled until
  the Android pass.

## September 27 execution scope correction

Owner explicitly stopped Android simulator/build/testing due to disk pressure.
Only iOS simulator builds/tests are authorized now. Android emulator is stopped;
approximately 1 GB of generated project Android outputs was removed. Preserve
Android implementation and record runtime validation as deferred. The new shared
`forceFallback` mode can be exercised on iOS, but does not verify Android native UI.
Retain iOS build caches and do not start a second full native consumer build tree
without accounting for available storage.

## Scope

Owner requested iPhone 17 Pro Max testing and version 0.1.3 after verification.
Use installed runtimes. Existing deferrals for unavailable older physical devices,
spoken VoiceOver/TalkBack, physical profiling, broad iPad/RTL/settings coverage and
signed app-store distribution remain explicit gaps; no new compatibility claim.

Native API references: [Apple context-menu delegate](https://developer.apple.com/documentation/uikit/uicontextmenuinteractiondelegate)
and [Android PopupMenu](https://developer.android.com/reference/android/widget/PopupMenu).
