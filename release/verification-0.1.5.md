# 0.1.5 verification

**Status: candidate.** Not yet tagged or published. The owner authorized the 0.1.5 release on
September 29, 2026.

## Candidate

- Source: branch `release/0.1.5`, which is `main` (`6f399df`, 0.1.4 plus docs) with the menu-panel
  work (`e2e8092`, `1372ef3`, `e615ed9`), the version bump (`290c413`), a UI-test fix for the
  segment fallback (`d356f1f`), an Android check-runner fix (`ae0c722`), the concentric row
  highlight found in owner testing (`1744b07`), a more tolerant Android toast check (`f27d7b0`), and
  CI changes that end with device tests and native builds removed from GitHub (owner decision; see
  below). The package source is unchanged since `1744b07`.
- Reviewed source digest: recorded in `release/acceptance.json`.
- Changes since 0.1.4 (see `packages/liquid-glass/CHANGELOG.md`):
  - **Added:** `GlassMenuPanel`, the system menu as a native view the app places itself: iOS 26
    glass platter and UIKit menu metrics, system material below 26, the `androidMenuStyle` popup
    look on Android; drag-to-select with a tick per row; `measure()` before first paint; `width`,
    `maxHeight`, `colorScheme`, `appearFrom`, `dismiss()`, `autoFocus`, `accessibilityModal`.
  - **Added:** `GlassLongPress`, a native long press that reports the content's window frame,
    cancels the content's touches and hands the same finger to the latest panel.
  - **Added:** `GlassContextMenu` `onOpen`/`onClose` and per-corner `previewCornerRadii`.
  - New native components: `ALGMenuPanel` and `ALGLongPress` (iOS and Android), new `ALGMenu`
    props. Hosts must rebuild both native apps.

## Evidence

| Check | Result |
| --- | --- |
| TypeScript, Jest, release tools | Clean; 21 suites / 97 tests and 6 tier snapshots; release-tool tests 10/10. |
| Package contents | `check-pack` passed: 345 files. |
| Packed consumer (Release) | Passed: 345-file archive, SHA-256 `916e2ab81eb75e8dd12fa28512b0cd14c404b932fc062d18af6d4dbc53e537ab`; consumer TypeScript, both production bundles, iOS and Android native Release builds. No Expo or navigation dependency. Run on the final package source (after the highlight fix). |
| iOS 26.5 simulator (iPhone 17 Pro Max), Release | Passed: tab lifecycle and first tap, tab artwork and tints, icon buttons and programmatic menus, visual tiers, menu panel, context menu (with `onOpen`/`onClose`) and its plain fallback. The menu-panel test covers placement from frames, tap selection, long press with the reported frame, press-slide-lift selection, lift off the panel leaving it open, and the platter's brightness staying steady after the entrance. It passed again after the segment-query fix. |
| iOS 18.6 simulator (iPhone 16 Pro Max), Release | Passed: menu panel (system-material look, same flow), context menu and plain fallback. The panel test first failed on 18.6 because it queried native segment buttons, which the pre-26 segmented fallback does not have; the test now uses the fallback's test IDs. |
| Android 36 emulator (Pixel 10 Pro XL), debug | All nine checks passed, including the new `verify-android-menu-panel.py` (long press, slide onto a row, lift off the panel, tap). |
| Row highlight (owner report) | The highlighted row did not follow the panel's corners (iOS 26: a fixed 12 pt radius against the 30 pt platter; Android: a full-width rectangle). It is now inset by the panel's top padding with the panel's radius less that gap. iOS 26.5: the menu-panel test passed with the fix (Release) and the simulator run was recorded; Android: a held row was captured showing the inset, rounded highlight, and the menu-panel, context-menu and menu checks passed. Pre-26 iOS keeps the edge-to-edge highlight (same code path as before). |
| Android panel entrance | A flicker found in manual testing (the panel drew one fully opaque frame before its fade-in started) was fixed; a per-frame draw log showed the first frame transparent in 10 of 10 presses afterwards. iOS recordings of every entrance frame showed no dip. |
| GitHub Actions | Only the shared checks (release tools, typecheck, Jest, pack) run on GitHub now; they passed on every push of pull request #8. Hosted device tests were tried and removed: across the runs, iOS and Android each failed at least once on runner problems unrelated to the package (the emulator launcher's "isn't responding" dialog over the app; a compiler-cache path; a 2-second toast missed by a slow UI read, now read more tolerantly), and a run took 20–40 minutes. The owner decided on September 29 that native builds and device tests are verified locally before release instead; the local results above are that evidence. |

## Not established

As for 0.1.4: physical-device profiling, spoken VoiceOver and TalkBack, iOS 15–17 runtimes, the
Android minimum API, and signed store distribution remain documented deferrals. For the new
components specifically: `GlassLongPress` next to an inverted `FlatList` or a gesture-handler pan
was not exercised (the demo has neither).
