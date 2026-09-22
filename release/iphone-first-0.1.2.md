# 0.1.2 iPhone-first candidate — September 21, 2026

Status: implementation and local verification completed; publication is tracked in
[the current verification report](verification-0.1.2.md). The owner subsequently
authorized testing and publication, superseding the earlier source-review-only
instruction. VoiceOver, unavailable older physical devices, full profiling,
iPad multitasking and distribution signing remain deferred. No runtimes were downloaded.

[Artifact receipt](iphone-first-0.1.2-artifact.json) identifies the final archive
installed in an independent consumer and built in Release on both platforms.

## Final source review and changes

- Pre-iOS-26 surfaces still use UIKit system blur; modern glass calls remain
  availability-guarded. Existing opacity/reduced-motion behavior is retained.
- Native action clusters now select the existing wrapping standard controls when
  their measured host is narrower than `76 + 64 * actions.length` points. Resizing
  back restores the native renderer. Controlled state and callbacks are retained;
  no selection or expansion event is emitted merely because the renderer changes.
  Allow the fallback to grow vertically; avoid a fixed height for narrow clusters.
  Existing tint, native feedback and merging behavior are retained where it fits.
- Native title buttons skip equal `@Published` assignments, reducing redundant
  SwiftUI invalidations. No measured frame-rate or CPU improvement is claimed.
- Button hosting now establishes containment before inserting the child view,
  removes the child view when detaching, and retries attachment after Fabric
  finishes mounting. It reuses the same controller and sizes it from host bounds.
- Existing tab/menu/toolbar hosts already size from their bounds. Toolbar actions
  move to native overflow as width shrinks. The example already has a scene-owned
  window and all iPad orientations. No new iPad OS APIs, runtime or dependencies
  are needed for these layout paths. Split-window behavior is not yet executed.
- Earlier B5 fixes include native action RTL, Release packaging/build automation,
  demo Hermes resolution and status-bar ownership; see the linked prior review.
- Added opt-in `GlassActionCluster.iosImplementation="swiftui"`, using stock
  SwiftUI `.glass` buttons with optional `GlassEffectContainer`. The existing
  `uikit` mode remains default and retains its accepted appearance. Native hosts
  swap through Fabric without emitting an action or changing controlled expansion.
  Detached-renderer callbacks are ignored. Older/narrow/forced fallbacks remain.
  The demo has a live switch. `material`/`interactive` apply to UIKit only; SwiftUI
  keeps standard material/feedback and accepts standard button tint.
- Package, example dependency and npm lockfile agree on 0.1.2. The new optional
  prop is backward-compatible; consumers must rebuild native code after updating.
  README screenshots remain pinned to their original published 0.1.1 captures.

The source review follows Apple's [adaptive window layout guidance](https://developer.apple.com/documentation/uikit/multitasking-on-ipad-mac-and-apple-vision-pro), [stock SwiftUI glass buttons](https://developer.apple.com/documentation/swiftui/glassbuttonstyle),
and [child-controller containment lifecycle](https://developer.apple.com/library/archive/featuredarticles/ViewControllerPGforiPhoneOS/ImplementingaContainerViewController.html).
These sources support the implementation choices; they do not validate our code.

## Evidence boundaries

[Earlier review](review-2026-09-20.md) records successful iOS 18.6 blur/fallback,
iOS 26.5 RTL and iPad rotation/menu tests, native Release archive builds, and an
independent packed consumer. The iPhone 17 Pro Max/iOS 27 action baseline predates
the final RTL and button/layout changes. None of that is extended to the new code.

The later verification pass compiled and exercised the new SwiftUI branch,
ran shared regression and iOS 18.6 fallback checks, and built the packed consumer
on both platforms. Exact counts and evidence are in the current verification
report. This is not a claim of exhaustive stability or store acceptance.

## Release policy

`release/acceptance.json` schema 2 records an `iphone-first` scope. Source review,
matching version/tag/digest and durable evidence remain required. Each deferred
manual/device category has an explicit reason and owner decision; deferral is not
a pass. GitHub Actions still requires shared checks and both native Release builds
before publishing through the existing npm trusted publisher. Those jobs have not
been triggered in this pass, so a hosted CI success is not claimed.

The final digest identifies the source covered by the recorded review and scoped checks. Before tagging,
commit this report and the acceptance record with the candidate. Any later source
change requires review and a new digest. No further manual-device campaign is
required for 0.1.2 under the current scope.

## Using this candidate

Install the local `artifacts/consumer-5d744294ec57048bb4a435f6cb4efabc4e79cccbf49b5fada9b006377161cdbf.tgz`
into the consuming app with `npm install /absolute/path/to/the/archive.tgz`.
Then run CocoaPods in that app and rebuild iOS when ready. On RN 0.87.1 use
`RCT_USE_PREBUILT_RNCORE=0 pod install`; other versions should follow their normal
Pod setup. Do not copy the example's signing or Metro configuration into the app.
See [iPhone integration](../docs/iphone-integration.md) for the short setup guide.
Until a successful 0.1.2 publish, an ordinary registry install still retrieves the
previous published release and does not include this candidate's changes.
