# Action-cluster appearance options

`GlassActionCluster` can use either the existing UIKit presentation or stock
SwiftUI glass buttons on iOS 26+. Both use Apple's native rendering APIs. The
UIKit version is our configured arrangement/material treatment, including the
accepted dark-mode shading; the SwiftUI option uses standard `Button` styling.

```tsx
<GlassActionCluster
  iosImplementation="swiftui" // "uikit" keeps the current appearance (default)
  actions={[
    {id: 'save', title: 'Save', systemImage: 'bookmark'},
    {id: 'share', title: 'Share', systemImage: 'square.and.arrow.up'},
  ]}
  expanded={expanded}
  onExpandedChange={setExpanded}
  onAction={handleAction}
/>
```

You can change `iosImplementation` while mounted. React owns `expanded` and all
action data in both modes. Changing the implementation does not emit an action or
expansion event. The old renderer is detached and its callbacks are ignored. Only
the selected renderer is visible; SwiftUI hosting is created on first use.

| Behavior/prop | `uikit` (default) | `swiftui` |
| --- | --- | --- |
| Material and press appearance | Existing UIGlassEffect surfaces; icons remain inside stretching glass | SwiftUI `Button` with `.buttonStyle(.glass)` and circular border shape |
| Default tint | Existing neutral dark-mode material shading | System button tint; no added dark-mode shading |
| `tintColor` | Material tint override | Standard SwiftUI button tint |
| `material`, `interactive` | Existing regular/clear and native-feedback controls | Ignored; stock material and button feedback remain active |
| `mergingEnabled` | Existing UIKit glass container; defaults off | Opt-in `GlassEffectContainer`; defaults off. SwiftUI owns glass transitions; no promise of identical UIKit morphing |
| `spacing` | Material merging threshold | SwiftUI glass-container spacing when enabled; not row layout spacing |
| `animationDuration` | Existing UIKit expansion duration | SwiftUI ease-in-out expansion duration; 0 disables it |
| Reduce Motion / Transparency | Existing behavior | Expansion animation suppressed / standard bordered buttons |
| Disabled actions | Native activation blocked | SwiftUI disabled buttons and current-data callback checks |

Both modes use the same controlled callbacks, stable action IDs and toggle label.
The UIKit branch keeps the accepted icon rotation and material treatment. The
SwiftUI branch displays standard plus/close symbols and uses SwiftUI transitions;
it does not reproduce our UIKit expansion animation or add custom press physics.

On older iOS, Android, `forceFallback`, or a host narrower than
`76 + 64 * actions.length` points, both choices use the existing wrapping standard
controls. Android ignores this iOS-only prop. Allow enough height for wrapping.
The choice applies to this cluster only; standalone `GlassButton` is unchanged.

The example's **SwiftUI action buttons** switch changes the cluster live. Its
other surfaces still follow their own material controls. Re-run CocoaPods and
rebuild the consuming iOS app when ready: this option changes Fabric props and
adds Swift source, so a JavaScript reload alone is insufficient.

Implementation references: Apple's [GlassButtonStyle](https://developer.apple.com/documentation/swiftui/glassbuttonstyle)
and [GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer).
The stock style is available on iOS 26.0; the configurable `.glass(Glass)` overload
needs newer SDK/runtime support, so this implementation deliberately uses the
26.0 stock style. The addition compiled and passed simulator switching, merging and RTL checks;
light-mode screenshots were inspected. See [release verification](../release/verification-0.1.2.md)
for exact executed coverage and remaining limits.
