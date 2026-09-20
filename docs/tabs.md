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
| item `androidIcon` | Drawable resource name in the consuming Android app. Missing resources fall back to the preset. |
| item `badge` | Nonnegative integer up to 2147483647, or `'dot'`. Numeric display caps at 999+. Omit to remove. |
| item `accessibilityLabel` | Native tab label; defaults to title. Native controls add selection/badge semantics; disabled activation is guarded. |
| `tintColor` | Selected foreground accent. Material and native interaction remain system-owned. |
| `style` / layout props | React host bounds. Defaults: height 80, minimum width 180. No intrinsic Yoga sizing. |

Stable IDs preserve native identity when items reorder. Replacing/removing destinations updates the native list; the same render must supply a valid selected ID. There are no callbacks for programmatic selection. The native host contains no arbitrary React children and exposes no `forceFallback`, custom press physics, or shared glass merging control.

## Layout and installation

Place the bar below the screen content. Apply bottom/side safe-area spacing **outside** the native host, exactly once. Supply sufficient width for up to five destinations and increase height as appropriate for accessibility text. UIKit remains in compact tab-bar mode on iPad. This component does not provide a sidebar, automatic scroll minimization, or a native navigation stack.

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
