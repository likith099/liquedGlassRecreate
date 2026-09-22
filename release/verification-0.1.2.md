# 0.1.2 release verification

The owner authorized a broad regression pass and publication on September 21,
2026, superseding the earlier no-testing instruction. Version means **0.1.2**.
Use installed runtimes only; VoiceOver and unavailable older physical devices
remain deferred. No claim of exhaustive bug freedom or universal performance.

Local verification completed. Hosted workflow and registry verification remain the final publication steps.

| Scope | Current result |
| --- | --- |
| TypeScript | Passed (`artifacts/rc012-typecheck.log`) |
| JS/API/fallback | 11 suites, 34 tests passed (`artifacts/rc012-jest.log`) |
| Release tools | 10 tests passed after the current runtime/consumer gate update (`artifacts/rc012-release-tools-final.log`) |
| iOS native compile | SwiftUI host and Fabric prop compile passed; Debug linking required local cached-engine restoration |
| iOS 26.5 regression | 14 passed, 2 older-runtime cases skipped, 0 failures; `artifacts/RC012IOS265Retry.xcresult` (16 discovered tests) |
| Explicit SwiftUI switching, merging and RTL | 4/4 passed, exit 0; `artifacts/RC012SwiftUI.xcresult` |
| iOS 18.6 fallback | 8/8 passed, exit 0; `artifacts/RC012Fallback186.xcresult` |
| iPad | 4/4 functional checks passed, exit 0; `artifacts/RC012IPad.xcresult`. Dark portrait and direct landscape captures inspected. |
| Android Release | APK/AAB build passed, exit 0; `artifacts/release-android-build.json` (example debug signing) |
| iOS Release archive | Passed, exit 0; unsigned archive embeds JavaScript (`artifacts/release-ios-build.json`) |
| Independent packed consumer | TypeScript, both production JS bundles and both native Release builds passed, exit 0 (`artifacts/package-smoke.json`) |
| GitHub release workflow / registry artifact | Pending |

The first Debug link failed with missing Hermes debugger symbols. Pods had lost
their last-configuration markers while containing cached Release frameworks, and
React Native's build scripts assumed Debug was already installed. Marking the
cache as Release made the official build scripts restore their existing Debug
archives. No dependency source patch or package workaround was added.

The aggregate run did not discover the newer cases despite a current installed
runner binary. New SwiftUI/RTL cases are selected explicitly after reinstalling
the test runner; a zero-test success cannot satisfy acceptance.

The counts above describe executed tests; skipped cases are not passes. Earlier evidence remains in [the historical review](review-2026-09-20.md).

## Inspected visuals

[SwiftUI stock buttons](screenshots/swiftui-ltr.png), [existing UIKit buttons](screenshots/uikit-ltr.png),
and [SwiftUI merged RTL](screenshots/swiftui-rtl-merged.png) were inspected. Controls
fit the host, icons are visible, the stock tint differs from the current UIKit
treatment, and RTL mirrors the order. The merged capture shows joined glass.
These screenshots establish those rendered states, not frame-rate guarantees.

All four focused test cases and xcodebuild exited successfully. Xcode's optional
`simctl diagnose` subprocess stalled after test completion; it was terminated to
allow result finalization. The completed result bundle and screenshots were
exported. Later runs use `-collect-test-diagnostics never`.

## Verified package archive

The independent consumer installed the 78-file archive with SHA-256
`5d744294ec57048bb4a435f6cb4efabc4e79cccbf49b5fada9b006377161cdbf`.
Its example explicitly selects `iosImplementation="swiftui"`. Release builds
passed for iOS and Android; no Expo or navigation runtime dependency is bundled.
The example archive is unsigned and Android uses example signing: neither is
store distribution acceptance. Physical profiling, iOS 15–17, spoken accessibility
and iPad multitasking remain deferred.

## iPad capture check

The four iPad checks passed in dark mode. The [portrait capture](screenshots/swiftui-ipad-dark.png)
shows the stock buttons and their icons. XCTest application screenshots after
rotation appeared clipped with a black band. A focused repeat of rotation and
merged RTL checks used the same existing binary; a simultaneous direct
`simctl io screenshot` [landscape capture](screenshots/swiftui-ipad-landscape.png)
shows the complete controls without that clipping. Both repeated tests passed, exit 0 (`artifacts/RC012IPadCapture.xcresult`). The demo's RTL content column
is right-aligned. This resolves the capture concern, not narrow multitasking
acceptance. No product workaround was added for the screenshot behavior.

## Hosted runner correction

The first tagged [workflow](https://github.com/likith099/liquedGlassRecreate/actions/runs/35685101630)
passed shared checks but Android setup requested the retired SDK `tools` package
through the action's default. It failed before compilation, so publication did
not run. The native workflow now explicitly requests `platform-tools`, following
[the setup action's documented package input](https://github.com/android-actions/setup-android#additional-packages).
No package source changed; the verified tarball remains identical. The corrected
workflow then passed both native Release jobs on main at `df4cb48`
([run 35685728604](https://github.com/likith099/liquedGlassRecreate/actions/runs/35685728604)).
With the owner's approval, the unpublished `v0.1.2` tag was moved from `e0b3655`
to the commit carrying this record. A re-run could not help, because it would
reuse the tagged commit's broken workflow. Before re-tagging, the local gate
passed with `GITHUB_REF=refs/tags/v0.1.2` (digest `00e93061…b8e0`), and a fresh
`npm pack` again produced SHA-256 `5d744294…cdbf`.
