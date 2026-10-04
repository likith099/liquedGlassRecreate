# 0.1.7 focused release verification

October 3, 2026. Publication authorized by the owner, with only local checks of changed features.
**Published 0.1.7**, tagged `v0.1.7` at commit `68147e7`. The [release workflow](https://github.com/likith099/liquedGlassRecreate/actions/runs/37166257751) completed successfully without hosted tests. npm reports `latest: 0.1.7` and a provenance attestation. The downloaded registry archive is byte-identical to the local verified archive.

Changes: preserve the pending B17 native menu transition/action timing work; remove targeted
preview shadows, resolve preview traits before presentation, and expose `GlassContextMenu`
`colorScheme` for native and fallback menu appearance. No Android native implementation or native
prop schema additions. Version metadata and package documentation advance to 0.1.7.

R1 exact 10 ±1 pt spacing and R2 shadowless open `below` platter are not reachable through the
inspected public API. The shape-preserving margin and native menu placement remain. R2b supplies
appearance before presentation; no all-frame ±1-luma claim or owner visual acceptance is made.
The actual native scaling curve is UIKit's, including the existing B17 transition changes.
See [requirement review](../docs/message-menu-research.md#017-requirement-review--october-3-2026).

Broad regression, a new standalone consumer, older-iOS reruns, Android native rebuild, physical
devices and spoken accessibility checks are omitted under the owner's focused scope. Historical
B17 iOS 18.6 and Android lifecycle evidence is linked in the research document and is not claimed
as a new run of this candidate. No package dependencies, native registration or shared material
implementation changed. The workflow verifies evidence and packages/publishes without hosted tests.

## Local results

- Package JS/declaration build passed. Workspace TypeScript check covers the changed example/API.
- Menu Jest suites: 23 tests across `GlassContextMenu` (5) and `GlassMenuPanel` (18). The first new
  fallback-theme test had an inactive renderer measurement mock; corrected to the existing mock
  pattern and reran only `GlassContextMenu`: all 5 passed. Panel's 18 passed on the first run.
- Release validator tests: 11 passed, including focused-scope authorization, required native
  evidence, and rejection of a deferred source review. Hosted tests removed from release.yml;
  OIDC provenance, tag/source matching and package inspection remain.
- iOS 26.5 / iPhone 17 Pro Max simulator, Release, Xcode exit 0: appearance test 25.476 s and
  conversation transitions 39.520 s. The latter checks repeated close, deferred Copy/Delete,
  disabled action, source-frame restoration, text/image preview geometry. Existing build cache used.
- Initial appearance captures showed preview-only light mode with dark native rows under a dark
  app window. Corrected the demo to call `Appearance.setColorScheme` as the requesting app does,
  and documented the window inheritance limit; only the appearance check is rerun afterward.
- Package inspection passed: 346 files, no generated native build caches or bundled dependencies.
  No new standalone consumer installation or unrelated native regression was executed.

Local artifacts: `artifacts/b18-ios.log`, `b18-menu.xcresult`, `b18-captures/`,
`b18-context-jest.log`, `b18-menu-jest.log`, `b18-release-tools.log`, `b18-types.log`,
`b18-package-build.log`, `b18-pack-check.log`. These files are not shipped or tracked; this report
preserves their outcome. Pixel-level all-frame shadow/flash acceptance remains unverified.

Final appearance follow-up: `b18-appearance-final.xcresult`, Release on iOS 26.5, **passed in
25.617 s, Xcode exit 0**. System set to light; the app cycles inherited/light, forced dark and
forced light. Exported settled dark/light captures in `artifacts/b18-final-captures/` were inspected:
menu rows and content use the matching appearance, with the menu below the selected bubble.
The system-dark/app-light combination with the corrected app-window integration was not rerun;
frame-series luminance and user visual acceptance remain open. Simulator appearance restored to dark.

Final local archive: `likith99-react-native-adaptive-liquid-glass-0.1.7.tgz`, 346 files.
SHA-1: `2744c5830ac63734432cf8a173bd98b193c7729a`.
SHA-256: `18b4422e6fd0435856b8f63d8066dd6d9895fdcffc2389d06c101134929d6106`.
