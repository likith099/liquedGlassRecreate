# Platform support and backward compatibility

What this package can run on, what sets each limit, and what is still unverified.

## React Native versions

The peer range is `react-native >=0.81.0` with **no upper bound**. That range says what npm will let you install; it is not a claim that every future release is tested. What has actually been built and exercised is this:

| React Native | Status |
| --- | --- |
| 0.81.5 | Built and exercised |
| 0.86.3 | Built and exercised |
| 0.87.1 | Built and exercised — typecheck, 32 JS tests, Fabric codegen, native compile, and five native UI batches (surface/live props, menus, tabs, buttons/segmented, toolbars) all pass |
| below 0.81 | Not supported. These are Fabric codegen components and need the New Architecture |

An upper bound was tried and removed. Capping the range at the last tested version makes every new React Native release an install-time `ERESOLVE` failure for everyone, including on versions that work perfectly well. Without the cap, a genuinely incompatible release fails at build time with a real diagnostic instead. Tested versions belong in this table, not in the peer range.

### Known React Native 0.87 issues (in React Native, not this package)

The following build and workspace integration issues surfaced while verifying 0.87.1:

- **Prebuilt React-Core header paths.** With 0.87's default prebuilt mode, React's own `ReactCodegen` target fails to compile: its xcconfig puts `Headers/Public/React-Core-prebuilt` on the search path, but `RCTComponentViewProtocol.h` lives one level deeper under `React-Core-prebuilt/React_RCTFabric/React/`, and `RCTRequired` is not published as a public pod header at all. Building React from source with `RCT_USE_PREBUILT_RNCORE=0 pod install` avoids it, and that is how 0.87.1 was verified.
- **Android requires Gradle 9.4.1 and AGP 9.** React Native 0.87 ships AGP 9.2.1, which needs Gradle 9.4.1 or newer, so the wrapper's `distributionUrl` must be bumped. AGP 9 also provides Kotlin itself, so applying `org.jetbrains.kotlin.android` on top fails with *"Cannot add extension with name 'kotlin'"*; this package's own `android/build.gradle` already guards that apply behind an AGP-version check, but a host app's `app/build.gradle` usually does not. AGP 9 also rejects `getDefaultProguardFile('proguard-android.txt')` in favour of `proguard-android-optimize.txt`.
- **`@react-native/metro-config` nesting in npm workspaces.** On 0.86.3 npm hoisted it to the root `node_modules`; on 0.87.1 it is nested inside the app workspace. `@react-native/community-cli-plugin` loads it with a bare `require()`, which cannot reach a nested copy, so Metro fails to start. Declaring it in the workspace root's `devDependencies` forces the hoist.

- **Release Hermes compiler resolution in npm workspaces.** The RN 0.87 Gradle plugin searches under the app root, while this repository hoists `hermes-compiler` into the workspace root. Debug builds skip JS bundling and hid this failure. The example now supplies `react.hermesCommand` for the hoisted package with the plugin's OS substitution. A standalone app normally uses the default path. See the [Gradle plugin configuration](https://reactnative.dev/docs/react-native-gradle-plugin#hermescommand).

- **Android RTL locale detection.** The installed RN 0.87.1 source and Maven Release bytecode use `Locale.getAvailableLocales()[0]` to detect direction, which does not select the active app locale. The demo explicitly aligns React's RTL flag with Android's current configuration before the React host starts. This is a host-only workaround; the library does not set global locale or direction. See [RTL notes](accessibility.md#rtl-layout).

## What actually sets the floor

| Constraint | Value | Set by |
| --- | --- | --- |
| React Native minimum iOS | **15.1** | React Native itself; both 0.81 and 0.86 declare `min_ios_version_supported = 15.1` |
| Xcode 27 lowest deployment target | **15.0** | The iPhoneOS 27.0 SDK's `ValidDeploymentTargets` |
| Lowest iOS this package compiles at | **15.1** | Verified by building the example at that target |
| Podspec floor as shipped today | **15.1** | `AdaptiveLiquidGlass.podspec`, lowered in B4 to match React Native's own minimum |
| Native glass rendering | **26.0+** | `UIGlassEffect`, `.glass` button style (UITab itself predates glass) |

iOS 12, 13 and 14 are **not reachable**. React Native's own minimum is 15.1, so no version of this package can go below it while targeting a supported React Native. iOS 15.1 is the realistic floor and is the target of batch `B4`.

## What happens to a consuming app today

This matters more than a crash, because it is silent and happens at build time rather than at runtime.

- CocoaPods enforces the podspec floor when resolving. An app whose deployment target is below the floor fails `pod install` outright with *"Specs satisfying the `AdaptiveLiquidGlass` dependency were found, but they required a higher minimum deployment target."* The app does not build. It does not crash at runtime, because it never ships.
- Raising the app's deployment target to satisfy the pod means that **the whole app stops being installable on every device below that target**. With the floor now at 15.1 the package no longer forces a consuming app above React Native's own minimum, so adopting it costs no device reach.
- Below iOS 26 the components are designed to fall back to standard UIKit and React Native controls rather than glass, so the intended behaviour on an older but supported device is a working UI with UIKit system blur for surfaces and ordinary controls. The fallback path has executed on iOS 18.6; current coverage is recorded in the tracker.

## Support matrix

| iOS | Intended behaviour | Verified |
| --- | --- | --- |
| 26.0+ | Native Liquid Glass materials and controls | Yes, on the 26.5 simulator and an iPhone 17 Pro Max on 27.0 |
| 15.1 – 25.x | Standard UIKit and React Native controls, no glass | **Executed on the iOS 18.6 simulator.** The app runs, reports "Standard platform components", and tab navigation plus the native button and selector checks pass. Eight selected checks now pass, including native blur/reuse, surface interaction, accessibility, largest text, controls, tabs, slider and menus/toolbars. 15.1–17.x remain unexecuted |
| below 15.1 | Not reachable | React Native's own limit |

Two deliberate behavioural differences below iOS 26, both correct for their platform: a loading button reports the accessibility value `busy` from the React fallback where SwiftUI reports `Loading`, and the selector is an individually accessible radio group rather than a `UISegmentedControl`. The UI tests branch on the running OS version to assert the right one.

Android's minimum is inherited from the consuming app's `minSdkVersion`; the package declares no floor of its own. Material Components 1.13.0 is the practical constraint. This has not been tested against a low `minSdkVersion`.

## Batch B4 scope

1. **Done.** The podspec floor is 15.1. `preferredMenuElementOrder` needs iOS 16.0 and is guarded with `if #available(iOS 16.0, *)`; nothing else in the package exceeded 15.1.
2. **Done.** The deployment-target trade-off is fixed. `UITabBarController` adopts the `UITab` API from the app's deployment target, not merely the running OS, so a runtime `#available(iOS 18.4, *)` check alone left an app built for an older target with tabs UIKit ignored and no view controllers, and tab replacement silently produced a blank screen. The view-controller array is now driven whenever the controller's contents do not match, which is a no-op once `UITab` has taken effect, and selection falls through to the view-controller path when `tab(forIdentifier:)` returns nil. At a 15.1 deployment target the tab navigation, accessibility, large-text, button/selector and slider tests all pass.
3. **Largely done.** The user installed the iOS 18.6 simulator runtime, which `xcodebuild -downloadPlatform` could not fetch, and the fallback path executed there for the first time. The app launches, the support gate correctly reports "Standard platform components" rather than glass, and `testNativeTabNavigationBatch` and `testNativeButtonAndSegmentedControl` pass. Review found that `testAdaptiveControlAccessibility` queried a UIKit segmented control when the fallback rendered React radio controls. The runtime-specific query is corrected and passes, including largest-text selection. Runtimes between 15.1 and 17.x are still unexecuted.
4. **Rechecked.** The unchanged full flat/hierarchical menu and toolbar test passes on 18.6 and 26.5. The previous dismissal failure was not reproduced; no menu fix is claimed.
5. **Deferred by the owner; not a release blocker.** Acceptance on a physical older device. An iPhone 7 tops out at iOS 15.8, so it is a valid target only once the floor reaches 15.1, and never for glass rendering.
6. **Done.** The package README documents the 15.1 floor, 18.6 evidence and unverified older versions.

## Current candidate scope

0.1.2 prioritizes iPhone. The owner accepts the existing iOS 18.6 simulator evidence
for the fallback decision and requires no older physical device or new simulator.
The owner subsequently authorized runtime/regression testing and publication.
SwiftUI switching/merging/RTL and the current/older simulator regression have
passed; see [the current evidence](../release/verification-0.1.2.md). Remaining
manual acceptance stays deferred. iPad hosts already
size from their bounds and toolbars overflow; narrow action clusters now select
wrapping controls. Multitasking runtime behavior has not been newly verified.
See [candidate scope](../release/iphone-first-0.1.2.md).

## Deferred coverage gaps

- iOS 15.1 to 17.x have never been executed. Xcode 27 cannot download those runtimes, so a physical device is the only route for them.
- Blur/accessibility/menu simulator checks pass on 18.6. Reduce Transparency/Motion transitions still need runtime acceptance.
- A physical iPhone 17 Pro Max/iOS 27 Release action baseline is recorded; full candidate profiling remains open. Unsigned iOS archive and demo-signed Android APK/AAB builds pass, with real distribution signing/export/install still pending. See [the review](../release/review-2026-09-20.md).
- iPad rotation/tabs, largest text and menus/toolbars pass on the 26.5 simulator; multitasking remains open. Actual-locale iOS/Android RTL action/selector checks pass, with broader navigation/menu/slider cases still pending. VoiceOver is deferred by user request; TalkBack remains unverified.
- Android has not been tested against an old `minSdkVersion` or an old device.
