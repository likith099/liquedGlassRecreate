# 0.2.0 API, behaviour and acceptance

Everything from 0.1.x keeps working. New native components require `pod install` and a native rebuild. No Expo Modules, Reanimated, or new runtime dependencies are needed.

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

Groups use one interactive UIKit glass capsule and individually addressable native buttons. Pills use separate UIKit glass buttons without a shared glass container, isolating their highlights; they remain controlled, scroll on overflow, and distinguish selection from trailing actions. Each pill is sized from its regular-weight label; the selected (semibold) pill takes the extra width out of its padding and stays on one line, so selection never shifts the row or badge resting positions (iOS and Android). Android uses solid surfaces, ripples and platform menus. Each item accepts a stable `id`, label and `testID`. Use resource names for group/pill Android icons; React icon elements inside those native rows are not yet supported.

Controls are measured natively: a C++ shadow node asks UIKit (iOS) or the Android view manager for the size during React Native layout, so the first frame is right and a resize never waits for JavaScript.

On iOS 26, `GlassMorphButton` and `GlassHeaderHost` slots are drawn by SwiftUI the way system apps such as Contacts draw them: each content has its own glass shape (`glassEffectID`) inside one `GlassEffectContainer`, so on a change the outgoing glass flows into the incoming one like liquid (`glassEffectTransition(.matchedGeometry)`; neighbouring slots that merge or split on a screen change join through a liquid neck) while the old content blurs out and the new content focuses in. The timing matches Contacts: old content out in ≈150 ms, glass reshape, new content in over ≈250 ms, ≈0.5 s in all; the trailing edge stays fixed for `anchor="trailing"`. Under Reduce Motion the glass takes its final size at once and the content cross-fades in 0.2 s. Older iOS, Reduce Transparency and `forceFallback` keep the UIKit/fallback buttons, whose width animates. `GlassPresence` retains children until native exit completion and reports `onExited` once, including when the parent unmounts mid-exit; a re-entry cancels the exit; Reduce Motion cross-fades. Direct children with the same `glassID` can pair across a commit inside an iOS `GlassContainer`; arbitrary nested descendants and Android matched identity are not implemented.

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

Pass `routeKey: route.key`: react-native-screens publishes the same key as each native screen's `screenId`, which is how the iOS host knows which screen a transition is bringing in. Every registered screen's items are sent to native at once, so the host runs the slot diff inside the stack's own transition coordinator. Controls pair as the system bar pairs its items: a control both screens show with the same side and content (a back button on both, a shared Share button) keeps its glass and stays still, whatever its position or slot name; a named `slot` both screens use keeps its glass and morphs its content (Select → ⋯); the remaining controls on each side pair by position and morph (Edit → +); a control only the incoming screen has appears at full size, and one only the outgoing screen has shrinks to its centre (≈70 ms). Within one screen a control keeps the glass it was paired with, so a later content change still morphs. An interactive swipe back is followed through the stack's pop gesture recognizers. On iOS 26 the outgoing screen keeps its controls while the finger is down; when it lifts and the pop is going to complete they morph to the incoming screen's while the screen slides away, and a cancelled swipe changes nothing (a SwiftUI morph cannot be scrubbed). Before iOS 26 UIKit scrubs the width animation with the finger and reverses it on cancel. JavaScript does nothing per frame, and a 500 ms JavaScript stall during the push does not affect it. After a programmatic push or pop the host watches natively (at most 1.5 s) for react-native-screens to begin the transition, since it can start a few frames after the commit. The host never replaces the navigator's delegate and has no router dependency. Keep slot names stable and memoize item arrays; `slot` is optional for controls that look the same on both screens. A screen that registers no items shows no header controls. Android has no transition coordinator: it morphs the same slots with native animators when the focused screen changes. Every header control posts VoiceOver focus to the incoming screen's first control after the transition; verify focus order on a device. Trailing items are placed from the trailing edge, the first one outermost (as UIKit's `rightBarButtonItems`), 12 pt apart; leading items 10 pt apart.

Alternatively, on iOS 26 with a React Navigation native stack (react-native-screens 4.2x), pass the screen's `navigation` to `useGlassHeader`: the items then become UIKit bar button items in the stack's own navigation bar (`glassHeaderOptions` builds those screen options; `kind: 'back'` becomes UIKit's back button). UIKit morphs their glass between screens and scrubs it with the swipe, but swaps the content without the blur. Elsewhere the host's overlay is used.

On iOS 26 each slot is a SwiftUI button with interactive glass on its measured frame; a slot with a menu is a SwiftUI menu built from the same items, and its badge draws above the glass container at the capsule's top-trailing 45° point, riding the reshape. Before iOS 26, morph buttons and header slots use independent UIKit buttons. A retained slot reuses its material configuration when its content changes. New titles are laid out on one line before the width animation, and content layout completes with the resize. Native control and React Native wrapper width changes share a 0.25-second critically damped animation so the lens finishes resizing before the native release-lighting tail; Reduce Motion applies the final geometry immediately. Native press lighting remains enabled. Use the fields for the chosen content kind: `{kind: 'title', title: 'Done', ...}` or `{kind: 'symbol', symbol: 'ellipsis', ...}`; the demo switches between these rather than showing both together. On Android, a slot whose content changes keeps one capsule and animates its width from the edge it is anchored to while the icon and title cross-fade (Material emphasized easing, 300 ms; `GlassMorphButton` 420 ms); a slot that appears fades in at full size and one that leaves shrinks to its centre and fades. `kind: 'back'` uses the package's Material back arrow on Android.

## Tabs and additional Apple APIs

`GlassTabBar` adds `minimizeBehavior` (`never`, the unchanged default; `automatic`, `onScrollDown`, `onScrollUp`) and a `scrollViewRef` on each item. On iOS 26 the destination controller associates that React scroll view with its bottom edge. `bottomAccessory` supplies React content to `UITabAccessory`; use `bottomAccessoryHeight` (default 44) and reserve sufficient host height. Older iOS and Android place an ordinary bar above the tabs. Their tab bars do not minimize.

Additional gaps found in the Apple review:

- `GlassIconButton material="clear"` selects `clearGlass()` / `prominentClearGlass()` on iOS 26. Regular remains the default.
- `GlassBackgroundExtension` wraps `UIBackgroundExtensionView` on iOS 26; other platforms use an ordinary view. React owns content layout. This extends background content; it is not another glass material.
- Existing `GlassScrollEdge` already wraps `UIScrollEdgeElementContainerInteraction`; no duplicate wrapper is needed.
- UIKit bar items support native badges; UIButton does not. Icon and group badges stay outside the clipped material and follow native presentation scale from highlight onset; title badges anchor to the button center so title relayout cannot displace them during a press. An iOS hold recording confirms visible scaling; exact tracking tolerance remains unmeasured. No private class lookup or replacement button animation is used.
- SwiftUI's `glassEffectUnion` and `glassEffectID` are not UIKit APIs. `GlassMorphButton` and header slots use `glassEffectID` through SwiftUI; arbitrary React children cannot receive those modifiers, and `GlassContainer`'s `glassID` commit pairing is a separate UIKit implementation.

## Acceptance status

Measured on the iPhone 17 Pro Max simulator (iOS 26.5, 3×, dark) with the example app's
**0.2.0 acceptance** screen (`example/AcceptanceDemo.tsx`), XCUITest frames, and 60 fps screen
recordings analysed frame by frame (`scripts/record-ios-ui-test.sh`, `scripts/trace-glass.py`,
`scripts/acceptance-images.py`, `scripts/profile-reattach.sh`). Older-iOS fallbacks were run on
the iOS 18.6 simulator and Android on the Pixel emulator; see the release record for device runs.

| Item | Criterion | Result |
| --- | --- | --- |
| G1 cost | Pop over 20+ surfaces well under ~24 ms | ≈1 ms total in `ALGSurfaceView` across 10 re-attaches of 20 surfaces (no `setEffect` samples) |
| G1 pixels | ±2 per channel after the pop | Simulator: noise floor 0; 6 channels differ by 3/255 on two surfaces' rims (UIKit regenerates the rim highlight). iPhone 13 Pro (iOS 26.7.1): re-attached glass is settled (0 change a second later) but each fresh effect lands within 17/255 of its earlier look on 20–40 % of glass pixels. Keeping the old effect instead keeps drifting (16/255 within a second), so a fresh effect stays. **Not met as written**; no public API restores UIKit's earlier glass state |
| G2 | Back chevron like UIKit's; replace never empty | UIKit back indicator measured 11.0 × 18.7 pt, 63.3 pt²; `{pointSize: 17, weight: 'semibold', scale: 'large'}` reproduces it (now `kind: 'back'`). The request's 55.1 pt² came from the app's own tool; this tool reads the app's 0.1.7 sample within 2 %. Replace: minimum 79 % ink in every frame |
| G3 | Calendar / Wallet within ±1 pt | 162.0 / 162.7 pt and 102.3 / 101.7 pt; items separately hittable, menus per item, VoiceOver per item |
| G4 | Fitness+ pills within ±1 pt | For You 87.7, Explore 86.7, Plans 71.3, Library 83.0 (87 / 87 / 71 / 84); search 49 × 42; gap 10; inset 20; "1 of 4"; selection switches in one frame |
| G5 | ≤ 0.6 s, trailing edge fixed, glass every frame, ≤ ±5 % overshoot; same with JS blocked 500 ms; Reduce Motion 0.2 s cross-fade | iOS 26 SwiftUI morph: ≈0.58 s, trailing drift ≤ 0.3 pt, no overshoot, glass in every frame (the outgoing glass flows into the incoming shape); identical with a 500 ms stall; Reduce Motion: final size in one frame, ≈0.2 s cross-fade. Before iOS 26 (UIKit path): ≈0.2 s, drift 0 |
| G6 | Glass every frame; exit ≤ 0.2 s; `onExited` once, incl. unmount mid-exit | Exit ≈40 ms, enter from the first frame; `onExited` once in both cases |
| G7 | Push/pop trace; back appears in one frame, leaves ≤ 0.1 s; swipe scrubs and cancels; JS stall | iOS 26: shared slots blur-morph, neighbouring glass merges and splits through a liquid neck, glass in every frame; identical with a 500 ms stall; swipe back keeps the outgoing controls while the finger is down and morphs on release when the pop completes; a cancelled swipe changes nothing; header menu and badge work; slot order matches UIKit. Not scrubbed (a SwiftUI morph cannot be). Before iOS 26: back appears at full size, leaves in ≈70 ms, swipe scrubs and restores on cancel. VoiceOver focus posts to the first header control (device check) |
| G8 | Each `controlSize` ±0.5 pt | All exact |
| G9 | Default unchanged; `onScrollDown` minimizes | Minimizes; re-expands when tapped (scrolling up does not re-expand while the list lives outside the native tab controller) |
| G11 | Badge centre on the circle's top-right edge ±1 pt, every frame of a hold | Max 0.75 pt over 128 frames, including the release dip |

JavaScript stalls are measured starting in the next JS task: React Native mounts UI changes at
the end of the JavaScript task that made them, so work in that same task delays any library.

G10: the referenced 0.1.7 request file contains menu R1/R2/R2b, not R3–R5. Android long-press
cancellation and tab background tint are addressed; the consumer's tab-badge patch is
superseded by the unified badge API.

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
