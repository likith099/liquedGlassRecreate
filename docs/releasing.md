# Publishing and consuming the package

`@likith99/react-native-adaptive-liquid-glass` is MIT licensed and intended for the public npm registry; it has not been published. This is the process for cutting a release and for installing it in another app and its pipelines.

The selected organization scope is `@likith99`. Authenticated registry checks confirmed `npm whoami` returns `likithnmp` and `npm org ls likith99 --json` lists that account as `owner`. The login username and organization scope correctly differ. No registry package has been published; npm may still require an authentication/2FA challenge when publishing.

## One-time setup

For an interactive developer session:

```sh
npm login            # interactive, on a developer machine
npm whoami           # confirms the account
```

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
4. Publish:
   ```sh
   npm publish --workspace @likith99/react-native-adaptive-liquid-glass --access public
   ```
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

- [ ] B4 fallback/menu checks pass; physical Release performance reviewed
- [ ] Release/archive and oldest supported device gaps resolved or explicitly documented
- [ ] Checks pass, including `node scripts/verify-package.mjs`
- [ ] Version bumped and `npm pack --dry-run` inspected
- [ ] `npm publish` run deliberately
- [ ] Git tag pushed for the podspec source
- [ ] Tracker and [verification history](verification.md) updated
