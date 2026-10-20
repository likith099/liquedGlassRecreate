# 0.2.0 development API and research

This is an unpublished implementation under verification. Existing 0.1.7 exports and defaults remain available. New native components require `pod install` and a native rebuild. No Expo Modules, Reanimated, or new runtime dependencies are needed. The package version stays at 0.1.7 until release preparation is authorized.

## Controls

```tsx
<GlassIconButton symbol={{name: 'chevron.backward', pointSize: 16.5, weight: 'semibold'}}
  controlSize="regular" accessibilityLabel="Back" onPress={goBack} />
<GlassIconButton symbol="bell" badge={{count: 77}} badgeColor="#E33B42"
  accessibilityLabel="Notifications" onPress={openNotifications} />
<GlassIconGroup items={[
  {id: 'save', symbol: 'heart', accessibilityLabel: 'Save', pressEffect: 'bounce'},
  {id: 'more', symbol: 'ellipsis', accessibilityLabel: 'More', menu: {items, onAction}},
]} onPress={onAction} />
<GlassPillBar items={[{id: 'all', label: 'All'}, {id: 'saved', label: 'Saved', badge: 2}]}
  value={scope} onValueChange={setScope} />
<GlassMorphButton anchor="trailing" content={editing
  ? {kind: 'title', title: 'Done', accessibilityLabel: 'Done'}
  : {kind: 'symbol', symbol: 'ellipsis', accessibilityLabel: 'More'}} onPress={toggleEditing} />
<GlassPresence visible={editing} onExited={onExit}>
  <GlassIconButton symbol="trash" accessibilityLabel="Delete" onPress={remove} />
</GlassPresence>
```

`GlassSymbol` accepts a name or an object with `name`, `pointSize`, nine SF Symbol weights, `scale`, `rendering` (`monochrome`, `hierarchical`, `palette`, `multicolor`), `paletteColors` and `variableValue` (0–1). Palette and badge colours must be static. `image` accepts a React Native image source; `androidIcon` names an Android drawable. Icon buttons also accept an Android React icon overlay. SF Symbols are not available on Android; provide artwork there. Images use the package's cached native URI loader, not a new networking dependency; authenticated request headers are not forwarded.

`contentTransition` is `none` by default; `replace`, `replaceDownUp`, `replaceUpUp` and `automatic` opt into symbol replacement. `pressEffect="bounce"` opts into a discrete symbol effect. Availability: image-view effects/transitions require iOS 17; button configuration transitions require **iOS 26** (the request's iOS 18 assumption was incorrect). Reduce Motion disables these effects. Existing `systemImage`, `symbolPointSize` and raw `size` remain accepted; explicit `size` takes precedence over `controlSize`.

| controlSize | Points / dp |
| --- | --- |
| mini | 28 |
| small | 36 |
| regular | 44 |
| large | 50 |
| extraLarge | 56 |

These are exported **package layout constants**, not measured intrinsic values promised by Apple's `buttonSize` enum. Icon buttons use the exact dimensions; grouped and title controls allow larger text and maintain a 44-point minimum target. `GlassMetrics` also exports pill geometry, group ink spacing, symbol sizes and a 16/20-point page inset split at 414 points. The request supplied the reference measurements; new reference pixel comparisons are pending.

Groups use one interactive UIKit glass capsule and individually addressable native buttons. Pills use separate UIKit glass buttons without a shared glass container, isolating their highlights; they remain controlled, scroll on overflow, and distinguish selection from trailing actions. On iOS, title pills reserve the larger regular/semibold text width so selection never shifts the row or badge resting positions. Android uses solid surfaces, ripples and platform menus. Each item accepts a stable `id`, label and `testID`. Use resource names for group/pill Android icons; React icon elements inside those native rows are not yet supported.

Morph buttons retain one native button and animate layout changes. Native controls report their intrinsic size once per content/font change; this currently uses a native size event and a React layout commit, **not a custom Yoga measuring shadow node**. Initial-layout and blocked-JS acceptance therefore remain open. `GlassPresence` retains children until native exit completion and reports once, including cleanup during exit. A re-entry cancels the exit. No iOS ancestor opacity animation is used; presence currently animates transforms, while `GlassView transition="materialize"` animates effect assignment. A full effect-removal exit and Reduce Motion content cross-fade are still under development. Direct children with the same `glassID` can pair across a commit inside an iOS `GlassContainer`; arbitrary nested descendants and Android matched identity are not implemented.

## Corner badges

Every glass control that shows a badge takes the same four props:

| Prop | Values | Default |
| --- | --- | --- |
| `badge` | `{count: n}` (nonnegative integer; above 99 shows `99+`), `{text: 'New'}` (short, nonempty), `{indicator: true}` (a dot that only says something is waiting), or `null`/omitted to hide | none |
| `badgeColor` | static colour for the fill | red (`#FF3B30` / system red) |
| `badgeTextColor` | static colour for the count or text | white |
| `badgeAccessibilityLabel` | what VoiceOver/TalkBack reads, e.g. `'3 unread messages'` | `'<count> new'`, the text, or `'New'` for a dot — **English**; pass a localized string |

```tsx
<GlassIconButton symbol="bell" accessibilityLabel="Notifications"
  badge={{count: 12}} badgeColor="#D53A45" badgeAccessibilityLabel={t('unread', {count: 12})} onPress={openInbox} />
<GlassIconButton symbol="envelope" accessibilityLabel="Inbox" badge={{indicator: true}} onPress={openInbox} />
<GlassIconButton symbol="tray" accessibilityLabel="Updates" badge={{text: 'New'}}
  badgeColor="#FFD60A" badgeTextColor="#1C1C1E" onPress={openUpdates} />
<GlassView badge={{text: 'New'}} badgeColor="#FF9500" style={{width: 100, height: 48}}>{/* content */}</GlassView>
```

Where each control takes them:

| Control | Where | Notes |
| --- | --- | --- |
| `GlassIconButton`, `GlassButton`, `GlassMenuButton` | props | animated with the glass press on iOS 26 |
| `GlassIconGroup`, `GlassToolbar` | each item | toolbar: the toolbar's own buttons only (see menu rows) |
| `GlassPillBar` | each item; `badge` also accepts a plain number | a pill reads its position, then its badge ("2 of 4, 2 new") |
| `GlassMorphButton` | inside `content` | |
| `GlassTabBar` | each item; `badge` also accepts a number or `'dot'` | `badgeColor`/`badgeTextColor` supported; the platform tab bar announces the badge itself, so there is no `badgeAccessibilityLabel` |
| `GlassView` | props | static (no press to ride); give the surface an explicit size and let surrounding layouts overflow |

Platform notes:

- **Menu rows can't show badges.** Apple's native menus have no row badge, and Android menus keep the same rows. A badge on a dropdown or context-menu item is ignored with a one-time development warning; put it on the control that opens the menu or in the item title.
- **Toolbars:** iOS 26 draws badges on toolbar buttons; iOS below 26 has no toolbar badge API, so badges there are omitted. On Android, visible toolbar buttons get Material's standard badge; buttons moved into the overflow menu say the badge in their spoken label.
- **Android tab bar default colour:** without `badgeColor`, Material uses the theme's error colour, which is a light pink with dark text in dark mode. That is standard Android; pass `badgeColor` (e.g. `'#FF3B30'`) and `badgeTextColor` to match your brand. With React Navigation, map the standard `tabBarBadgeStyle` (`backgroundColor`, `color`) to these props, as the example's adapter does.
- **Cap:** every control, including tabs, caps counts at `99+`. (0.1.x tabs showed up to `999+`.)
- `GlassPressable` has no badge prop.

On iOS 26 glass buttons, the badge follows the public background attachment's press scale, holds its peak during a tracked hold, and uses a bounded touch-based lean and release spring. The lean and spring are approximations: public UIKit APIs do not expose the glass lens's full deformation. When UIKit cancels control tracking during a drag, live scale tracking continues but touch-based lean can stop. Exact finger tracking and release feel still need manual acceptance.

Grouped-control badges render above the glass container so menu-dismissal clipping does not crop their corners. The native button owns badge layout throughout press/release; its parent does not reset the animated pose.

Transient out-of-control background coordinates at highlight onset are ignored so reattachment cannot make the badge disappear for a frame. During morph/header frame animations the badge follows the button's interpolated corner and retires the preceding press scale, without treating a width change as press enlargement. A newer frame animation supersedes an interrupted animation's completion. Reduce Motion skips the frame animation. Android draws badges on its native controls; they are not deformed by a press (there is no glass), but on morph and header capsules the badge rides the animated edge. Plain `GlassView` badges are static on both platforms. Older-iOS controls retain their existing fallback materials and availability guards.

## Persistent headers

```tsx
<GlassHeaderHost topInset={insets.top}>
  <Stack.Navigator screenOptions={{headerShown: false}}>{/* screens */}</Stack.Navigator>
</GlassHeaderHost>

// In each screen, using its navigation library's focus state:
useGlassHeader({routeKey: route.key, active: isFocused,
  leading: [{slot: 'back', kind: 'back', accessibilityLabel: 'Back', onPress: navigation.goBack}],
  trailing: [{slot: 'primary', kind: 'title', title: 'Done', accessibilityLabel: 'Done', onPress: finish}],
});
```

This is an **experimental integration**. Keep slot names stable and memoize item arrays. The host does not replace a navigator delegate or depend on a router package. It uses a discoverable UIKit transition coordinator when available. Registration-before-push, interactive cancellation, accessibility focus, exact navigation-bar bulging and a JS-stall recording are not established; do not assume Passwords-equivalent transitions. The example's persistent-header section demonstrates state changes, not a native-stack swipe test.

On iOS, morph buttons and header slots use independent glass buttons. A retained slot reuses its material configuration when its content changes. New titles are laid out on one line before the width animation, and content layout completes with the resize. Native control and React Native wrapper width changes share a 0.25-second critically damped animation so the lens finishes resizing before the native release-lighting tail; Reduce Motion applies the final geometry immediately. Native press lighting remains enabled. Use the fields for the chosen content kind: `{kind: 'title', title: 'Done', ...}` or `{kind: 'symbol', symbol: 'ellipsis', ...}`; the demo switches between these rather than showing both together. On Android, a slot whose content changes keeps one capsule and animates its width from the edge it is anchored to while the icon and title cross-fade (Material emphasized easing, 300 ms; `GlassMorphButton` 420 ms); a slot that appears fades in at full size and one that leaves shrinks to its centre and fades. `kind: 'back'` uses the package's Material back arrow on Android.

## Tabs and additional Apple APIs

`GlassTabBar` adds `minimizeBehavior` (`never`, the unchanged default; `automatic`, `onScrollDown`, `onScrollUp`) and a `scrollViewRef` on each item. On iOS 26 the destination controller associates that React scroll view with its bottom edge. `bottomAccessory` supplies React content to `UITabAccessory`; use `bottomAccessoryHeight` (default 44) and reserve sufficient host height. Older iOS and Android place an ordinary bar above the tabs. Their tab bars do not minimize.

Additional gaps found in the Apple review:

- `GlassIconButton material="clear"` selects `clearGlass()` / `prominentClearGlass()` on iOS 26. Regular remains the default.
- `GlassBackgroundExtension` wraps `UIBackgroundExtensionView` on iOS 26; other platforms use an ordinary view. React owns content layout. This extends background content; it is not another glass material.
- Existing `GlassScrollEdge` already wraps `UIScrollEdgeElementContainerInteraction`; no duplicate wrapper is needed.
- UIKit bar items support native badges; UIButton does not. Icon and group badges stay outside the clipped material and follow native presentation scale from highlight onset; title badges anchor to the button center so title relayout cannot displace them during a press. An iOS hold recording confirms visible scaling; exact tracking tolerance remains unmeasured. No private class lookup or replacement button animation is used.
- SwiftUI's `glassEffectUnion` and `glassEffectID` are not UIKit APIs. Arbitrary React children cannot receive those modifiers directly. The package's commit pairing is a separate implementation and needs its own acceptance evidence.

## Acceptance status

Implementation is not visual acceptance. Track current runs in `.agent/development.md` in the working copy. Verified locally: iOS 26.5 builds, new-control interactions, header state changes, badge hold recording, AXXXL light/increased-contrast interaction, and existing icon/menu/tab tests. Optimized G1 after-images are pixel-identical to the original implementation; both have six before/after rim channels at 3/255, so the literal ±2 criterion remains open. Android builds and the new group/menu/pill/morph/presence interaction test pass, along with menu, tab navigation, context-menu and existing feature regressions. The tab test needed a launcher-scrolling helper correction before passing. Remaining acceptance includes G1 profiling, G2 ink/transition frames, G3/G4 reference geometry, G5/G6 uninterrupted glass and interrupted-exit recordings, G7 real stack push/pop/cancel, G9 scroll minimization, and exact badge tracking tolerance. Older-iOS device testing remains deferred.

G10: the referenced 0.1.7 request file contains menu R1/R2/R2b, not R3–R5. Android long-press cancellation and tab background tint are addressed from source analysis. The exact consumer tab-badge patch is absent and has not been claimed as upstreamed.

## Official sources checked October 16, 2026

- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views): containers, identities, unions and materialize transitions in SwiftUI.
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass): native components, adaptive appearance and restrained effect use.
- [UIButton configurations](https://developer.apple.com/documentation/uikit/uibutton/configuration-swift.struct): glass and clear variants. Installed UIKit headers confirm availability.
- [Symbol content transition](https://developer.apple.com/documentation/uikit/uibuttonconfiguration/symbolcontenttransition): opt-in transition, defaults to nil. Installed SDK declares iOS 26.
- [Tab minimization](https://developer.apple.com/documentation/uikit/uitabbarcontroller/minimizebehavior) and [bottom accessory](https://developer.apple.com/documentation/uikit/uitabbarcontroller/bottomaccessory).
- [Bar button badges](https://developer.apple.com/documentation/uikit/uibarbuttonitem/badge-swift.struct).
- [Navigation willShow delegate](https://developer.apple.com/documentation/uikit/uinavigationcontrollerdelegate/navigationcontroller(_:willshow:animated:)): delegate ownership is significant; no documented guarantee of React commit ordering.
- [Background extension](https://developer.apple.com/documentation/uikit/uibackgroundextensionview).

### Badge drag research (October 17, 2026)

Apple demonstrates native glass interactivity and adding custom content in [Build a UIKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/284/). Its [badge API](https://developer.apple.com/documentation/uikit/uibarbuttonitem/badge-swift.struct) belongs to UIBarButtonItem. The installed UIKit SDK exposes `UIBackgroundConfiguration.customView` for a background attachment; [CALayer.presentation()](https://developer.apple.com/documentation/quartzcore/calayer/presentation()) provides in-flight geometry. Our recordings showed that following the image/title alone misses background deformation, and that ending tracking when highlight leaves the original bounds stops it too early. The implementation now follows the owned background attachment throughout the touch sequence.
