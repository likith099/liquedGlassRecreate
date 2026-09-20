# Performance review and release acceptance

September 20, 2026. Static review is not a device performance measurement.

## Current implementation

- UIKit owns glass/blur and action animations; React does not calculate material frames. Android uses platform controls and ripple feedback.
- Surface effects are gated by changed material props and initial window layout. B4 adds older-iOS system blur through the same gate, with a native regression checking that 100 unchanged configurations do not replace the effect.
- Action controls retain identity by ID. JSON decoding is gated by changed input. Sliders keep native tracking and reconcile controlled values after release.
- Android tabs retain menu items for metadata-only updates; the extra layout fixes initial indicator sizing. Avoid removing this work without measuring and retesting first.
- Potential hotspots to profile: SwiftUI button models assign every published property per configuration; tab metadata updates reload symbols and badge appearance; Fabric material hosts opt out of recycling. These are candidates, not demonstrated bottlenecks. Do not change accepted interactions based only on suspicion.

## Material cost

Use bounded areas and avoid nested blur/glass surfaces or one surface per row in long lists. Keep merging opt-in. `forceFallback` selects an opaque React surface when compositing cost is unsuitable. Reduce Transparency supplies an opaque semantic native background. Keep visual-effect views and their ancestors at full opacity where possible; Apple's [UIVisualEffectView documentation](https://developer.apple.com/documentation/uikit/uivisualeffectview) describes compositing restrictions. Blur uses system APIs, but still has a rendering cost.

## Required measurement before performance claims

Profile a Release build with an embedded JS bundle on a representative older iPhone, a current iPhone and a lower-end Android device. Record device/OS, source revision, display refresh rate, thermal state and build configuration. Repeat scrolling behind material, surface mount/unmount, action expansion, tabs, menus and slider tracking with glass/blur and opaque modes.

Capture frame times and hitches, main-thread/JS time, CPU, memory after repeated navigation, and GPU/compositing cost using Instruments and Android profiling tools. Compare with each display's frame budget (about 16.7 ms at 60 Hz, 8.3 ms at 120 Hz); do not claim that a simulator Debug interaction test meets either budget. Fix measured hotspots and repeat the same workload. No physical Release performance baseline or measured speedup is claimed yet.

Current test and release state lives in [the tracker](development.md); final candidate checks live in [releasing](releasing.md).
