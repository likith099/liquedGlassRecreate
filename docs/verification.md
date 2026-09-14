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
