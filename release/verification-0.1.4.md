# 0.1.4 verification

**Status (September 28, 2026): release candidate verified. Not yet published.**

## Candidate

- Source: version 0.1.4: `main` after pull request #5 (`05af921`), plus the Release-mode iOS CI job
  and the version bump.
- Reviewed source digest: `791c5bd747feb1e90460c41c22aff734ae48ac9d72cda82844a87ad27af7e7e1`.
- Changes since 0.1.3 (see `packages/liquid-glass/CHANGELOG.md`):
  - **Fixed:** `GlassExpandingTabs` on Android shook sideways while switching. Its widths were
    animated from JavaScript, which on the New Architecture reaches the views out of step with the
    layout the other pills are placed from. It now animates transforms and opacity only, on the
    native driver.
  - **Changed:** Android menu buttons, icon buttons and context menus open a Material 3-style
    popup (rounded surface, icons, checkmarks, submenus in place) instead of the system
    `PopupMenu`.
  - **Added:** `androidIcon` on menu items and submenus, and `androidMenuStyle` (corner radius and
    light/dark background, text, icon and destructive colours).
  - **CI:** iOS device tests run on a Release build; UI tests allow 120 s for a cold launch.
- iOS native code gained one Fabric prop (`menuStyleJSON`) that iOS ignores; no iOS behaviour
  changed.

## Evidence

| Check | Result |
| --- | --- |
| TypeScript, Jest | Clean; 20 suites / 93 tests and 6 tier snapshots. A test fails if the Android pills animate a layout prop from JavaScript. |
| Package contents | `check-pack` passed. |
| Packed consumer (Release) | Passed: 318-file archive, SHA-256 `f1f537c646e9c9c160f0b18d722f4b9ffea22dbfb0e21eea85487636858390be`; consumer TypeScript, both production bundles, iOS and Android native Release builds. No Expo or navigation dependency. |
| Android emulator | Pills recorded frame by frame while switching: every icon moves monotonically, with no overlaps (before the fix, icons reversed direction every few frames). Menus captured in light and dark with the default and a custom style. `verify-android-{menu,toolbar,context-menu,features}.py` passed; the context-menu check passed 4 of 5 first attempts (in one, the menu was not open when Back was pressed; the check now asserts the menu is open first, and passed after). |
| iOS 26.5 simulator | The four CI device tests (tab lifecycle with three cold launches, tab artwork and tints, icon buttons and menus, visual tiers) passed in Release. The app and UI-test target compile with the new prop. |
| GitHub Actions | Device tests on the menu branch (`08a16a8`, [run 36444495265](https://github.com/likith099/liquedGlassRecreate/actions/runs/36444495265)): iOS and all eight Android checks passed. CI passed on `main` (`05af921`). |

Earlier CI failures, all in the CI setup: a Debug iOS launch on a busy runner showed
"No script URL provided" because Metro missed the app's startup check, so the iOS job now runs
Release; and the Android features check read badges scrolled off a short screen (fixed in 0.1.3's
cycle).

## Not established

As for 0.1.3: physical-device profiling, spoken VoiceOver and TalkBack, iOS 15–17 runtimes, the
Android minimum API, and signed store distribution remain documented deferrals. The iOS 18.6
fallback evidence is 0.1.3's; iOS native behaviour did not change since.
