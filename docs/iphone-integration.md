# Use in an iPhone app

The 0.1.2 candidate is prepared locally. Install its archive to use the latest
changes before publication. This hash-named file also avoids reusing an earlier
local 0.1.2 archive from npm's cache:

```sh
# Run in your other React Native project's root:
npm install /Users/likith_k/liquedGlassRecreate/artifacts/consumer-5d744294ec57048bb4a435f6cb4efabc4e79cccbf49b5fada9b006377161cdbf.tgz
cd ios
pod install
```

For React Native **0.87.1**, replace `pod install` with
`RCT_USE_PREBUILT_RNCORE=0 pod install` to avoid the prebuilt React-Core header
issue. Rebuild the iOS app when ready; native changes require a build. No package
test run or device session is required just to install it. After 0.1.2 is published,
use `npm install --save-exact @likith99/react-native-adaptive-liquid-glass@0.1.2`
and commit the consuming app's lockfile. Keep a local tarball available at a
portable path if committing a `file:` dependency before publication.

Requirements: React Native 0.81+, React 19, New Architecture, Xcode 26+, and a host
deployment target of at least iOS 15.1 (or the higher minimum your RN version needs).
Retain the host's signing, scene lifecycle and safe-area handling. In particular,
the iOS 27 device used here required scene lifecycle adoption in the host app.

```tsx
import {useState} from 'react';
import {GlassButton, GlassView} from '@likith99/react-native-adaptive-liquid-glass';
import {PlatformColor, Text} from 'react-native';

export function SaveControl() {
  const [saved, setSaved] = useState(false);
  return (
    <>
      <GlassView style={{padding: 16}}>
        <Text style={{color: PlatformColor('labelColor')}}>
          {saved ? 'Saved' : 'Ready to save'}
        </Text>
      </GlassView>
      <GlassButton title={saved ? 'Saved' : 'Save'} systemImage="bookmark"
        disabled={saved} onPress={() => setSaved(true)} />
    </>
  );
}
```

On iOS 26+ this uses native glass. Below 26, surfaces use UIKit blur and buttons
use the standard fallback. `forceFallback` selects an opaque surface when desired.
Merging is off by default. Avoid stacks of blurred backgrounds in dense lists;
keep glass to visible controls and bounded areas.

Use flexible widths for controls. For action clusters, allow height to grow when
the narrow-width fallback wraps; use a `GlassToolbar` when overflow menus better
suit a dense action set. The host app owns safe-area padding around tabs/toolbars.

For the expandable cluster, `iosImplementation="uikit"` preserves the current
appearance (the default); `iosImplementation="swiftui"` chooses Apple's standard
SwiftUI glass buttons. See [the options and prop differences](action-clusters.md).

The final candidate passed shared checks, iOS 26.5 SwiftUI/RTL runtime checks,
iOS 18.6 fallback checks, and both native Release builds in an independent
packed consumer. iOS 15–17 execution, full physical profiling, spoken
accessibility and narrow iPad multitasking remain deferred. See the
[verification report](../release/verification-0.1.2.md).
