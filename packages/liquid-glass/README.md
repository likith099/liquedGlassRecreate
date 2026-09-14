# react-native-adaptive-liquid-glass

Native iOS Liquid Glass surfaces and UIKit action controls, with ordinary Android counterparts. No Expo dependency. Initial prototype for React Native 0.86 / React 19 / Fabric; requires Xcode 26+, and iOS 16.4+ (glass on iOS 26+).

Install the locally packed `.tgz` in your app, run `pod install` in its iOS folder, and rebuild both native apps. Android autolinks Kotlin SeekBar, PopupMenu, Toolbar, and Material BottomNavigationView bridges; surfaces and the other Android controls use React Native views and pressables. The package is not yet published.

```tsx
import {GlassView, GlassButton, GlassContainer, GlassActionCluster} from 'react-native-adaptive-liquid-glass';

<GlassView interactive cornerRadius={24} style={{padding: 20}}>
  <Text>React content inside native glass</Text>
</GlassView>

<GlassActionCluster
  actions={[{id: 'save', title: 'Save', systemImage: 'bookmark'}]}
  expanded={expanded}
  onExpandedChange={setExpanded}
  onAction={id => handleAction(id)}
/>
```

`GlassView` accepts material (`regular`, `clear`, `none`), interactive, tintColor, cornerRadius, colorScheme, animationDuration (seconds), fallbackStyle, and forceFallback. Use cornerRadius instead of style.borderRadius. `GlassPressable` adds custom React children, press semantics and Android ripple. `GlassButton` with a `title` uses a fully native SwiftUI button on iOS 26+. Existing children-based GlassButton calls remain compatible. `GlassContainer.mergingEnabled` defaults to false. Set it to true to allow nearby surfaces to join; `spacing` then controls the merging threshold, independently of layout gap. The action cluster also defaults to `mergingEnabled={false}`; enable it to opt into native glass merging during expansion and collapse. For a GlassContainer, place participating GlassViews inside it.

The UIKit action cluster retains controls by stable IDs and uses the same UIGlassEffect material host as GlassView. The toggle keeps its material, bounds, and opacity unchanged during expansion. UIKit owns the native finger-localized highlight and deformation whenever `interactive` is enabled. There is no custom press overlay, scale, or finger-follow animation. SF Symbols remain inside the effect content view, so UIKit deforms the icon and glass together. A tap recognizer observes activation without cancelling or delaying native glass touches. There is no separate UIControl or forced hit-test target. Default dark-mode actions apply a neutral black native material tint at 0.65 alpha to reduce lightness. This also darkens the resting material; it is not a highlight-strength percentage. Light mode uses transparent tint. An explicit tintColor overrides the default. UIKit still owns the highlight and provides no separate intensity setting. The old `pressFeedback` prop is deprecated and ignored. `interactive={false}` disables native press visuals without disabling callbacks. Android keeps its normal ripple. Opt-in merging uses UIGlassContainerEffect and animated UIKit geometry; SwiftUI matched-geometry transitions are no longer used. Supply unique nonempty action IDs; `__toggle` is reserved. Keep expanded controlled. iOS renders SF Symbols with accessible titles, while Android displays titles on ordinary buttons. Allow approximately `24 + 52 * (actions.length + 1) + 12 * actions.length` points of width and at least 80 of height. Arbitrary React children are supported by the surface, but not the action cluster.

Reduce Transparency replaces our glass surface/cluster materials with opaque backgrounds. Reduce Motion suppresses our native property/morph transitions. Use semantic text colors for your children; the package does not recolor arbitrary content. `forceFallback` previews the standard implementation on surfaces, buttons, selectors, and action clusters. The native slider has no `forceFallback` prop.

See `src/types.ts` for the complete typed API. The repository root README contains the demo commands, architecture, reference study, and verification results. Custom drag/stretch physics, a full native control suite, arbitrary React-tree morphing, physical-device profiling, and broader React Native compatibility remain future work. Before publishing, choose a license and replace the placeholder podspec source/metadata.

## Native controls

`GlassButton` accepts `title`, optional `systemImage` (iOS), `variant="regular" | "prominent"`, `disabled`, `loading`, `onPress: () => void`, tintColor, colorScheme, forceFallback, and view layout props. Loading prevents activation. Default native host height: 64 points. For custom children/material/shape, use GlassPressable.

`GlassSegmentedControl` accepts `options: {value, label, disabled?}[]`, controlled `value: string | null`, `onValueChange`, disabled, tintColor, colorScheme, forceFallback, and view layout props. Values must be unique and nonempty; a non-null selection must be present. It uses UISegmentedControl on iOS 26+ and selectable ripple buttons on Android. Default native host height: 52 points. Provide enough width for short labels, and larger heights for large accessibility text. Neither control enables shared glass merging.

## Native slider

```tsx
import {useState} from 'react';
import {GlassSlider} from 'react-native-adaptive-liquid-glass';

export function LevelControl() {
  const [level, setLevel] = useState(40);
  return <GlassSlider value={level} onValueChange={setLevel}
    minimumValue={0} maximumValue={100} step={10}
    accessibilityLabel="Level" />;
}
```

`GlassSlider` uses UISlider on iOS (Liquid Glass on iOS 26+, standard native appearance on older versions) and SeekBar on Android. Defaults: minimum 0, maximum 1, step 0 (continuous), height 52 points. It also accepts `disabled`, `tintColor`, `onSlidingStart`, `onSlidingComplete`, `onSlidingCancel`, and view layout props. The native slider owns tracking and reconciles to the latest controlled `value` after release, including a rejected change. Update `value` in `onValueChange` to accept changes. Programmatic changes during tracking apply when it ends.

Values clamp and positive steps snap relative to the minimum; the maximum endpoint remains reachable. Require finite inputs, maximum greater than minimum, and step between zero and the range. Native positioning uses normalized Float precision on iOS and one million ticks on Android; this is not an arbitrary-precision numeric input. Accessibility increments by step or 5% of the range. Provide an accessible label.

Native cancellation, disabling, range/step changes, or detachment cancel an active drag. `onSlidingCancel` reports the restored latest controlled value and does not fire completion or undo values React already accepted. No custom thumb children, tick-mark API, neutral-track style, or shared merging group is added. Apple's [UIKit design session](https://developer.apple.com/videos/play/wwdc2025/284/) describes the native slider's system interaction.

## Native menus

```tsx
import {GlassMenuButton} from 'react-native-adaptive-liquid-glass';

<GlassMenuButton title="Actions" systemImage="ellipsis.circle"
  items={[{id: 'save', title: 'Save', systemImage: 'bookmark'},
    {id: 'remove', title: 'Remove', destructive: true}]}
  onAction={id => console.log(id)} />
```

iOS uses UIKit's native menu and glass button; older iOS, Reduce Transparency, or forceFallback uses a standard button. Android uses a native Button and PopupMenu. Items support disabled, destructive, and controlled checked flags. IDs must be unique and IDs/action titles nonempty. Empty items disable the trigger. SF Symbols are iOS-only. A selection emits its ID; update checked in your items to change the checkmark. Destructive is presentation only. Changing items, disabling, or detaching dismisses the native menu and stale selections are rejected. The default host is 64 points tall with a minimum width of 120; supply room for long titles and accessibility text. tintColor is a foreground accent (including enabled Android menu text; destructive entries retain their error color). Rebuild both native apps after installing this version.

`GlassMenuElement` extends the existing action type with `{kind: 'section', id, title, items}` and `{kind: 'submenu', id, title, items, disabled?, systemImage?}`. Sections may have an empty title. Groups must contain items; IDs are unique across all groups and leaves. Only enabled leaf actions emit callbacks; a disabled submenu blocks its descendants. UIKit displays inline sections; Android uses native groups and disabled title rows. One submenu level is supported on both platforms, with at most 8 total tree levels including sections and 256 elements. Submenus inside submenus are rejected. Existing flat arrays remain compatible.

## Native toolbars

```tsx
import {GlassToolbar} from 'react-native-adaptive-liquid-glass';

<GlassToolbar items={[
  {id: 'save', title: 'Save', systemImage: 'square.and.arrow.down'},
  {kind: 'submenu', id: 'sort', title: 'Sort', items: [
    {id: 'name', title: 'By name', checked: true},
    {id: 'recent', title: 'Most recent', checked: false},
  ]},
  {id: 'remove', title: 'Remove', destructive: true, placement: 'overflow'},
]} maxVisibleItems={2} onAction={id => console.log(id)} />
```

`GlassToolbar` uses UIKit UIToolbar / Android Toolbar. Root items are actions or submenus; their menus use the same tree contract above. `maxVisibleItems` defaults to 3 and is an upper bound; 0 places everything in overflow. `placement="overflow"` always hides a root item in the native overflow menu. Other items move there as space becomes limited; platforms may show different visible counts. The host defaults to height 64, minimum width 64. The screen owns safe-area insets and placement. Long titles should be allowed to move to overflow; provide explicit width/flex in horizontal layouts.

On iOS 26, `mergingEnabled` (default false) lets bar items share native glass backgrounds. `forceFallback` and Reduce Transparency use an opaque bar with hidden shared item backgrounds. Android uses its standard appearance and title actions; iOS uses SF Symbols when supplied, retaining titles as accessibility labels. `disabled` blocks all actions; individual items/submenus can also be disabled. Checkmarks remain controlled. `tintColor` sets a foreground accent; destructive actions use the native error color. Changing items or toolbar width dismisses open menus. Rebuild native apps for the extended Fabric bridge. No custom press animation or navigation-library dependency is introduced.

## Native tabs

```tsx
const [tab, setTab] = useState('home');
<GlassTabBar items={[
  {id: 'home', title: 'Home', icon: 'home'},
  {id: 'inbox', title: 'Inbox', icon: 'inbox', badge: 3},
]} value={tab} onValueChange={setTab} onTabReselect={id => console.log(id)} />
```

`GlassTabBar` uses a contained UITabBarController on iOS and Material BottomNavigationView 1.13.0 on Android. UIKit owns Liquid Glass on iOS 26+ and the standard tab appearance on earlier supported versions. Android resolves a consuming Material theme or falls back to Material 3 DayNight. No Expo or navigation library is required by the package. Rebuild both apps after installation.

Supply 1–5 items with unique nonempty IDs/titles and a `value` present in the list. Empty items require `value={null}`. Items accept icon presets (`home`, `search`, `library`, `favorites`, `inbox`, `settings`), iOS `systemImage`/`selectedSystemImage`, Android app drawable name `androidIcon`, numeric or `'dot'` badge, `disabled`, and `accessibilityLabel`. Numeric badges are nonnegative 32-bit integers; native display caps at 999+. Omitting a badge removes it.

Selection is controlled: update `value` in `onValueChange` to accept a tap. Rejected changes restore the supplied value after the React transaction; tapping the current tab calls only `onTabReselect`. Programmatic values emit no callbacks and may select disabled tabs. Global `disabled` blocks user taps. On the iOS 26.5 simulator, XCTest still reports disabled tabs as enabled despite native dimming and blocked activation; VoiceOver announcements need the planned accessibility audit. `tintColor` changes the selected foreground accent. Stable IDs preserve tab identity across reorder/replacement; native controls own press and selection animations.

Default host height is 80 points, minimum width 180. Supply sufficient width/height for your labels. The screen owns safe-area spacing outside the host and the content above it. This primitive does not own a navigation stack, React screens, automatic scroll minimization, or an iPad sidebar. It does not accept React children or `forceFallback`; the native system determines its appearance. The repository demo shows a React Navigation 7 custom tab-bar adapter using route keys, preventable `tabPress`, reselection, retained screen state, and back history.
