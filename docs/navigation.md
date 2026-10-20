# Navigation headers and independent scroll blur

`GlassNavigationView` owns a single-screen UIKit navigation controller on iOS and a Material toolbar on Android. The package owns the header; your navigator owns routes and back gestures. Native title transitions remain the default. Set `titleTransition="morph"` for the opt-in, finger-tracked iOS title described below.

## A scrolling screen

```tsx
const list = useRef<FlatList<Contact>>(null);
const header = useRef<GlassNavigationHandle>(null);
const [query, setQuery] = useState('');

<GlassNavigationView ref={header} title="Contacts" scrollViewRef={list}
  titleDisplayMode="large" titlePosition="leading"
  edgeEffect={{top: 'hard'}}
  onBack={() => navigation.goBack()}
  trailingItems={[
    {id: 'search', systemItem: 'search', accessibilityLabel: 'Search'},
    {id: 'more', symbol: 'ellipsis', androidIcon: 'app_more', accessibilityLabel: 'More',
      badge: {count: 5}, menu: {items: menuItems, onAction: handleMenu}},
  ]}
  search={{value: query, onChangeText: setQuery, placeholder: 'Find contacts'}}
>
  <FlatList ref={list} style={{flex: 1}} nestedScrollEnabled
    contentInsetAdjustmentBehavior="automatic"
    data={filteredContacts} renderItem={renderContact} />
</GlassNavigationView>
```

Give the parent a bounded height, usually `flex: 1`. On iOS, **use `contentInsetAdjustmentBehavior="automatic"`** and let UIKit calculate bar/search/toolbar overlap. Avoid additional header padding or a top SafeAreaView. Your `onScroll` remains available; no JS scroll listener drives the header. An empty `title` is supported.

Android uses a fixed Material toolbar by default. `androidCollapsing` enables `AppBarLayout` / `CollapsingToolbarLayout`; enable `nestedScrollEnabled` on the list. It uses native Material title interpolation and lift-on-scroll, rather than the iOS renderer. System and cutout insets are automatic; numeric `topInset` / `bottomInset` override them. The `app_more` drawable in this example belongs to the consuming app. SF Symbol names are iOS-only.

## Title layout and motion

| Property | Behaviour |
| --- | --- |
| `titleDisplayMode` | `large` (default) expands below the bar; `inlineLarge` starts in the bar row (iOS 17+); `inline` stays compact. Android collapse requires `androidCollapsing`. |
| `titlePosition` | `automatic` uses UIKit's layout rule: on iOS 26 a title can be centered or leading depending on available space. `leading` uses the public browser item style on iOS 26. Earlier iOS retains its native centered compact title; use `morph` for leading alignment there. Android titles are leading. |
| `titleFont` | `{compactSize, largeSize, weight}`. Defaults 17/34 points. Sizes are bounded to 10–64 and scale with Dynamic Type; iOS compact text is capped at 1.16×. `weight`: regular/medium/semibold/bold. |
| `titleTransition` | `native` (default) retains UIKit's timed title transition. `morph` uses the single-label native renderer, implies leading alignment and snaps to either end on release. |
| `titleWeight` | Morph only: `bold` (default) or `semibold` for the entire motion. |
| `largeTitle` | Alternate expanded title on iOS 26. The morph uses this text throughout; it does not cross-fade between different strings. |
| `subtitle`, `largeSubtitle` | Native compact/expanded subtitles on iOS 26. Android renders `subtitle`; older iOS omits these. |

UIKit reverts native `inlineLarge` to a large title below the bar when a back button is present, and it can move leading items into overflow. With leading items or `onBack` the package therefore falls back to `large` and warns in development. The morph keeps those actions visible and does not need this fallback. There is no forced-center option.

The morph draws **one opaque label**, with a font and line layout that remain constant while scrolling. Only uniform scale and fractional position change. UIKit measures the available title slot; a transparent native label preserves the scroll-edge effect. Long text scales to fit, or keeps a consistent ellipsis if even its compact size cannot fit. Landscape stays compact. Reduce Motion switches immediately between endpoints, without a dissolve. Scaling the large SF raster has slightly different letterforms than UIKit's separately typeset compact title; the chosen weight remains constant.

## Custom content and pinned accessories

```tsx
<GlassNavigationView title="Maya" titleDisplayMode="inline" scrollViewRef={list}
  titleView={<ContactTitle style={{height: 40}} />}
  subtitleView={<Presence style={{height: 20}} />}
  largeSubtitleView={<LocationPicker style={{height: 32}} />}
  accessory={<Filters style={{height: 44}} />}
  onBarInsetsChange={({top, bottom}) => setBarInsets({top, bottom})}
>
  {/* Screen content */}
</GlassNavigationView>
```

Slots accept React content. Give it an intrinsic or explicit **height**; the package measures that height and supplies the native slot's available width. Keep content flexible horizontally and truncate long text. Custom `titleView` takes precedence over `titleTransition="morph"`. On iOS 26, subtitle slots use `UINavigationItem.subtitleView` / `largeSubtitleView`; older iOS omits them. Android hosts slots in its toolbar/header layout.

`accessory` stays under the collapsing title/bar, contributes to safe-area layout and shares one continuous native edge region with the entire header on iOS 26. The soft fade ends below the filter rather than restarting between the bar and filter. iOS 26 places an expanded native large title inside the scroll view, beneath the edge effect, so the extended region is only installed once that title has collapsed; until then content stays below the header and UIKit’s own bar edge applies. Native titles and subtitles therefore stay sharp in soft and hard modes. The morph label is drawn above the header and keeps the continuous region throughout. On iOS during search, the accessory stays below the search bar and scopes; the morph title releases its reserved row until search closes. Use it for filters or segmented controls. `onBarInsetsChange` reports settled `{top, bottom}` in points, not per-frame scroll progress. Normal scrolling content should continue using automatic iOS insets; use the callback for fixed content or manually inset layouts. Android already lays content below its toolbar, so do not add those insets again to its body.

For an **inverted list**, use the manual recipe: an unbound ref (`useRef(null)`), `titleDisplayMode="inline"`, `edgeEffect="hidden"`, `contentInsetAdjustmentBehavior="never"`, and a containing View padded with the reported insets on iOS. This avoids applying UIKit's top-edge ownership to a transformed list. Automatic hard-edge rendering over inverted lists is not promised; the demo includes this manual chat configuration.

## Actions, search and commands

Actions use unique nonempty IDs across leading/trailing/bottom placements and require an accessibility label. Duplicate/blank IDs throw in development; production drops invalid entries with a warning. Localize your labels.

- `leadingItems`, `trailingItems`, `toolbarItems`: SF Symbols, app drawables, text, images, nested menus, disabled/selected/prominent states, count/text/dot badges and badge colours. iOS retains bar-item identity across badge changes. Native Android menus provide overflow.
- `systemItem`: close/done/cancel/edit/add/save/search. UIKit supplies its localized standard item; provide a localized accessibility label. Android uses standard icons or your action label.
- `imageRendering`: template (default) or original; `imageShape`: none or circle. Artwork is fitted to the bar icon size.
- `mergingEnabled`: adjacent iOS 26 items share glass only when true; default false. Android uses Material actions. `hidesSharedBackground` is iOS 26 only.
- `toolbarItems` also accepts `{id, spacer: 'fixed', width}` and `{id, spacer: 'flexible'}`. With no explicit spacers, actions are distributed across the bar. Avoid a bottom toolbar when a navigator's tab bar already owns that area.
- An item with `menu` opens that menu on tap on both platforms and reports choices through `menu.onAction`; only items without a menu call the view's `onAction(id)`.
- Menu action `subtitle`, `keepsMenuPresented` (iOS 16+) and group `singleSelection` use public UIKit menu options. Android retains standard popup-menu behaviour; secondary subtitles and keep-open are iOS features.
- `onBack` is an application callback. iOS VoiceOver escape invokes it. `handlesSystemBack` opts Android into handling system Back, with active search dismissed first; default false. The containing navigator remains responsible for route and predictive-back transitions.
- `titleTestID`, `backTestID`, `search.testID` avoid duplicate identifiers in mounted tab screens. In native-title mode the title identifier marks the navigation bar; in morph mode it marks the accessible title slot.

`search` supports controlled `value` / `onChangeText`, optional `active` / `onActiveChange`, `onSubmit`, `onCancel`, `onFocusChange`, `placeholder`, `autoCapitalize`, and `returnKeyType`. Omitting the iOS placeholder preserves the system default. Android uses Material `SearchBar` / `SearchView`, including its clear button; `cancelLabel` labels its close action. Temporary native screen detachment preserves the search session.

On iOS, `active: true` opens UIKit's search and focuses its field (Android `SearchView.show()` does the same); it waits until the view is in a window, so it can be set together with first rendering `search`. Adding or removing `search` while it is visible animates the header to its new height and keeps a list that was at the top at the top. Removing it while active lets UIKit finish the dismissal first. A stacked search bar sits below a native large title; the morph title row sits below a visible search bar.

On iOS 26, choose `placement`: stacked (default), integrated, integratedButton, or integratedCentered. `allowsToolbarIntegration` defaults false; older iOS uses stacked. `hidesWhenScrolling` defaults true on iOS. Search scopes use `{items: [{id, title}], value, onChange}`; filtering remains app-owned. Native edit counts protect newer typing from stale controlled values. Android keyboard settings update only when changed, preserving the active input connection while typing.

The ref supplies `scrollToTop(animated = true)`, `focusSearch()` and `dismissSearch()`. Native iOS scroll-to-top retargets after the title inset settles. Ref adapters use `getNativeScrollRef`, `getScrollResponder`, `scrollToOffset` and `scrollTo`; SectionList's public responder is supported. FlashList and Animated.FlatList use their public ref adapters; library-specific version compatibility still needs consumer verification.

`colorScheme`, `tintColor` and `contentBackgroundColor` control appearance. The two colour props accept static colours or `{light, dark}` pairs. They do not replace the native material or touch response.

## With a navigator

Install navigators in the **app**, not as package dependencies. For React Navigation native-stack, set `headerShown: false` on screens using this component. Pass `onBack={() => navigation.goBack()}` (or your discard-confirmation handler). The outer stack owns gestures; the inner single-screen controller does not install a competing pop gesture. Each screen's header travels with that screen during navigation. Configure the outer navigator's `statusBarStyle` to match your app theme because it owns the status bar.

For tab reselection:

```tsx
const header = useRef<GlassNavigationHandle>(null);
useScrollToTop(header); // @react-navigation/native
return <GlassNavigationView ref={header} /* ... */ />;
```

Using a raw list ref here can scroll to offset zero rather than the native adjusted top. Do not show both an outer native header and this header. If your navigator's header already provides what you need, keep it and use the independent blur component for overlays. Native tab-bar minimization and full-screen back gestures remain navigator-specific integration checks.

The demo's **Review** screen runs inside a native stack with the package's native tab-bar adapter. It includes push/pop while searching, custom title/subtitle/accessory controls, title presets, and an inverted chat screen.

## Pull-to-refresh and hero content

Attach a normal `RefreshControl` to the list and keep automatic iOS insets. The package preserves the app's content inset and adds/removes only its own morph title row. Do not add a second title-height `progressViewOffset`; the demo exercises refresh in both the normal and morph paths. Use Android's platform offset options only when your own overlay requires them.

For a hero image under custom controls, use `GlassProgressiveBlur` and one application-owned text layer. If you animate that text in RN, animate scale/translation with a native driver and a fixed weight. Animating `fontSize` or `fontWeight` re-lays out glyphs or changes weight discretely. An empty navigation `title` is also valid, but automatic reveal of a separate hero title is app-owned.

## Independent progressive blur and the Phone-style edge

```tsx
<View style={{flex: 1}}>
  <FlatList ref={list} data={items} renderItem={renderItem}
    contentContainerStyle={{paddingTop: 88}} />
  <GlassProgressiveBlur scrollViewRef={list} edge="top" effect="hard" fallback="blur"
    style={{position: 'absolute', top: 0, left: 0, right: 0, height: 88}}>
    {/* Optional custom controls */}
  </GlassProgressiveBlur>
</View>
```

`edge`: top (default) or bottom. `effect`: soft (default) or hard. Developers own overlay dimensions and content padding. With soft edges, extend the region roughly 16–24 points below the last text line so it doesn't sit over the weakest part of the fade.

Both effects use UIKit's actual scroll edge on iOS 26 with a transparent native image defining the full region. **Hard** requests the native cutoff style. `GlassNavigationView` also draws a one-physical-pixel system separator at the bottom of the complete header (including a pinned accessory), and suppresses the navigation bar's own shadow to avoid a line through the filter. Soft and hidden modes omit that separator. This explicit boundary follows the owner's subsequent review; the standalone blur retains UIKit's own rendering. Physical-device material appearance still requires separate verification.

Navigation `edgeEffect="hard"` controls the top, and the bottom only when this component shows a toolbar. `{top, bottom}` explicitly controls either edge; `hidden` disables the selected effect. Other bottom-edge owners are otherwise preserved.

Older iOS: `fallback="blur"` uses uniform material; `solid` (default) uses opaque fill. Android blur captures linked scrolling content on API 31+; older/software/missing-source cases use solid. `fallbackColor` controls fallback fill/tint; Reduce Transparency uses solid on iOS. Video/SurfaceView capture is unsupported on Android. `GlassScrollHeader` is now a deprecated, compatible top/soft alias; existing code continues to work.

## Native API references and limits

- [UIKit navigation items](https://developer.apple.com/documentation/uikit/uinavigationitem) and [search placement](https://developer.apple.com/documentation/uikit/uinavigationitem/searchbarplacement-swift.enum).
- [Native search presentation](https://developer.apple.com/documentation/uikit/uisearchcontroller) and [transition coordination](https://developer.apple.com/documentation/uikit/uiviewcontrollertransitioncoordinator).
- [Content scroll view ownership](https://developer.apple.com/documentation/uikit/uiviewcontroller/setcontentscrollview(_:for:)) and [scroll-edge interaction](https://developer.apple.com/documentation/uikit/uiscrolledgeelementcontainerinteraction).
- [Material collapsing toolbar](https://developer.android.com/reference/com/google/android/material/appbar/CollapsingToolbarLayout) and [Material search](https://github.com/material-components/material-components-android/blob/1.13.0/docs/components/Search.md).

Navigation history, document-title rename menus, customizable iPad toolbar groups and application editing/filter logic remain app/navigator responsibilities. Device hard-edge rendering, physical scrolling performance and every supported OS/navigation-library combination require separate acceptance; implementation and public API availability are not test evidence.
