# Publishing and consuming the package

`@likith99/react-native-adaptive-liquid-glass` is MIT licensed and published to the public npm registry. **0.1.1** is the current release; 0.1.0 was the first, released on September 20, 2026. From 0.1.1 onward releases are published by the [release workflow](../.github/workflows/release.yml) on a `v*` tag, using npm trusted publishing, and carry a signed provenance attestation. This is the process for cutting a release and for installing it in another app and its pipelines.

The organization scope is `@likith99` and the publishing account is `likithnmp`, an `owner` of that organization. The login username and organization scope correctly differ. `npm access get status` reports the package `public`.

## Publishing setup

The existing [release workflow](../.github/workflows/release.yml) uses
[npm trusted publishing](https://docs.npmjs.com/trusted-publishers/) with GitHub
OIDC. The npm publisher is bound to the repository and `release.yml` filename;
keep that identity when changing the pipeline. Only the publish job receives
`id-token: write`. Consumers of this public package need no npm credentials.

The first release used interactive npm login and account 2FA. Normal releases
now use the tag workflow; an interactive publish would bypass its checks.

## Cutting the next release

1. Review the [iPhone-first candidate](../release/iphone-first-0.1.2.md) and
   [release policy](release-acceptance.md). Run the SwiftUI/current-iOS, older-iOS fallback and packed Release consumer
   checks. The owner authorized testing and publishing; remaining manual/device
   deferrals are coverage limits and must not be relabeled as passes.
2. Keep the package version, example dependency and npm lockfile synchronized.
   They are already set to **0.1.2** for this candidate. Screenshot URLs can stay
   pinned to the version from which the captures came.
3. Record source review and documented deferrals in `release/acceptance.json`.
   After final source edits, get the digest with
   `node scripts/check-release-acceptance.mjs --print-digest`. A digest identifies
   reviewed source; it does not mean tests passed. Commit the candidate and its
   durable review report together so the evidence survives a clean clone.
4. Push the candidate commit and its matching `v0.1.2` tag when proceeding with
   publication. The tag triggers shared checks, both native Release builds, then
   OIDC publishing with provenance. Do not bypass a CI failure with manual publish.
   Push only the intended tag. A branch dispatch cannot publish, and published
   name/version pairs cannot be reused.
5. Inspect Actions results and verify the registry artifact as described below.

The earlier source-review pass did not execute tests. The subsequent
[release verification](../release/verification-0.1.2.md) records actual candidate execution. The
unsigned iOS archive and demo-signed Android bundle are build checks. Signing and
store delivery belong to the host app; they are not prerequisites for publishing
this native source package under the agreed scope.

## Consuming it in another app

```sh
npm install @likith99/react-native-adaptive-liquid-glass
cd ios && pod install
```

Then rebuild the native app you are using; a JS reload will not pick up new native code. Autolinking finds the iOS podspec and the Android Gradle module inside `node_modules`, so nothing is registered by hand.

The host app must use **React Native >=0.81 with the New Architecture**. Builds have been verified at 0.81.5, 0.86.3 and 0.87.1; the unbounded peer range does not establish future-version compatibility. See [compatibility](compatibility.md) for version-specific setup, including the RN 0.87 source-mode workaround. Its iOS deployment target must be **15.1 or higher**, and on 0.81 it must use React Native's prebuilt iOS dependencies rather than building React Native from source. On **iOS 27** the host app must adopt the UIScene lifecycle or iOS traps during scene creation; see the `UIApplicationSceneManifest` and `SceneDelegate` in `example/ios/LiquidGlassLab`.

## Pipelines and environments

Because the package is public, dev, UAT and production pipelines install it the same way, with no registry credentials:

- Pin an exact version or a caret range in the app's `package.json` and commit the app's lockfile. The lockfile, not the range, is what makes dev, UAT and production install identical bytes.
- Use `npm ci` in pipelines rather than `npm install`, so the lockfile is authoritative and the build fails instead of silently resolving a different version.
- Cache `~/.npm` and the CocoaPods cache between runs; the pod is built from `node_modules`, so a fresh `pod install` is required whenever the package version changes.
- Native code is included in the host app archive/APK/AAB. Final candidate Release builds and distribution archives still need validation; Debug consumer builds do not establish store readiness.

## Release checklist

State for 0.1.0:

- [x] B4 fallback/menu checks pass — **physical Release performance still not profiled**
- [x] Release/archive and oldest supported device gaps explicitly documented, not resolved; see [compatibility](compatibility.md)
- [x] Checks pass, including `node scripts/verify-package.mjs`
- [x] Version set and packed contents inspected — 77 files, no `node_modules`, `android/build` or `.gradle`
- [x] `npm publish` run deliberately, with explicit user authorization
- [x] Git tag `v0.1.0` pushed for the podspec source
- [x] Development records updated

After publishing, confirm the registry copy is the artifact you verified rather than trusting the CLI's exit code:

```sh
npm view @likith99/react-native-adaptive-liquid-glass version dist.shasum dist.fileCount
npm pack @likith99/react-native-adaptive-liquid-glass@<version>   # then compare sha256 with the local tarball
```

A first publish can return `PUT 200` while anonymous `GET` still 404s for a minute or two; that is read-path propagation, not a failed publish. `npm access list packages` and `npm access get status <pkg>` distinguish a propagating package from a genuinely missing or private one.

## Next-release gate

The [acceptance record](../release/acceptance.json) uses schema 2 and the
`iphone-first` scope. Documented owner deferrals do not block publication. Source
review, SwiftUI/fallback runtime evidence, the packed Release consumer, exact
source/version/tag matching, shared CI and native Release builds
remain required. Current local changes still need commit/push; 0.1.2 is not yet
published. To use these changes now, follow [iPhone integration](iphone-integration.md).
