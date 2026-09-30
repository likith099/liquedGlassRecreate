# 0.1.6 verification

**Status: candidate.** The owner authorized publishing once every test on this machine passes
(September 30, 2026). No hosted device tests run (removed in 0.1.5); all native evidence below is
local.

## Candidate

- Source: branch `feature/native-menu-panel` from `main` (`1fe9c9d`, 0.1.5).
- Reviewed source digest: recorded in `release/acceptance.json`.
- Changes since 0.1.5 (see `packages/liquid-glass/CHANGELOG.md`):
  - **Principle (owner):** the package wraps Apple's own UI; it no longer draws a menu of its own.
  - **Added:** `GlassContextMenu` `menuPlacement="below"`: Apple's context menu opens below the
    content as in Messages. UIKit lays out and animates the lift (a separate preview, moved only as
    far as the menu needs) and the menu; the press-in plays on an invisible stand-in so the content
    keeps its size; a clear margin (iOS 26 only) keeps UIKit's ~32-point corner clip off the content.
    Android lifts the content (180 ms) when its popup would not fit below.
  - **Added:** `computeFocusMenuLayout` (the R2.4 layout as a pure function).
  - **Changed (breaking):** `GlassMenuPanel` is an invisible anchor for Apple's `UIMenu` (`open()`
    via `performPrimaryAction`, iOS 17.4+; the plain fallback before), and `measure()` returns
    `{width, height}` measured from Apple's menu at all 12 text sizes. The 0.1.5 custom panel and its
    props are removed; `GlassLongPress` no longer hands its finger to a panel.
  - **Changed:** Android long-press menus are at least 208 dp wide.
  - **Fixed (found by the iOS 18.6 run):** the action cluster's JavaScript fallback reported
    React Native's expanded state on iOS ("expanded" / nothing), unlike the native cluster
    ("Expanded" / "Collapsed"); VoiceOver now hears the same values on every iOS version.

## Evidence

| Check | Result |
| --- | --- |
| TypeScript, Jest, release tools, lint | Clean; 21 suites / 111 tests and 6 tier snapshots (including the ten R2.5 vectors, a full-screen invariant sweep, `measure` against the measured table, the anchor, the pre-17.4 fallback and `menuPlacement`); release-tool tests 10/10; ESLint no errors. |
| Package contents | `check-pack` passed. |
| Packed consumer (Release) | Passed: 346-file archive, SHA-256 `ddbc3c7d9cd12dc989b242f0f43d9f472111c2b26a79f4f536de403628833cd3`; consumer TypeScript, both production bundles, iOS and Android native Release builds. No Expo or navigation dependency. |
| iOS 26.5, iPhone 17 Pro Max, Release | All 32 UI tests: 29 passed, 3 skipped (iPad, older-iOS and physical-device tests). After the action-cluster fix, the 8 tests touching the cluster passed again. |
| iOS 18.6, iPhone 16 Pro Max, Release | All 32 UI tests: 23 passed, 7 skipped (iOS 26-only and other-hardware tests), 2 failed on the action cluster's spoken value (fixed above); after the fix those 2 and the 2 related tests passed. |
| iPad, Release | `testIPadRotationAndTabLayout` passed on iPad Pro 11-inch with iOS 26.5 (M5) and with iOS 18.6 (M4). |
| Android 36 emulator (Pixel 10 Pro XL) | All 9 checks passed first time on a debug build and again on a release build (JavaScript bundled), including the rewritten `verify-android-menu-panel.py` (received and sent messages at the top, middle and bottom: popup below the message every time, the message lifted at the bottom, 208 dp wide). |
| Motion, frame by frame | 60 fps simulator recordings on 26.5 and 18.6: no size change while pressed, one bubble in every frame, the lift glides up and back, the bubble keeps its shape. |

## Not established

Physical-device profiling, spoken VoiceOver and TalkBack, iOS 15–17 runtimes and the Android minimum
API remain deferred. Specific to 0.1.6: the Android lift was not recorded frame by frame (the
emulator's recorder gives black frames); the message menu was exercised in the demo's scroll view,
not in a long, recycling chat list; on iOS 18.6 faint corner slivers of the preview container show
around a lifted bubble; a title that wraps makes Apple's menu taller than `measure()` predicts.
