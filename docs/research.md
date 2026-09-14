# Liquid Glass reference study

Inspected on September 11, 2026 against installed Xcode 26.6 / iOS 26.5 SDK headers and Swift interfaces.

## Installed references

| Package | Installed version | What was inspected |
| --- | --- | --- |
| `@callstack/liquid-glass` | 0.8.1 | Swift material host, Objective-C++ Fabric wrappers, generated component schema, lifecycle, interaction reset, container |
| `expo-glass-effect` | 57.0.3 | Swift view and container, effect initialization, live interaction changes, children mounting, style transitions |

These packages remain isolated in `research/references`. Their upstream copyright/license files remain in their installed packages. Our implementation was written against Apple's public APIs and React Native's Fabric integration pattern; we do not depend on or vendor either reference implementation.

The starting premise needs qualification: the reference packages already support native interactive material and merging containers, not just a static glass layer. Callstack 0.8.1 also resets effects when interactivity changes. Cached README/search content may describe earlier limitations. The opportunity is a broader component API with SwiftUI-owned identity and transitions, accessible platform counterparts, and carefully handled host lifecycles.

## Primary sources

- [Apple: Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views): native material, interaction, containers, stable glass identities and morphing.
- [Apple: UIGlassEffect](https://developer.apple.com/documentation/uikit/uiglasseffect): UIKit material and interactive behavior.
- [Apple: UIGlassContainerEffect](https://developer.apple.com/documentation/uikit/uiglasscontainereffect): combined rendering of child glass effects.
- [Callstack source](https://github.com/callstack/liquid-glass): Fabric/Swift bridge implementation, public API, MIT license.
- [Expo Glass Effect documentation](https://docs.expo.dev/versions/latest/sdk/glass-effect/): UIKit wrapper behavior, opacity constraints, accessibility and runtime checks.
- [Expo source](https://github.com/expo/expo/tree/main/packages/expo-glass-effect): lifecycle and contentView mounting reference.

The installed Apple SDK confirms `UIGlassEffect.isInteractive`, `tintColor`, `UIGlassContainerEffect.spacing`, `GlassEffectContainer`, `glassEffectID`, `glassEffectTransition`, and `Glass.interactive`. Apple renders refraction, light response, and native deformation. Public APIs do not expose a general configurable physical stretching engine or every Apple system control behavior.

## Design decisions

1. Bare React Native Fabric module; the user explicitly requires no Expo Modules dependency.
2. UIKit hosts arbitrary React children and composite material groups.
3. The action cluster now uses stable UIKit controls and the same UIGlassEffect host as surfaces. The earlier SwiftUI cluster was replaced after physical-device feedback exposed an objectionable interactive highlight; UIKit merging uses UIGlassContainerEffect. The title button still uses native SwiftUI styles.
4. Android uses standard platform-backed React Native controls and a native Kotlin SeekBar for the slider, with the same public API.
5. Xcode 26+ is a build requirement, while runtime guards provide older-iOS fallbacks.
6. Reference packages are not installed into the demo; they cannot accidentally become native runtime dependencies.

## Native control sources

- [Apple: GlassButtonStyle](https://developer.apple.com/documentation/swiftui/glassbuttonstyle) and [GlassProminentButtonStyle](https://developer.apple.com/documentation/swiftui/glassprominentbuttonstyle): the title button uses these system primitive styles.
- [Apple: Build a UIKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/284/): native segmented-control thumbs adopt Liquid Glass interaction. The new selector wraps UISegmentedControl rather than simulating that thumb with React animations.
- [Apple: UISlider](https://developer.apple.com/documentation/uikit/uislider) and the same UIKit design session: the system slider owns thumb momentum and stretching. Our Swift bridge retains native continuous tracking; stepped mode snaps values. Tick-mark and neutral-track configuration remain outside the current public package API.
