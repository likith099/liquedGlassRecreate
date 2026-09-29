# Developing the package

The package is in `packages/liquid-glass`; `example` is a bare React Native 0.87.1 demo (React 19,
Fabric) that exercises every component. Contributors follow [the development workflow](../AGENTS.md).

## Run the demo

```sh
npm install
cd example/ios && RCT_USE_PREBUILT_RNCORE=0 pod install && cd ../..
npm start
# In a second terminal:
npm run ios -- --simulator 'iPhone 17 Pro'
# Or, with an Android device or emulator and the Android SDK configured:
npm run android
```

Metro uses port **8093**. The iOS debug build uses localhost in the simulator and the Mac's address
on a device, so the Mac and phone must share a network. Android's CLI and direct Gradle builds use
the same port through `reactNativeDevServerPort` in `example/android/gradle.properties`.

Requires Node 22.11+, Xcode 26+ and CocoaPods. Rebuild both native apps after changing native code.

### Build from Xcode

Run `npm run xcode` to open **`example/ios/LiquidGlassLab.xcworkspace`**, select the
**LiquidGlassLab** scheme and a device or simulator, and run. Open the workspace, not
`LiquidGlassLab.xcodeproj`: the project alone omits the Pods targets and fails with
`AdaptiveLiquidGlass.modulemap not found` or `No such module React`.

### Try an unreleased build in another app

```sh
npm pack --workspace @likith99/react-native-adaptive-liquid-glass --pack-destination artifacts
npm install /absolute/path/to/liquedGlassRecreate/artifacts/likith99-react-native-adaptive-liquid-glass-<version>.tgz
```

## Checks

```sh
npm run typecheck
npm test                       # Jest, including tier snapshots
node scripts/check-pack.mjs    # builds lib/ and inspects the tarball
```

**iOS UI tests** (Metro must be running for Debug builds):

```sh
node scripts/run-ios-ui-tests.mjs testTabBarLifecycleAndFirstTap testVisualTiers
```

The runner picks the newest iPhone simulator (or `--simulator <udid>`), turns off the
multi-gigabyte failure diagnostics, and stops `xcodebuild` if it lingers after the run. Screenshots
are attached to the result bundle. `testVisualTiers` captures each surface tier in light and dark.

**Android checks** drive the installed demo over adb:

```sh
scripts/run-android-checks.sh             # all eight
scripts/run-android-checks.sh menu features
```

Each check starts from a fresh launch and gets one reported retry. A failed attempt saves a
screenshot, the UI tree and error log lines under `artifacts/`. The individual scripts are
`scripts/verify-android-{menu,toolbar,tabs,context-menu,features,slider,accessibility,rtl}.py`; they
default to `emulator-5554` and accept `ANDROID_SERIAL` and `ADB`. A debug build needs Metro on
8093; a release build carries its JavaScript.

**Packed consumer.** `node scripts/verify-package.mjs` packs the library, installs it in a separate
app with its own dependencies, then checks TypeScript and autolinking, builds both JavaScript bundles
and compiles both native apps. Set `ALG_BUILD_CONFIGURATION=Release` for Release builds and
`ALG_CONSUMER_DIR` to reuse an existing `/private/tmp/alg-consumer-*` build. It needs network
access, Xcode and CocoaPods, and `ANDROID_HOME` / `JAVA_HOME`.

## Continuous integration

- `ci.yml` (every push to `main` and every pull request): release-tool tests, typecheck, Jest and
  the pack check.
- `device-tests-ios.yml` and `device-tests-android.yml` (ready, non-draft pull requests that
  change code that platform's app is built from, and on demand; an iOS-only change does not run
  the Android checks and the reverse, and Jest tests or Markdown run neither): iOS UI tests on a
  macOS simulator and all Android checks on API 35 emulators, both with Release builds that carry
  their JavaScript. The iOS job keeps React Native's compiled C/C++/Objective-C in a ccache between
  runs, so only the first run on a pull request compiles everything. The Android demo is built once
  (with Gradle's cache) and its checks run in three emulator jobs at the same time. (A Debug launch
  on a busy runner can fail outright when Metro misses the app's startup check; locally,
  `run-ios-ui-tests.mjs` defaults to Debug and takes `--configuration Release`.)
- `release.yml` (a `v*` tag): acceptance checks, native Release builds, then npm publishing with
  provenance. See [releasing](releasing.md).

## Reference study

The reference packages studied during development are installed only under
`research/references/node_modules`, with their own lockfile, and are not dependencies of the
package or the demo. Restore them with
`npm ci --prefix research/references --ignore-scripts --legacy-peer-deps`.
