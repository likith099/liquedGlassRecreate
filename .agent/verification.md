# Verification — September 12, 2026

## B1 toolbar and menu hierarchy — September 13, 2026

Implemented GlassToolbar using native UIToolbar/Toolbar and extended the shared menu bridge with sections and one submenu level. Existing flat actions remain compatible. Tree validation enforces unique IDs, enabled ancestry, and bounded depth/count. Toolbar actions move to native overflow based on the visible-item cap and host width; iOS shared backgrounds default off. The accepted action-cluster code was not changed.

TypeScript and **6 suites / 23 JavaScript tests passed**. The consolidated iOS simulator test passed (**1 test, 0 failures**, 147.430 seconds) in `artifacts/B1ToolbarMenus.xcresult`: existing flat/fallback menus plus toolbar activation, hierarchical selection, checked/disabled items, dismissal, narrow overflow, replacement, fallback toolbar actions, and replacement while a menu is open. Inspected grouped-menu and narrow-toolbar screenshots in `artifacts/b1-ios-captures/`. The original workspace read stalled in NSFileCoordinator; a local validation workspace referencing the same app/Pods projects completed successfully using existing DerivedData.

Android native compilation passed. The final toolbar runtime pass verified direct actions, grouped checkmarks, disabled actions/submenus, overflow, dismissal, narrow layout, item replacement, and open-menu dismissal on replacement. Results: `artifacts/b1-android-verification.json`; final log: `/private/tmp/alg-b1-android-measure-test.log`. The flat-menu regression passed before the toolbar-only corrections and was reused for the final pass. Inspected `artifacts/b1-android-grouped-menu.png` and `artifacts/b1-android-narrow.png`.

Runtime inspection caught clipped overflow at narrow width and missing direct actions after the first width-budget change. The final Android implementation budgets against host width, assigns fitting native actions explicitly, and forces a posted measurement so action children added during layout receive bounds. The toolbar instance is retained. Temporary diagnostics were removed. The test helper also rejects stale XML after UIAutomator returns a null root; the timed demo replacement was extended to 20 seconds to allow the automation to open its menu.

The local tarball was refreshed at the batch milestone and checked: **60 files**, toolbar/menu sources and extended Fabric props included, no node_modules or generated Android build output. `artifacts/b1-verification.json` records archive/source hashes and test scope. The standalone-consumer sample now includes GlassToolbar but was not rebuilt for this batch; that remains a release-preparation check. New toolbar physical-device acceptance, shared-background visual comparison, older-iOS testing (user-deferred), and full accessibility/large-text/RTL/settings review remain outstanding. No publication occurred.

## Native menu phase — September 13, 2026

Added GlassMenuButton with UIKit UIButton/UIMenu on iOS and Kotlin Button/PopupMenu on Android, shared typed items, checked/disabled/destructive presentation, and guarded ID callbacks. iOS 26 uses native glass configuration; older iOS, Reduce Transparency, and forceFallback use a standard tinted trigger. Menu contents remain native. Item replacements, disablement, and detachment dismiss menus, and revision guards reject stale callbacks. Added the Native menus demo section, API documentation, and a standalone-consumer sample entry. The accepted action-cluster implementation was not changed.

TypeScript and all 19 JavaScript tests passed. Native menu selection/disabled/checked updates passed on the iOS simulator (`artifacts/NativeMenuIOS.xcresult`). The expanded physical-iPhone test also passed outside-tap dismissal without an action (`artifacts/NativeMenuDevice.xcresult`). Device screenshots were inspected in `artifacts/menu-device-captures/`; native checked, disabled, and destructive presentation is visible. The tested app was reopened on the iPhone. The local npm archive contains all 7 new menu source/bridge files and the iOS provider registration, with no generated build output.

After the user requested continuation and approved the Android build, Kotlin/Fabric compilation passed and the updated APK was installed on Pixel_10_Pro_XL. The first runtime attempt reached another project's Metro on port 8081. Added `reactNativeDevServerPort=8093` to the demo's Gradle properties, rebuilt, and verified the generated port resource before reinstalling. `scripts/verify-android-menu.py` then passed native popup selection, controlled checkmarks, disabled entries and trigger, and dismissal without selection. Inspected `artifacts/menu-android-open.png`: checked, unavailable, and destructive entries display correctly. Results are recorded in `artifacts/menu-android-verification.json` and `artifacts/menu-verification.json`.

The standalone-consumer script was updated but not rerun; historical consumer results predate the menu. Older iOS runtime coverage and a full VoiceOver/TalkBack pass remain outstanding. No npm publication was performed.


## Accepted interaction baseline — September 13, 2026

The user confirmed that the native-tint action-button appearance is working well and acceptable. Preserve its native interaction, glyph placement, default dark-mode tint, and default-off merging while adding new components.

## Native neutral tint — September 13, 2026

The user confirmed icon stretching but still found the press highlight far brighter than Native surface. Recorded sustained reference/action presses. Removing the otherwise empty shared effect parent produced the same sampled pressed RGB values and was reverted. A native black tint at 0.5 alpha reduced the recorded action sample from RGB [168,167,184] to [140,138,156]. These are encoded screenshot pixel values, not physical display luminance. Representative frames and measurements are in `artifacts/highlight-comparison/`.

Default action materials now use a dynamic native UIColor tint: black at 0.65 alpha in dark mode, transparent in light mode. This shades the resting material as well as the pressed material; it is not a separate highlight intensity control. Explicit caller tintColor takes precedence. The icon remains inside the effect content view, and native interactivity/lighting/deformation remain enabled without additional press animations or overlays. The 0.65 default is stronger than the recorded 0.5 pilot; no numerical physical-display reduction is claimed.

Validation: the signed iPhone Release build passed. Repeated presses/merging passed in `artifacts/NativeNeutralTintRegression.xcresult`. Xcode initially omitted the other two selected tests; explicit interaction-toggle and native-state tests passed in `artifacts/NativeNeutralTintState.xcresult`, including dark/light tint resolution, custom tint overrides, glyph placement, and material stability. The physical cancellation/hitch test passed with three zero-hitch samples in `artifacts/NativeNeutralTintDevice.xcresult`. The tested app was reopened on the iPhone and the local npm archive refreshed. Physical icon readability and acceptance of the darker resting material await user comparison.


## Match Native surface touch hierarchy — September 12, 2026

The user reported detached icons no longer stretching with the glass and reiterated that Native surface is the reference. Returned SF Symbols directly to the effect content view and removed the contrast shadow. Removed the inner UIControl and the override that forced hit testing to return it. Each item now uses the same plain UIView / ALGSurfaceView / native effect-content hierarchy as the reference, with normal UIKit hit targeting. A tap recognizer observes activation without cancelling or delaying touches; UIKit owns all lighting and deformation. Native highlight strength is not separately adjustable, and identical perceived brightness across different shapes is not established by these checks.

Four simulator checks passed (`artifacts/NativeSurfaceParityRegression.xcresult`): comparison with a reference glass host, content placement/native hit targeting, interaction toggling, repeated action activation and merging, and cancellation/hitch measurement. The first test build referenced an unavailable style getter; that assertion was removed before the successful run. The signed iPhone Release build passed, and the physical cancellation/hitch test passed with three zero-hitch samples (`artifacts/NativeSurfaceParityDevice.xcresult`). The app was installed through XCTest and the local package archive was refreshed. Perceived icon stretching and highlight agreement await user comparison. JavaScript and Android were not changed in this follow-up.


## Icon compositing follow-up — September 12, 2026

The user could not distinguish the pressed icon with a shadow inside the glass content view. Moved each icon above its individual glass material host, retaining its full opacity and fixed dark contrast shadow; the semantic control remains inside the effect to receive native touches. No custom press lighting or movement was added. The signed iPhone build and native visual-state test passed (`artifacts/NativeForegroundVisualState.xcresult`), and this version was installed and opened on the iPhone. The local npm archive was refreshed. User comparison is pending; the physical hitch measurements below predate this hierarchy change and should not be treated as a new measurement of it.

## Native action feedback restored — September 12, 2026

The user rejected the custom flat highlight and small synthetic movement, requesting Apple's localized glass lighting and deformation. Removed the overlay, scale/translation animations, and custom touch tracking. Enabled the same `UIGlassEffect.isInteractive` path used by the existing surface for all enabled action controls. Removed the demo's System press highlight switch and native bridge prop; the public `pressFeedback` prop remains deprecated and ignored for source compatibility. Each fully opaque glyph has a static 1pt-radius black shadow (0.65 opacity) for contrast. Native highlight brightness is unchanged because the public API has no intensity control. Physical readability and perceived motion still await user comparison.

Validation: TypeScript and all 17 JavaScript tests passed. Simulator repeated presses with merging off/on and interaction-toggle activation passed (`artifacts/NativeRestoreRegression.xcresult`). The visual-state check initially failed because it compared copied effect objects by reference; the corrected test observes effect assignments and passed (`artifacts/NativeRestoreVisualState.xcresult`). It verifies native interactivity on both controls, no overlay/custom transform, opaque glyphs, and no effect replacement on press or unchanged props. The signed Release build passed. The physical iPhone cancellation/hitch test passed with three zero-hitch samples (`artifacts/NativeRestoreDevice.xcresult`), and the tested app was reopened on the iPhone. These metrics do not establish optical smoothness or icon readability. The local npm archive was refreshed; a separate consumer was not rebuilt for this change.

Earlier entries below describe superseded implementations.

## Touch response independent of system highlight

The user reported missing motion with Touch response on and System press highlight off. The restrained mode previously supplied only the brightness overlay because disabling Apple's interactive effect also disabled its deformation. Added separate UIKit motion in restrained mode: **1.06x scale, at most 3pt touch-follow translation**, with the existing 0.10s press / 0.20s release timing and requested **46% highlight**. Native mode does not add this transform. The stationary circular hit area, explicit tracking/cancellation, and bounds/center layout keep touch delivery independent of visual movement. Runtime Reduce Motion disables the movement. Turning interaction off restores the rest geometry but does not disable activation.

- Five targeted simulator tests passed in `artifacts/PressMotionRegression.xcresult`: direct native visual-state assertions, real app cancellation/hitch workload, repeated actions with merging off/on, highlight-mode switching, and the glass/fallback regression. The new direct test verifies actual transformed UIKit hosts, layout stability, reset on cancellation/interaction-off, absence of custom transforms in native mode, and callback activation with visuals disabled. It compiles the two production UIKit host files into the test runner; the separate real-app tests exercise actual touch delivery.
- The initial physical test waited for the locked phone, then completed after the device became available: cancellation passed and three iterations measured zero hitches. Minor hit-area/Reduce Motion adjustments were subsequently included in a final device build and rerun. The signed final Release build and physical test passed (`artifacts/PressMotionFinalDevice.xcresult`): cancellation succeeded and all three measured iterations reported 0 hitches / 0 ms/s. These short measurements do not establish a universal frame rate or subjective feel.
- Updated API documentation and the local tarball. The standalone-consumer harness now resolves the test-source references to the installed package when copying the demo project.

## Requested 46% highlight

Increased the restrained overlay peak from 0.16 to **0.46**, as explicitly requested. Press/release timing and the default-off System press highlight switch are unchanged. The signed iPhone Release build passed, the local package was repacked, and the app installed on the iPhone. Launch was blocked because the phone was locked. Earlier functional/hitch results predate this constant-only adjustment.

## Medium highlight adjustment

The user found the 6%-opacity restrained highlight too faint and requested a medium level. Increased only the overlay peak alpha to **0.16 (16%)**, retaining the 0.10s press / 0.20s release timing, full icon opacity, and the default-off System press highlight switch. The signed iPhone Release build passed, and the updated app was installed and opened on the physical iPhone; the local package archive was updated. The previous functional and hitch tests cover the same animation implementation at 6%; they were not rerun for this constant-only visual adjustment. Perceived medium brightness is subject to the user's device comparison.

## Restrained action-button highlight

The user confirmed the UIKit release animation was smooth, then reported that the native press highlight still washed out the +/close glyph. Apple's public UIGlassEffect API exposes interactive on/off and material tint, with no press-intensity parameter. The action cluster now defaults to `pressFeedback="subtle"`: native adaptive glass remains, native press deformation/highlighting is disabled, and a UIKit overlay behind the unchanged icon animates to at most 6% white opacity. Press/release durations are 0.10s/0.20s, with interruption and Reduce Motion handling. `pressFeedback="native"` restores the system response. Android retains its normal ripple; merging remains off by default. The demo adds a System press highlight switch, initially off.

- TypeScript and all 17 JavaScript tests passed. CocoaPods regenerated the native enum prop and both iOS builds succeeded.
- Physical iPhone Release test passed: cancellation plus three press/release iterations measured 0 hitches and 0 ms/s hitch ratio in each iteration (`artifacts/SubtleFeedbackDevice.xcresult`). This measures timing, not perceived brightness or a percentage reduction in luminance.
- Simulator cancellation, repeated action/merging, and original glass/fallback tests passed (`artifacts/SubtleFeedbackSimulator.xcresult`). Xcode omitted the newly added mode-switch test from the initial filtered run; it passed in the explicit separate run (`artifacts/SubtleFeedbackModes.xcresult`), including native → subtle round-trip switching and action callbacks.
- The Release app was reopened on the iPhone for brightness comparison. The maximum overlay alpha is established by the implementation; the user's visual comparison remains a separate check.

## UIKit action-cluster replacement and physical-device measurement

The first SwiftUI animation correction did not resolve the user's visual complaint. The action cluster now uses the same UIKit `ALGSurfaceView` / `UIGlassEffect` material path as the smoother reference surface, with stable native UIControls. Expansion changes action geometry/visibility and the toggle glyph; it does not change the toggle glass's opacity, bounds, or material. Merging remains opt-in through UIGlassContainerEffect. The cluster no longer uses SwiftUI interactive glass or matched-geometry transitions; the public React API and Android counterparts remain unchanged.

- **User confirmed on the physical iPhone: “The highlight now looks smooth.”** This confirms the reported visual issue is resolved in the UIKit build tested here.
- Physical iPhone 17 Pro Max / iOS 26.6: signed Release UI test **passed**. Verified a dragged-out press cancels without expanding, followed by three measured iterations of toggle → Favorite → toggle, each with 0.35-second held presses. `XCTHitchMetric` reported **0 hitches and 0 ms/s hitch ratio in each of the three iterations**. These results cover this short workload; they do not prove 120 FPS, a quantified improvement against the old implementation, or perceptually perfect brightness. Test result: `artifacts/UIKitFeedbackDeviceSigned.xcresult`; log: `/private/tmp/liquid-glass-uikit-device-signed.log`.
- The UI-test runner initially lacked a provisioning profile. Xcode obtained a development profile using the configured team, then installed and ran the test successfully. The tested Release app was reopened on the user's unlocked iPhone for visual comparison.
- All **five simulator UI tests passed** after the correction, including repeated actions with merging off/on, cancellation, existing glass/fallback behavior, native buttons/selection, and the slider (`artifacts/UIKitClusterRegressionFixed.xcresult`).
- The first UIKit regression run caught collapsed actions still being discoverable in the native hierarchy. Fixed by detaching collapsed controls while retaining instances by ID, and reran the suite. Also made glyph layout independent of its rotation transform.
- Local package archive updated. Earlier standalone package-consumer builds in this document predate this native replacement. No new Expo or third-party runtime dependency was introduced.

## Xcode module-map build error

Xcode's failing DerivedData `info.plist` identified `example/ios/LiquidGlassLab.xcodeproj` as the opened project. Its build logs contained both a missing `AdaptiveLiquidGlass.modulemap` and `No such module React`, with the app target built without the Pods dependency targets. Opened `example/ios/LiquidGlassLab.xcworkspace` and verified a signed Debug iphoneos build from that workspace succeeded in fresh `artifacts/XcodeDebugDerivedData`; confirmed the generated module map exists. Added `npm run xcode` and explicit workspace instructions to the README. No pod source or module-map workaround was required.

## Action-button feedback correction

The user reported excessive highlight intensity and a visibly uneven release fade on the action-cluster toggle. Code inspection found overlapping button-label/symbol animations and unconditional material configuration publication inside a bouncing spring. These are plausible contributors; no before/after frame-time capture establishes them as the sole cause.

- The cluster now compares a single equatable configuration snapshot, skips unchanged publication, and animates only changed expansion state with a non-bouncing curve.
- Interactive glass owns press feedback without an additional label-opacity effect. The toggle rotates one stable plus symbol into a cross instead of replacing symbols. Noninteractive/Reduce Transparency buttons retain simple dim feedback.
- iOS simulator build and signed physical-device Release build passed. The existing glass/merging/fallback test passed (`artifacts/ActionFeedback.xcresult`). A dedicated repeated press/release test passed separately (`artifacts/ActionFeedbackRepeated.xcresult`), exercising all three actions and expansion/collapse twice with merging off and twice with it on. The initial filtered test run omitted the new test, so it was run explicitly and its execution confirmed.
- Updated the main simulator and installed the Release app on the connected iPhone. Physical launch was blocked by the locked phone. **Physical highlight intensity, fade smoothness, and frame-time improvement remain unverified.** No FPS improvement is claimed from functional UI tests.
- Repacked the local `.tgz` with this Swift fix. The earlier standalone consumer verification below predates the change; the current fix was compiled in the demo for simulator and physical-device Release. JavaScript/API and Android code are unchanged.

## Slider and package checks before the feedback correction

- TypeScript check passed. JavaScript: **4 suites / 17 tests passed**, including numeric normalization/range validation, slider event forwarding, disabled suppression, and reconciliation when React declines a value change.
- iOS: **3 XCTest UI tests passed, zero failures**, on iPhone 17 Pro Max / iOS 26.5 using Xcode 26.6. Slider checks cover stepping, programmatic reset, rejected changes restoring the native thumb, disabled state, and continuous movement. Existing native button/selector and glass/merging regression tests also passed.
- Android: native Kotlin/Fabric code compiled in the demo (`:app:assembleDebug`, arm64-v8a). Installed and exercised on Pixel_10_Pro_XL. The adb script verified a stepped drag to 80, reset to 40, a rejected drag to 90 retaining React's 40, disabled drag suppression, and continuous movement to approximately 63 (demo labels round values). Compared reset/rejected screenshots: the native thumb is at the same 40 position after rejection, with the completion event reporting 90. These checks cover the slider; a complete Android action-cluster interaction pass remains outstanding.
- Independent packed-package consumer: installed the `.tgz` into `/private/tmp/alg-consumer-LdsNXd` with its own dependency tree and no workspace symlink. Consumer TypeScript, iOS/Android autolinking, both production JS bundles, CocoaPods installation, iOS native build, and Android native build all passed. The Android build executed 98 tasks, including the installed library's Kotlin/codegen tasks. No Expo dependency was installed.
- Physical iPhone: signed Release build succeeded with the project's existing signing configuration, and installation succeeded on the connected iPhone 17 Pro Max. **Launch was blocked because the phone was locked.** No physical-device interaction or performance result is claimed. Release includes its JS bundle and does not require Metro.
- Updated and launched the demo on the main iPhone 17 Pro simulator. Glass merging remains **off by default**. The slider adds no new merging group.

The package verifier initially hit two test-harness issues: conflicting xcodebuild destination/architecture arguments and copied Android demo paths intended for a workspace. Corrected the harness to use build settings and standard standalone node_modules paths; both native consumer builds then passed. The first demo Android build reused an old autolinking cache and omitted the slider; the refreshed build included it and was the APK used for interaction checks.

## Current artifacts (local, gitignored)

- `artifacts/react-native-adaptive-liquid-glass-0.1.0.tgz`: locally installable package; not published. The archive now includes the later action-feedback correction described above; the standalone consumer run used the preceding slider build.
- `artifacts/package-smoke.json`: standalone consumer verification record.
- `artifacts/consumer.ios.js`, `artifacts/consumer.android.js`: production bundles from the separate consumer.
- `artifacts/GlassSlider.xcresult`: all three passing iOS UI tests, with screenshots.
- `artifacts/slider-ios-screenshots/manifest.json`: exported iOS screenshot descriptions.
- `artifacts/slider-android-results.json`: Android slider interaction results.
- `artifacts/slider-android.png`, `artifacts/slider-android-reset.png`, `artifacts/slider-android-rejected.png`: inspected Android screenshots.
- `artifacts/DerivedData/Build/Products/Debug-iphonesimulator/LiquidGlassLab.app`: current iOS simulator demo.
- `artifacts/DeviceDerivedData/Build/Products/Release-iphoneos/LiquidGlassLab.app`: signed, installed physical-device demo.
- `example/android/app/build/outputs/apk/debug/app-debug.apk`: current Android demo.

Reproduce checks using the commands in the root README. Metro uses port 8093. Screenshots from the iOS test include a development Fast Refresh disconnect banner; it did not prevent native test interactions. Restarting Metro and relaunching the main simulator cleared the banner; the final launch screenshot is `artifacts/slider-demo-launch.png`. This is separate from glass rendering and is not evidence of production performance.

## Validation limits

UI tests establish callback/state behavior and screenshots establish visible positions, not animation smoothness at every frame. VoiceOver/TalkBack gesture use, Dynamic Type, accessibility setting changes, interrupted drags/range changes during tracking, older iOS runtimes, broad Android device coverage, and physical-device profiling still need dedicated runtime passes. Cancellation callbacks and accessibility adjustment paths are implemented, but the current UI tests do not cover all those native paths. No React Native version outside 0.86 is claimed as supported. Native tick marks, neutral-track styling, tab bars, menus, and custom gesture physics remain future work.

---

## Earlier verification — September 11, 2026

## Completed

- `npm run typecheck`: passed (library, platform files, example, tests).
- `npm test -- --silent`: 2 suites / 4 tests passed, covering app render, fallback children/props, controlled action callbacks, disabled semantics, and duplicate/reserved morph IDs.
- iOS Debug build: passed with Xcode 26.6 / iOS 26.5 SDK for the running iPhone 17 Pro.
- iOS XCTest UI interaction test: passed, 1 test / 0 failures. It verifies React press delivery, SwiftUI expansion/action/collapse callbacks, interaction/material/tint changes, merging state, fallback switching, and fallback action callbacks.
- Visually inspected native expanded glass and merged surfaces. Found and fixed Fabric's inset material frame causing padded button clipping. The final native screenshot shows the material surrounding the entire label; the merging screenshot shows a connected glass shape.
- Android `:app:assembleDebug`: passed for arm64-v8a using the installed Android SDK and Android Studio JBR.
- Installed/launched Android APK on Pixel_10_Pro_XL; inspected the standard opaque surfaces and Android controls.
- Android screenshot/accessibility tree showed the React button counter and callback status updating. The emulator disconnected before the final action-group tap check completed; Android action callbacks are covered at the shared-component level and by the iOS fallback UI test, but a complete Android action-group interaction run remains outstanding.
- `npm pack --dry-run`: passed; 25 files, about 28 KB unpacked, contains the Swift/Fabric source and TypeScript API, no reference libraries or Expo modules.

## Artifacts (local, gitignored)

- `artifacts/GlassUITests-3.xcresult`: successful native UI test, including screenshots.
- `artifacts/screenshots/manifest.json`: exported screenshot descriptions and filenames.
- `artifacts/DerivedData/Build/Products/Debug-iphonesimulator/LiquidGlassLab.app`: built iOS demo.
- `example/android/app/build/outputs/apk/debug/app-debug.apk`: built Android demo.
- `artifacts/android.png`: Android screenshot.

The example is served by Metro on port 8093. No package was published.

## Limits of this validation

UI tests establish callback/state behavior, not optical fidelity or smoothness at every animation frame. The merged-material screenshot supplies visual evidence of native merging; the Apple API handles optical rendering. No physical-device performance measurements, older iOS runtime testing, complete VoiceOver/Dynamic Type pass, or measured Reduce Motion/Reduce Transparency scenarios have been completed. The implementation responds to those accessibility APIs, but those scenarios still need dedicated runtime checks. Android native compilation and emulator inspection do not establish compatibility with every Android version. React Native versions outside 0.86 are not claimed as supported.

## Opt-in merging update

Added `mergingEnabled` (default false) to `GlassContainer` and `GlassActionCluster`, plus the demo's Glass merging switch. TypeScript and all four JavaScript tests pass. The updated native UI test passed on iPhone 17 Pro Max (iOS 26.5), including ordinary action callbacks with merging off, the switch's default value, off → on → off at unchanged close spacing, and fallback callbacks. Visually inspected all three screenshots: separate circles, joined glass, then separate circles again. Results: `artifacts/MergingToggle-Max.xcresult`; screenshots: `artifacts/merging-toggle-screenshots/`. The initial run on iPhone 17 Pro failed before the merging checks after an unexpected scroll-position change; the subsequent run passed without changing the implementation.

## Native button and segmented control update

- Added the SwiftUI-owned title/icon GlassButton (`.glass` / `.glassProminent`) and UIKit UISegmentedControl bridge, with standard Android counterparts. Existing children-based buttons remain compatible via GlassPressable.
- TypeScript check passed. JavaScript: 3 suites / 7 tests passed, including loading/disabled activation suppression, controlled selection, disabled options, dynamic option replacement, and value validation.
- Native iOS build and both XCTest tests passed on iPhone 17 Pro Max / iOS 26.5. The new test verifies native activation, segment selection, programmatic reset, per-option disablement, whole-control disablement, loading state, and fallback callbacks. The existing glass/merging regression test also passed.
- Visually inspected native and fallback controls. Screenshots and test evidence are in `artifacts/NativeControls.xcresult` and `artifacts/native-controls-screenshots/`.
- Android production JS bundle generated successfully at `artifacts/native-controls.android.js`. Checked that it contains no ALGButton/ALGSegmented native spec references. New Android controls were tested as shared fallbacks, including in the iOS UI test; this update has not had a fresh Android emulator interaction run or physical-device pass.
- Native controls use explicit React layout bounds (button 64pt, selector 52pt by default). Large Dynamic Type, physical-device animation smoothness, and accessibility settings changes still require dedicated validation. No new merging groups are introduced, and merging remains opt-in.

## B2 native tabs and navigation — September 13, 2026

Both platform implementations, demo, docs and tests were written before executing verification, following the user's batch workflow. TypeScript and 8 JS suites / 28 tests passed. The iOS navigation test passed in 48.393 seconds; a focused badge-removal capture passed in 10.886 seconds. Android selection, reselection, retained state, preventDefault, disabled/programmatic navigation, reorder/replacement, badges, back history and remount checks passed. Exported native tab screenshots were inspected.

Verification corrections: modern UIKit uses UITab enabled state; its disabled appearance/activation are correct, while XCTest enabled-state reporting remains inconsistent and VoiceOver review stays pending. Android metadata updates now preserve native menu items, fixing a disturbed selection indicator after badge removal. Explicit simulator app/runner installation ensured updated tests ran. A focused fresh iOS screenshot resolved an incomplete repeated capture.

The final 75-file archive matches source byte-for-byte. An independent consumer without Expo or React Navigation passed typecheck, both production JS bundles, autolinking and both native builds. Current archive hash, source hashes, logs, screenshots and coverage limits are in [B2 verification](../artifacts/b2-verification.json) and [package smoke](../artifacts/package-smoke.json). Older-iOS device tests remain deferred; physical acceptance and the broader accessibility/adaptive layout matrix remain B3.

## B3 accessibility and adaptive layout — September 18, 2026

Continued an in-progress B3 whose implementation was already written but whose verification had not passed. TypeScript passed and the full JS suite passed at 9 suites / 31 tests; the earlier recorded suite failure predates a fix and no longer reproduces. On an iPhone 17 Pro simulator running iOS 26.5, `testAdaptiveControlAccessibility` (21.912 s), `testAdaptiveLargeText` (13.826 s) and the existing `testNativeTabNavigationBatch` (48.025 s) passed with no failures. These cover native button activation, loading value and disabled state, a disabled segment and controlled selection, action-cluster expansion and individually exposed actions, native tab labels and selected state, rejected activation of a disabled tab, and the vertical radio group at `UICTContentSizeCategoryAccessibilityXXXL`.

Native correction: the B3 attempt to publish disabled tab metadata by assigning `accessibilityTraits` on `UITab` and `UITabBarItem` does not work. `UITab` conforms only to `UIAccessibilityIdentification`, and neither class declares a public `accessibilityTraits` property, so both assignments resolved through the informal `NSObject` accessibility category and never reached the rendered tab button. An exported accessibility hierarchy shows each tab as a labelled `Button`, the selected tab carrying `Selected`, and the disabled tab carrying no `Disabled` marker. The two no-op assignments were removed, `UITab.isEnabled` was kept, and the gap is now recorded in [accessibility](../docs/accessibility.md) instead of being claimed as covered. The test asserts the observable guarantee: a disabled tab does not become selected and selection stays on the previous tab.

Test-harness corrections: `XCUIElement.isHittable` is false for a disabled control, so the reveal helper could never scroll to the loading button or the disabled tab; it now checks frame containment and waits for the screen to mount before scrolling. An exact frame-edge comparison failed by 8e-5 points and now uses a one-point tolerance plus a column check. `verify-android-accessibility.py` accepted a window-clipped 46-pixel sliver as a revealed tab bar at font scale 2.0, which dropped the tab children from the dump; it now requires the control to clear the window edge or its visible height to stop growing.

Build lesson: after `build-for-testing` against an iOS 26.5 destination, `test-without-building` ran the previous day's test bundle. The build wrote `LiquidGlassLab_iphonesimulator27.0-arm64.xctestrun` beside the older 26.5 one, and reported failure line numbers matched the superseded source; explicitly installing the app and runner did not help. A single `xcodebuild test` invocation resolved it.

The Android pass completed on a Pixel_10_Pro_XL emulator: the controls phase, a dark 2.0 font-scale phase and a standard light phase all passed, and the captures were inspected on both platforms. RTL could not be produced at all: the developer force-RTL setting changed neither `I18nManager.isRTL` nor the native layout, a Play Store image cannot set `persist.sys.locale` without root, and a per-app Arabic locale left both React and native layout unmirrored, so the scripted RTL phase was replaced with a light-theme phase and RTL moved to manual acceptance.

Executed results, findings and remaining gaps are in [B3 verification](../artifacts/b3-verification.json). Spoken screen-reader output, RTL, Reduce Motion and Reduce Transparency paths, and physical-device acceptance are unverified.

## B3 Android tab active indicator — September 18, 2026

The user reported that on first landing on a tab screen the selected tab's active indicator rendered as a small stub at the icon's bottom-right instead of a pill behind it, and that tapping a tab corrected it. This reproduced at font scale 1.0, which withdrew the earlier diagnosis that it was an unfixable Material defect confined to large text; the large-text symptom was the same bug.

Two hypotheses were tested and rejected before instrumenting: driving selection through `NavigationBarView.selectedItemId` instead of `MenuItem.isChecked` changed nothing, because Material already auto-selects the first item when the menu is built, and removing the forced measure/layout changed nothing either. Logging the bar's view tree then showed the cause directly: the selected item's active indicator view had `lp=0x0`. Material derives those params from the item view's width at the moment the item becomes checked, the first selection happens while the bar is still unmeasured, and the resulting clamp to zero is never revisited.

`applyConfiguration` now re-assigns `itemActiveIndicatorWidth` after the forced layout, which makes every item recompute against its real width, and lays the bar out again because React Native swallows the `requestLayout` that changing those params triggers. The indicator view goes from `lp=0x0, size=0x0` to `lp=192x96, size=192x96` with full scale and alpha, and the pill renders correctly on first landing at font scale 1.0 and 2.0. The B3 Android phases and the B2 Android tabs regression both passed afterwards.

## B3 standalone packaged consumer — September 18, 2026

The refreshed 76-file archive, sha256 `a8188f14…b4abf6e5`, was installed into a fresh `/private/tmp/alg-consumer-*` app with its own dependency tree. Consumer typecheck, both production JS bundles, autolinking including the tab component descriptor and the packaged native sources, and both native builds passed. The consumer resolved no Expo and no React Navigation dependency. The consumer was rebuilt from scratch because its previous directory and `ConsumerDerivedData` cache had been deleted to free disk. Record in [package smoke](../artifacts/package-smoke.json); the file count rose from 75 to 76 with `src/adaptiveHeight.ts`.

## iOS 27 scene lifecycle adoption — September 18, 2026

The demo crashed on a physical iPhone running iOS 27.0, launching to a frozen splash screen with `EXC_BREAKPOINT`. The crash report's faulting frame was `__UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`, raised during scene creation: iOS 27 traps an app that has not adopted the UIScene lifecycle, where iOS 26 only reported a runtime issue. Every earlier check ran on the iOS 26.5 simulator, so nothing caught it.

Two earlier hypotheses were wrong and are recorded so they are not retried. The demo did hardcode `jsLocation = "localhost:8093"`, which cannot reach Metro from a device; that is a real bug, now fixed by reading the address React Native writes into `ip.txt`, but it was not this crash. A code-signing denial seen while launching through `devicectl` was a trust prompt on the device, not a build fault; profiles were valid and included the device.

The iOS 27.0 simulator reproduced the crash exactly, which made it debuggable after the device produced no synced crash report. `example/ios/LiquidGlassLab/Info.plist` now declares a `UIApplicationSceneManifest` and `AppDelegate.swift` adds a `SceneDelegate` that owns the window and starts React Native into it. The app then launched and rendered on the iOS 27 simulator and on the physical iPhone, staying alive past the splash. The three iOS checks passed again on iOS 26.5 afterwards: adaptive control accessibility, largest-text selector layout and the tab navigation regression, 3 tests with 0 failures in 94.6 seconds. This is the example app's configuration; the package itself is unchanged, and a consumer app on iOS 27 must adopt scenes in its own host app.

## MIT licensing and distribution readiness — September 18, 2026

The user chose MIT on the public npm registry, superseding decision D07's deferral. The package previously declared `UNLICENSED` with no LICENSE file, and its podspec claimed a Proprietary license with a `https://localhost/...` placeholder source. An MIT LICENSE now sits at the repository root and inside the package, `package.json` carries license, author, repository, homepage, bugs and keywords, and the podspec's license, homepage, author and source match. The package README's install section was rewritten for npm consumers and records the two host-app requirements that are easy to miss: React Native 0.86.x with the New Architecture, and UIScene adoption on iOS 27. [docs/releasing.md](../docs/releasing.md) holds the publish and pipeline runbook.

The repacked archive is 77 files and 37.3 kB, sha256 `1047045b…0e946ca9`, and passed the standalone consumer check again: typecheck, both production bundles, autolinking and both native builds, with no Expo or React Navigation dependency. The npm name `react-native-adaptive-liquid-glass` was confirmed unregistered. Nothing has been published; that needs an npm login and an explicit go-ahead.

One verification failure on the way was environmental, not a package defect. The consumer's Android build failed twice with `Daemon compilation failed: null`, first under memory pressure with two simulators booted and 95 MB of RAM free, then on a missing `kotlin-stdlib-2_1_20_jar-snapshot.bin` in the Gradle transforms cache — fallout from clearing `~/.gradle/caches` while the disk was nearly full. Clearing the transforms cache and the stale daemons fixed it, and the full run then passed.

## React Native 0.81 compatibility probe — September 18, 2026

A consuming app on React Native 0.81.5 with React 19.1 and Expo SDK 54, New Architecture enabled, prompted a direct test of the `>=0.86.0 <0.87.0` peer range. A scratch bare RN 0.81.5 app was created, the 0.1.0 tarball installed with `--legacy-peer-deps`, and both platforms built.

The package itself is largely compatible with 0.81. Autolinking resolved both platforms and reported all three Android component descriptors; the production JS bundle built, so the shipped TypeScript source transpiles under 0.81's Metro; and `:app:assembleDebug` succeeded, so Fabric codegen and the Kotlin view managers compile against 0.81. RN 0.81 also provides `RCTReactNativeFactory` and codegen `componentProvider`, the two integration points the package relies on.

Two blockers appeared on iOS. The podspec's `ios 16.4` platform floor exceeds the RN 0.81 template's default, so `pod install` refuses until the app raises its own deployment target; that is a one-line consumer change. The second is not ours: the iOS build fails compiling `Pods/fmt`, with `call to consteval function ... is not a constant expression`. A control build of the same app with the package uninstalled fails identically, so **React Native 0.81 does not compile under Xcode 26** regardless of this package. Since Xcode 26 is required for the iOS 26 glass APIs, that is a fundamental conflict for a bare 0.81 app rather than a porting gap.

That fmt failure turned out not to apply to the real consumer. The Expo app's `Podfile.lock` contains no `fmt` pod at all; it resolves `ReactNativeDependencies (0.81.5)`, React Native's **prebuilt** iOS dependency binary, because `RCT_USE_RN_DEP` defaults on. Re-running the probe's `pod install` with `RCT_USE_RN_DEP=1 RCT_USE_PREBUILT_RNCORE=1` produced the same fmt-free pod set, and the iOS build then **succeeded** with the package installed.

React Native 0.81 is therefore supported, and the peer range was widened to `>=0.81.0 <0.87.0`. Verified builds are 0.81.5 and 0.86.3; 0.87 is untested and excluded. Two host-app requirements are documented: an iOS deployment target of 16.4 or higher, which CocoaPods enforces, and on 0.81 the use of prebuilt React Native dependencies rather than building React Native from source. After widening the range, typecheck, the JS suite and the full standalone consumer check on 0.86 all passed again.

## Backward-compatibility audit — September 18, 2026

Prompted by the user asking what a first public release still needs, and offering an iPhone 7 for older-iOS testing.

**The iOS floor is not what the podspec claims.** Lowering `s.platforms` to 15.1 and rebuilding produced exactly two compile errors, both `preferredMenuElementOrder` in `ALGMenuView.swift`, which needs iOS 16.0. Nothing in the package requires 16.4; that figure was arbitrary. Both call sites are now guarded with `if #available(iOS 16.0, *)`, which is correct defensive code and is kept.

**But lowering the floor is not free.** With the example app's deployment target at 15.1 the package compiles, yet `testNativeTabNavigationBatch` fails at the Search-screen step. Reverting only the deployment target to 16.4 makes it pass again, so UIKit changes native tab behaviour on iOS 26 based on the app's deployment target. The floor therefore stays at 16.4 pending investigation; this is a real trade-off between older-device reach and modern tab behaviour, not a version-string edit.

**An iPhone 7 cannot run this package at any floor we ship today.** It tops out at iOS 15.8, below both the current 16.4 and the 16.0 the menu API needs. Older-device acceptance needs a device on iOS 16.0+.

**A pre-existing regression was found in the menu tests.** `testNativeMenuActionsAndFallback` and `testToolbarAndMenuBatch` both fail at line 116: after tapping outside an open menu, `Share item` never disappears, so the menu does not dismiss. Stashing the availability guard and rebuilding reproduces the failure, so it predates this change. B3 only ever ran the three accessibility and tabs tests, so the menu suite has not been executed since B1 in September, across scene adoption, the iOS 27 SDK and the adaptive-height work. Cause unknown; it needs its own investigation.

**No runtime below iOS 26.5 has ever executed this code.** Only the 26.5 and 27.0 simulator runtimes are installed, so the entire `isLiquidGlassSupported() == false` fallback path — the standard controls every pre-26 device would see — is unverified on any real or simulated older OS.

## B4 iOS floor lowered to 15.1 — September 18, 2026

The user's requirement is that devices below iOS 26 get the standard counterpart controls and full functionality rather than glass, which is the package's existing design; the work was to make that floor reachable and prove it.

The podspec floor moved from 16.4 to **15.1**, React Native's own minimum and the lowest deployment target the iPhoneOS 27.0 SDK accepts. Only one API exceeded it, `preferredMenuElementOrder` at iOS 16.0, now guarded at both call sites.

The real defect was in the tab wiring. `UITabBarController` adopts the `UITab` API based on the app's **deployment target**, not only the running OS. The code branched on `#available(iOS 18.4, *)`, which is true on iOS 26 regardless of deployment target, so an app built for 15.1 set `controller.tabs` that UIKit ignored while never populating `viewControllers`; tab replacement then produced a blank screen. This was found by bisection: at a 15.1 target `testNativeTabNavigationBatch` failed at the Search-screen step, and reverting only the deployment target to 16.4 made it pass. The fix drives the view-controller array whenever the controller's contents do not match the intended order, a no-op once `UITab` has taken effect, and lets selection fall through to the view-controller path when `tab(forIdentifier:)` returns nil.

At a 15.1 deployment target the tab navigation, adaptive accessibility, largest-text, native button/selector and slider tests all pass, along with typecheck and the JS suite.

What is still unproven is the fallback path itself at runtime. Xcode 27 offers only iOS 26.0 for download; 18.x, 17.x and 16.x simulator runtimes are unavailable, so no simulator on this machine can run a pre-26 OS. Verifying the counterpart controls requires a physical device below iOS 26. An iPhone 7 on iOS 15.8 is now within the supported floor and is the only such device available; it was not connected during this work.

## First execution below iOS 26 — September 19, 2026

The user installed the iOS 18.6 simulator runtime, which `xcodebuild -downloadPlatform` reports as unavailable for every version below 26.0, and it was used to execute the pre-26 fallback path for the first time in this project.

The example builds and launches on iOS 18.6 at the new 15.1 floor. The demo's own status line reads **"Standard platform components"** instead of the iOS 26 label, confirming `isLiquidGlassSupported()` gates correctly and the React counterparts render rather than glass. `testNativeTabNavigationBatch` passes, which is the requirement that basic navigation keeps working on older devices, and `testNativeButtonAndSegmentedControl` passes after the checks were made version-aware.

Two behavioural differences below 26 are real and now asserted per version rather than papered over. A loading title button reports the accessibility value `busy`, because the React fallback publishes `accessibilityState.busy`, where the SwiftUI control publishes `Loading`. The selector is an individually accessible radio group rather than a `UISegmentedControl`, so element-type queries differ. Both are correct for their platform.

`testAdaptiveControlAccessibility` still fails on 18.6 at the test's own `reveal` helper, which cannot settle on the shorter fallback layout; loosening it from full frame containment to a centre-point check did not resolve it. The exported accessibility hierarchy from the failure shows every expected element present and correctly typed, including the switches, the cluster toggle and all three tab identifiers, so this is a harness limitation rather than a product defect. It is recorded as open.

All three checks still pass on iOS 26.5 after the test changes, so the version-aware branching did not regress the glass path.

## B4 review: native blur and current release state — September 20, 2026

Reviewed the Claude changes and reconciled stale licensing, deployment-target and peer-range claims. MIT metadata already exists; the package is an unpublished 0.1.0 candidate with an iOS 15.1 floor and declared RN 0.81–0.86 range (prior build probes at 0.81.5 and 0.86.3). Corrected the workspace lockfile's stale UNLICENSED/0.86 metadata. Release instructions now use current npm trusted publishing/granular-token guidance and distinguish Debug consumer checks from Release/archive acceptance.

Older-iOS GlassView/GlassPressable now use the existing native host with UIBlurEffect system material (ultra-thin for clear). Explicit forceFallback keeps the opaque React implementation; Reduce Transparency keeps semantic opaque native backgrounds, material none stays transparent, and older-iOS containers remain ordinary layout. The dirty-prop gate retains the blur across unchanged configurations; children stay in contentView. No Android rendering or accepted iOS 26 action-feedback change.

The prior accessibility failure was not just scrolling: the test asked for UISegmentedControl when older iOS rendered individual React controls. Correcting the query resolves it. The previous menu outside-tap failure did not reproduce in either runtime; the unchanged full menu/toolbar test passes, so no menu-code fix or confirmed old root cause is claimed.

Executed evidence ([record and source hashes](../artifacts/b4-review-verification.json)):

- Typecheck and 10 JavaScript suites / 32 tests pass (exit 0).
- iOS **18.6**, iPhone 16 Pro simulator: 8 selected tests, 0 failures, xcodebuild exit 0. Native blur/reuse (100 unchanged configurations), surface touch, adaptive accessibility, largest text, title buttons/selectors, tabs, slider and full menus/toolbars. [Result](../artifacts/B4Review186.xcresult). Inspected blur, largest-text and badge/tab screenshots in `artifacts/b4-review-ios186-captures/`.
- iOS **26.5**, iPhone 17 Pro simulator: 4 selected tests, 0 failures, xcodebuild exit 0. Native action material/interaction configuration, adaptive accessibility, live surface props/merging/forced fallback, and full menus/toolbars. [Result](../artifacts/B4Review265.xcresult). Inspected expanded glass and grouped toolbar screenshots. Post-test simulator diagnostics timed out after 600 seconds before the bundle finalized; `TEST SUCCEEDED` and a readable result bundle were produced. No test rerun was needed.
- Android Debug build passed (136 tasks, 29 executed). Existing Pixel emulator: focused control checks pass for activation, loading/disabled state, controlled selector and action cluster; settings restored. Log `artifacts/b4-review-android-controls.log`. This does not refresh the large-text/theme/RTL evidence.
- npm pack dry run: 77 files, no generated build/cache directories. Prior independent consumer tarball predates B4; no refreshed consumer or publication in this review.

No physical Release performance result or measured speedup is claimed. Next: [physical Release profiling](performance.md), Reduce Transparency/Motion runtime transitions, deferred older-device and manual accessibility acceptance; then refresh the packed consumer and distribution builds for the final candidate. iOS 15–17, exact 18.5, iPad, RTL and spoken assistive technology remain unverified.

## Scoped npm package preparation — September 20, 2026

User supplied `https://www.npmjs.com/settings/likith99/packages`; selected `@likith99/react-native-adaptive-liquid-glass`. Updated package/public registry metadata, demo imports/dependency, workspace lockfile, CocoaPods paths, installation docs and the standalone harness. Native module, codegen and pod names are unchanged. No registry publication or authenticated account-permission verification occurred.

Typecheck and 10 JS suites / 32 tests pass, exit 0. Demo pod install passes. The fresh scoped 77-file tarball installs into `/private/tmp/alg-consumer-xWnbpZ`, passes metadata/autolinking checks, consumer TypeScript, both production JS bundles and both Debug native builds; the verifier exits 0. No Expo or React Navigation dependency in the consumer. Archive `artifacts/likith99-react-native-adaptive-liquid-glass-0.1.0.tgz`, SHA-256 `4baca972b97e140cfffdc0e264a945d3e4832e6693a7d51067719bb5cf40c5c0`. [Package record](../artifacts/package-smoke.json), [scope record](../artifacts/scope-verification.json), logs `artifacts/scope-package-verify.log`, `artifacts/scope-typecheck.log`, `artifacts/scope-jest.log`, `artifacts/scope-pods.log`. This refreshes packed-consumer evidence for B4; it does not replace physical Release performance, accessibility or distribution acceptance.

## First public npm release 0.1.0 — September 20, 2026

Published `@likith99/react-native-adaptive-liquid-glass@0.1.0` to the public npm registry with explicit user authorization, from commit `2cbf5f8` with annotated tag `v0.1.0` pushed so the podspec's `:tag => "v#{s.version}"` resolves. The release commit contains the B4 compatibility work, MIT licensing and scope metadata that the preceding consumer run verified.

Verified after publication rather than from the CLI exit code: registry reports version `0.1.0`, `dist.shasum` `c300239f0ee9379be94bdeb40e2102fb229ef8eb` and `dist.fileCount` 77; `npm access get status` reports `public`. The tarball re-fetched from the registry hashes SHA-256 `bd027edfa69997c4388cd56d5d14bb49fdfeeaab786c9361a5b52148d6665541`, identical to the locally packed archive, so the published bytes match the artifact checked before sending. The packed tree was also diffed against `packages/liquid-glass/` and contains no `node_modules`, `android/build` or `.gradle`. [Release record](../artifacts/release-0.1.0.json).

Publishing failures encountered and resolved, recorded because they will recur at the next release: a bare relative tarball path is parsed as a git spec (`git error 128`, `Permission denied (publickey)`), so it needs a leading `./`; a plain login token is rejected with `403 ... Two-factor authentication or granular access token with bypass 2fa enabled is required`; npm no longer enrols TOTP authenticators, so 2FA is a WebAuthn security key/passkey and `--otp` does not apply — npm prints an `npmjs.com/auth/cli/<uuid>` URL for browser approval, and that challenge requires a TTY or npm exits `EOTP` immediately. After a successful `PUT 200` the package 404s to anonymous readers for roughly a minute of read-path propagation; `npm access list packages` distinguishes this from a failed publish.

Publication does not add runtime evidence. Physical Release profiling, Reduce Transparency/Motion runtime transitions, iOS 15–17, iPad, RTL, spoken assistive technology, oldest supported Android and distribution/archive acceptance all remain unverified, and 0.1.0 ships with those gaps documented in [compatibility](../docs/compatibility.md) and [performance](performance.md). Published name/version pairs cannot be reused, so corrections ship as a new version.
