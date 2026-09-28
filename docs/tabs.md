# Native tab navigation

`GlassTabBar` is a controlled native tab selector. iOS uses a contained UITabBarController with the system Liquid Glass appearance on iOS 26+, and standard UIKit appearance on earlier supported versions. The iOS 18.4+ path uses UITab for native enabled-state presentation; earlier versions use UITabBarItem. Android uses Material BottomNavigationView 1.13.0. Native controls own press feedback and selection animation.

```tsx
import {useState} from 'react';
import {GlassTabBar} from '@likith99/react-native-adaptive-liquid-glass';

export function Tabs() {
  const [tab, setTab] = useState('home');
  return <GlassTabBar
    items={[
      {id: 'home', title: 'Home', icon: 'home'},
      {id: 'inbox', title: 'Inbox', icon: 'inbox', badge: 3},
      {id: 'settings', title: 'Settings', icon: 'settings', badge: 'dot'},
    ]}
    value={tab}
    onValueChange={setTab}
    onTabReselect={id => console.log('Reselected', id)}
  />;
}
```

## Contract

| Input | Behavior |
| --- | --- |
| `items` | 1–5 destinations with globally unique, nonempty `id` and nonempty `title`. Empty arrays require `value=null`. |
| `value` | Controlled destination ID, present in nonempty items. Accept taps by updating this value. |
| `onValueChange(id)` | Enabled tap on a different destination. Rejected requests restore the supplied value after React reconciles. |
| `onTabReselect(id)` | Optional callback for an enabled tap on the current destination. |
| `disabled` / item `disabled` | Blocks user selection. Programmatic values can select a disabled destination without an event. |
| item `icon` | Native presets: home, search, library, favorites, inbox, settings. Default is a circle. |
| item `systemImage` / `selectedSystemImage` | iOS SF Symbol overrides. Invalid primary symbols fall back to a circle. |
| item `image` / `selectedImage` | An iOS asset-catalog name (string), or an image source (`require()` or `{uri}`) on both platforms. Tried before the symbols; see below. |
| item `imageRenderingMode` | `'template'` (default for image sources) takes the tab colours; `'original'` keeps the artwork's colours. |
| item `selectedTintColor` / `inactiveTintColor` | This tab's icon and label colour, selected and not. Static colours only. |
| item `androidIcon` | Drawable resource name in the consuming Android app, tried before `image`. Missing resources fall back to the preset. |
| item `badge` | Nonnegative integer up to 2147483647, or `'dot'`. Numeric display caps at 999+. Omit to remove. |
| item `accessibilityLabel` | Native tab label; defaults to title. Native controls add selection/badge semantics; disabled activation is guarded. |
| `tintColor` | Selected foreground accent. Material and native interaction remain system-owned. |
| `inactiveTintColor` | Unselected icon and label colour of every tab; an item's own `inactiveTintColor` wins. Static colour. |
| `androidBackgroundColor` / `androidIndicatorColor` | Android only: the bar surface and the Material 3 active-indicator pill. iOS keeps the system glass or bar material. |
| `style` / layout props | React host bounds. Defaults: height 80, minimum width 180. No intrinsic Yoga sizing. |

Stable IDs preserve native identity when items reorder. Replacing/removing destinations updates the native list; the same render must supply a valid selected ID. There are no callbacks for programmatic selection. The native host contains no arbitrary React children and exposes no `forceFallback`, custom press physics, or shared glass merging control.

## Layout and installation

On iOS 18.4+ the host drives UIKit's `UITab` list and never installs the legacy view-controller array over it. Selection waits until the native controller is attached to a parent, so items and selection can change in the same render, including while the bar is being rebuilt. Each tab's configured and selected symbols are cached natively. The unselected image is never read back from `tabBarItem`, which UIKit overwrites. Below iOS 26 the bar uses UIKit's standard default-background appearance; without it UIKit would use the transparent scroll-edge appearance.

### Custom artwork and per-tab colours

- `image` / `selectedImage` are tried before `systemImage` / `selectedSystemImage`. A string names an iOS asset-catalog image. An image source works on both platforms:
  - JavaScript resolves it with `Image.resolveAssetSource`: a Metro URL in development, a bundled file (iOS) or drawable resource (Android) in release. For a list of sources, the one closest to the screen scale is used.
  - Native code loads it at runtime and keeps it in memory only (an `NSCache` on iOS, an 8 MB `LruCache` on Android). Nothing is written to disk.
  - While it loads, the tab shows a clear placeholder of the standard size, then its artwork. A source that fails to load falls back to the symbol or preset.
  - iOS scales artwork larger than 30 points down to fit; UIKit does not size tab images. Android draws it at Material's icon size.
- Template images take the tab colours; original-rendering images keep their own colours. Image sources are templates unless `imageRenderingMode: 'original'`.
- `selectedTintColor` / `inactiveTintColor` colour one tab's icon and label. Icons are baked with `.alwaysOriginal`, so they keep their colour under the iOS 26 drag lens. Labels use a per-item copy of the bar's appearance.
- Colours must be static (strings or numbers), because items cross to native code as JSON. `PlatformColor` and `DynamicColorIOS` are rejected.
- On iOS 26 a tab with a custom colour gets its label drawn by the package, and its system title is left empty. The drag lens paints every text label in the selected tab's colour. So the title string is drawn together with the icon, in the tab's colour, into one image per state. The lens then shows each tab's own colour: Library green, Home orange.
- These label images are generated in code at runtime with `UIGraphicsImageRenderer` and kept only in memory by the tab bar. Nothing is written to disk, added to the asset catalog, or looked up from assets. They are redrawn when the title, colours or light/dark mode change.
- The accessibility label still comes from the item, and the badge is moved back to the icon's corner.
- Drawn labels use the system tab label font (10 pt medium), which UIKit also keeps fixed in tab bars. Symbols show the variant you pass: pass `house.fill` if you want the filled look iOS 26 otherwise applies.
- UIKit shows each tab's selected image itself; the host never swaps a tab's image on selection. Swapping left the selected tab's artwork visible under the lens after it moved away.
- Android applies per-tab colours to each Material item view after the bar-wide colours: the tab's colour when checked, its inactive colour otherwise, and the theme's colour while disabled. A selected image becomes a state-list drawable, which Material swaps on the item's checked state.

```tsx
{id: 'home', title: 'Home', systemImage: 'house', selectedTintColor: '#F57C00', inactiveTintColor: '#8A8F98'}
{id: 'brand', title: 'Brand', image: 'BrandIcon', selectedImage: 'BrandIconFilled'}
{id: 'shapes', title: 'Shapes', image: require('./tab-diamond.png'), selectedImage: require('./tab-diamond-filled.png')}
{id: 'logo', title: 'Logo', image: {uri: 'https://example.com/logo.png', scale: 3}, imageRenderingMode: 'original'}
```

Place the bar below the screen content. **On iOS, extend the host to the bottom edge of the screen and add the bottom safe-area inset to its height** (for example `style={{height: 80 + insets.bottom}}`). UIKit then keeps the items above the home indicator, the iOS 26 floating bar sits where native apps place it, and older iOS draws the bar background under the indicator. Padding the host above the indicator instead leaves the iOS 26 bar 34 points too high (measured on iPhone 17 Pro Max). Apply side insets outside the host. On Android, apply the bottom inset outside the host; the in-host Android behaviour has not been verified yet. Supply sufficient width for up to five destinations and increase height as appropriate for accessibility text. UIKit remains in compact tab-bar mode on iPad. This component does not provide a sidebar, automatic scroll minimization, or a native navigation stack.

Rebuild iOS and Android after installation; run `pod install` for iOS. Android adds Material Components 1.13.0 through the library Gradle dependency. It uses the application's Material theme when available, otherwise Material 3 DayNight. No Expo, React Navigation, or react-native-screens dependency is required by the package itself.

## React Navigation example

The demo's [adapter](../example/navigation/NativeNavigationTabBar.tsx) is passed to a React Navigation 7 bottom-tab navigator through its `tabBar` prop. It maps **route keys**, not display labels or array positions, to native IDs. Both selection and reselection emit `tabPress` with `canPreventDefault: true`; navigation occurs only for a different route when that event is accepted. The router owns screens, retained component state, route parameters, and Android back history. Insets from the navigator wrap the native host.

The [demo](../example/TabNavigationDemo.tsx) includes prevented Inbox navigation, disabled tabs, programmatic navigation, reordering, route replacement, badges, and screen counters. Open **Open tab navigation →** in the component lab. The adapter is an integration example, not a drop-in implementation of every React Navigation tab-bar option: custom React icon renderers, long-press events, and scroll-driven minimization are outside this batch.

## Verification scope

Shared API/event tests and adapter tests live under `example/__tests__`. Native interaction coverage is `GlassInteractionTests/testNativeTabNavigationBatch` on iOS and `scripts/verify-android-tabs.py` on Android. On the iOS 26.5 simulator, XCTest reports disabled tabs as enabled even when UIKit dims them and blocks taps. The runtime test asserts unchanged selection and event count; VoiceOver disabled-state announcements remain part of the accessibility audit. Source existence alone is not a passing test result.

## Platform references

Apple documents the system-owned tab design in its [UIKit design session](https://developer.apple.com/videos/play/wwdc2025/284/) and [UITabBarController API](https://developer.apple.com/documentation/uikit/uitabbarcontroller). Android uses the public [Material Components 1.13.0 release](https://github.com/material-components/material-components-android/releases/tag/1.13.0). The adapter follows React Navigation's [custom bottom-tab bar contract](https://reactnavigation.org/docs/bottom-tab-navigator/).

## Adaptive layout and accessibility

The default 80-point host grows with the system font scale; an explicit style height wins. Android enables Material label scaling and permits two lines. Keep titles short and provide enough width for all items; native tab bars do not become scrollable lists. Screen-owned safe-area padding still applies. Each native tab is exposed by the platform as a labelled button that reports its own selected state, and Android also reports the disabled state. `UITab.isEnabled` dims a disabled iOS tab and blocks its selection, but UIKit exposes no public API for a tab's accessibility traits, so a disabled iOS tab still reports itself as enabled to the accessibility client. Accessibility-tree checks and actual spoken VoiceOver behavior are separate evidence; see [accessibility](accessibility.md).
