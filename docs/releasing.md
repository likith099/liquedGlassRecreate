# Publishing and consuming the package

`@likith99/react-native-adaptive-liquid-glass` is MIT licensed and published to the public npm registry. **0.1.0 was released on September 20, 2026** from commit `2cbf5f8`, tag `v0.1.0`. This is the process for cutting a release and for installing it in another app and its pipelines.

The organization scope is `@likith99` and the publishing account is `likithnmp`, an `owner` of that organization. The login username and organization scope correctly differ. `npm access get status` reports the package `public`.

## One-time setup

For an interactive developer session:

```sh
npm login            # interactive, on a developer machine
npm whoami           # confirms the account
```

**The account must have 2FA enabled to publish at all.** A plain login token is rejected with `403 ... Two-factor authentication or granular access token with bypass 2fa enabled is required`. npm no longer enrols new TOTP authenticators, so 2FA means a WebAuthn security key or passkey (Touch ID, Face ID, Windows Hello, YubiKey); the account is set to `auth-and-writes`. Because a passkey produces no 6-digit code, **do not pass `--otp`** — npm prints an `https://www.npmjs.com/auth/cli/<uuid>` URL, you approve it in the browser, and the CLI continues. Recovery codes are the fallback if a bare `Enter OTP:` prompt appears.

For supported CI providers, use [npm trusted publishing](https://docs.npmjs.com/trusted-publishers/) with OIDC. If that is unavailable, use a scoped, short-lived [granular token](https://docs.npmjs.com/about-access-tokens/) with the publishing permissions required by your account. Classic automation-token instructions are obsolete. Keep credentials in CI secrets; public-package consumers need no token. No publishing workflow is configured in this repository yet.

## Cutting a release

1. Land the change and run the checks: `npm run typecheck`, `npm test`, the platform runtime checks in [README](../README.md#checks), and `node scripts/verify-package.mjs`. The last one packs the tarball and builds it inside a throwaway app on both platforms, which is the real gate for a release.
2. Bump the version. Semver applies to the public API in `src/types.ts` and to native behaviour consumers can observe:
   ```sh
   npm version patch --workspace @likith99/react-native-adaptive-liquid-glass --no-git-tag-version
   ```
3. Inspect exactly what will ship before sending it:
   ```sh
   npm pack --workspace @likith99/react-native-adaptive-liquid-glass --dry-run
   ```
   The list should contain `src`, `ios`, `android`, the podspec, `react-native.config.js`, `README.md` and `LICENSE`, and must not contain `android/build`, `.gradle`, or `node_modules`.
4. Publish. Run this from an interactive terminal: the 2FA challenge needs a TTY, and without one npm exits `EOTP` instead of waiting for the browser approval.
   ```sh
   npm publish --workspace @likith99/react-native-adaptive-liquid-glass --access public
   ```
   Publishing the packed tarball directly also works, but keep the leading `./` — npm parses a bare `artifacts/x.tgz` as a git spec and fails with `git error 128 / Permission denied (publickey)`.
   Confirm package-name availability and account access at release time. Published name/version pairs cannot be reused; consult the current [npm unpublish policy](https://docs.npmjs.com/policies/unpublish) if removal is ever needed. Publishing requires explicit authorization.
5. Tag the commit so the podspec's `source` tag resolves: `git tag v<version> && git push --tags`.

## Consuming it in another app

```sh
npm install @likith99/react-native-adaptive-liquid-glass
cd ios && pod install
```

Then rebuild both native apps once; a JS reload will not pick up new native code. Autolinking finds the iOS podspec and the Android Gradle module inside `node_modules`, so nothing is registered by hand.

The host app must be on **React Native 0.81 to 0.86 with the New Architecture**, because these are Fabric codegen components; 0.81.5 and 0.86.3 are the verified builds. Its iOS deployment target must be **15.1 or higher**, and on 0.81 it must use React Native's prebuilt iOS dependencies rather than building React Native from source. On **iOS 27** the host app must adopt the UIScene lifecycle or iOS traps during scene creation; see the `UIApplicationSceneManifest` and `SceneDelegate` in `example/ios/LiquidGlassLab`.

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
