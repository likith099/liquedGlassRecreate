# Accessibility and adaptive layout

Use the demo’s **Open adaptive controls** screen to exercise controls with device text size, appearance and language settings. Controls retain their existing props and controlled event semantics.

## Layout

Native title buttons, menu triggers, toolbars and tabs need an explicit React host height because they do not size Yoga from their native content. Only the text inside them grows with the system font scale, so their default height grows by one line height per unit of font scale rather than scaling the whole box, which would otherwise leave a large empty area around the label. Caller `style.height` takes precedence. Fallback title buttons grow with wrapped text. GlassSegmentedControl keeps its options side by side at every text size with equal widths; labels wrap rather than truncate, so a long label makes the control taller. Above font scale 1.3 iOS uses the same React group instead of UISegmentedControl, which truncates. Options remain individually accessible and have a minimum 48-point target. A change in font scale preserves the caller’s selected value and does not emit a selection event.

Material tabs enable label font scaling and up to two lines. Keep native tab titles short. Native controls still live in React layout bounds: allow vertical space, avoid fixed-height ancestors and test the actual labels at the largest supported text size. Arbitrary children inside GlassView/GlassPressable are the caller’s responsibility. Native action-cluster icons retain their accepted size and material; their accessible titles convey meaning. Android action titles can wrap with the group.

## Semantics and system behavior

- Supply meaningful accessibility labels for sliders and custom pressable content. GlassView alone is a surface, not a semantic button.
- Individual actions, options and tabs remain exposed; do not group a native multi-control host as a single accessibility element. The fallback action cluster explicitly keeps its children exposed.
- Buttons report disabled/loading state, selectors report selected/disabled options, and native sliders supply adjustable semantics. Native tabs are exposed as labelled buttons that report their selected state.
- Known platform gap: a disabled iOS tab is dimmed and cannot be selected through `UITab.isEnabled`, but it still reports itself as enabled in the accessibility tree. `UITab` conforms only to `UIAccessibilityIdentification` and neither it nor `UITabBarItem` declares a public `accessibilityTraits` property, so the package cannot mark the tab as disabled without private API. Android's tab does report the disabled state. Spoken announcements need separate verification on both platforms.
- Reduce Transparency uses opaque semantic surface/action backgrounds and standard button/menu appearances. Reduce Motion suppresses package-owned expansion/material transitions. UIKit/SwiftUI and Android retain ownership of their system interactions.
- Use the device’s layout direction. React layout and native controls retain platform direction handling; the package does not reverse item IDs to simulate RTL.

## Verification boundary

B3 adds JS regressions, iOS accessibility-tree/large-text checks, and Android runtime checks for action groups, title buttons, selectors, dark large text and light RTL. Current executed evidence and remaining gaps live in the [development tracker](development.md). Test implementations alone do not establish a pass.

Manual acceptance still needs real VoiceOver/TalkBack navigation, spoken disabled/selected/loading states and badges, Switch Control or keyboard navigation, settings changes during interactions, and physical-device layout/perception. Older-iOS device coverage remains deferred. Do not claim comprehensive accessibility conformance from automation.

Platform references: [Apple notEnabled trait](https://developer.apple.com/documentation/uikit/uiaccessibilitytraits/notenabled), [UISegmentedControl](https://developer.apple.com/documentation/uikit/uisegmentedcontrol), and [Material 1.13.0 NavigationBarView public scaling API](https://github.com/material-components/material-components-android/blob/1.13.0/lib/java/com/google/android/material/navigation/NavigationBarView.java).
