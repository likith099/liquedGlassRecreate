# Glass surfaces

`GlassView`, `GlassContainer`, `GlassPressable`, `GlassBadge`, `GlassToastProvider` and `GlassScrollEdge` put React content on a native material. The material depends on the platform tier: glass on iOS 26, system blur on iOS 15–25, and an opaque surface on Android (except opt-in scroll-header blur on API 31+), under Reduce Transparency, and with `forceFallback`. `useGlassTier()` reports the tier, and it follows Reduce Transparency as it changes.

| Tier | iOS 26 | iOS 15–25 | Android, Reduce Transparency, `forceFallback` |
| --- | --- | --- | --- |
| Material | `UIGlassEffect` | `UIBlurEffect` system material | Opaque surface (themeable) |
| `useGlassTier()` | `'glass'` | `'blur'` | `'solid'` |

## GlassView

```tsx
<GlassView material="regular" cornerRadius={24} tintColor="#7770D840" style={{padding: 16}}>
  <Text>Content</Text>
</GlassView>
```

| Prop | Default | Behaviour |
| --- | --- | --- |
| `material` | `'regular'` | `'regular'`, `'clear'` (ultra-thin blur below 26) or `'none'` (transparent). |
| `interactive` | `false` | Native touch highlight and deformation (iOS 26). Does not make the view a button; use `GlassPressable`. |
| `tintColor` | none | Glass tint; below 26 a translucent overlay on the blur. |
| `cornerRadius` | `24` | The native shape. `style.borderRadius` is not applied to the material. |
| `colorScheme` | `'system'` | Pins light or dark material, for example over photos. |
| `animationDuration` | `0.35` | Seconds for material transitions; `0` disables them. Reduce Motion always does. |
| `fallbackMaterial` | `'blur'` | `'solid'` uses the opaque surface below iOS 26, which is cheaper in long lists. |
| `fallbackStyle` | none | Style applied only on the opaque and older-iOS tiers. |
| `forceFallback` | `false` | Opaque surface on every platform, for previews. |
| `ref` | | `GlassHostRef`, the native host view. |

## GlassContainer

Groups `GlassView`s. Set `mergingEnabled` and `spacing` to let nearby surfaces join on iOS 26. Merging is off by default. Passing `spacing` alone logs a development warning, because nothing merges. Below iOS 26 and on Android it is an ordinary view.

## GlassPressable

A `Pressable` on a `GlassView`, for custom React content that acts as a button. It accepts the `Pressable` props, plus `material`, `tintColor`, `cornerRadius`, `colorScheme`, `fallbackMaterial`, `fallbackStyle`, `forceFallback` and `contentStyle`. `interactive` defaults to true; set it false for large cards and rows that should not deform under the finger. Disabled pressables are never interactive. Android adds a ripple.

## GlassBadge

A one-line label on material that reads the same over bright and dark imagery.

```tsx
<GlassBadge tintColor="#F57C0080" tintGlass solidColor="#F57C00">New</GlassBadge>
```

`tintColor` tints the older-iOS blur; `tintGlass` also tints the iOS 26 glass. `solidColor` fills the badge on the solid tier. `colorScheme`, `textColor`, `textStyle` and `cornerRadius` (default 12) adjust it, and non-text children render as given.

## GlassToastProvider

```tsx
<GlassToastProvider bottomOffset={100}>
  <App />
</GlassToastProvider>

const toast = useGlassToast();
toast.show('Copied', {duration: 2000});
```

A short confirmation on a badge-style surface. A new toast replaces the one on screen, and each is
announced to screen readers. It slides and scales in (instantly under Reduce Motion) rather than
fading, because glass does not render inside a fading view. `colorScheme` defaults to dark.

## GlassScrollEdge

```tsx
const list = useRef<ScrollView>(null);

<ScrollView ref={list}>{rows}</ScrollView>
<GlassScrollEdge scrollViewRef={list} edge="bottom" effectStyle="soft" style={styles.floatingBar}>
  {bar}
</GlassScrollEdge>
```

A container for a bar floating over a scroll view's edge, so content fades under the bar instead of
colliding with it. iOS 26 applies UIKit's scroll-edge effect to the referenced scroll view
(`effectStyle`: `automatic`, `soft` or `hard`). Older iOS and Android default to a gradient scrim from
`fallbackColor` to clear under the container. `effectStyle="progressive"` defines a full header region for the native iOS 26 soft edge; `fallbackMode` selects gradient, blur or solid on Android. See `GlassScrollHeader` below.

## Theming the opaque tier

```tsx
<GlassFallbackThemeProvider value={{surface: {light: '#FFFFFF', dark: '#101820'}, foreground: {light: '#111', dark: '#EEE'}}}>
  <App />
</GlassFallbackThemeProvider>
```

The provider sets the surface and text colours for opaque surfaces, fallback buttons, segmented controls, the context-menu fallback, badges, toasts and the Android search field. Colours you do not set keep the defaults.

## Guidance

Keep glass for controls and small labels over content. Large glass panes behind forms or long text reduce legibility, so keep sheets, modals and form panels opaque. Do not animate the opacity of a glass surface or any of its ancestors: a visual effect view does not render while an ancestor's alpha is below 1. Animate position or scale instead, as `GlassToastProvider` does.

## GlassScrollHeader

For native collapsing titles, bar actions, and integrated search, use [GlassNavigationView](navigation.md). For the effect alone with either edge and no prescribed layout, use [GlassProgressiveBlur](navigation.md#independent-progressive-blur).

A pinned header using UIKit’s **native soft scroll-edge effect on iOS 26+**, the system treatment for content passing beneath floating controls. UIKit owns the progressive blur, contrast and scroll response; the header's text/buttons stay sharp. There is no overlaid uniform blur or custom gradient in this path.

React Native text is not a native UILabel. The Fabric host supplies an invisible native image element spanning the header bounds so `UIScrollEdgeElementContainerInteraction` recognizes the full header region. This follows Apple’s public native-element contract without private APIs or a reference-library dependency. Header layout, typography and large-title collapse remain the app’s responsibility; this component provides the scrolling backdrop treatment.

```tsx
const list = useRef<FlatList<Contact>>(null);
return <View style={{flex: 1}}>
  <FlatList ref={list} data={contacts} renderItem={renderContact}
    contentContainerStyle={{paddingTop: 100}} />
  <GlassScrollHeader scrollViewRef={list} fallback="blur" fallbackColor="#12141A"
    style={{position: 'absolute', top: 0, left: 0, right: 0, height: 100, padding: 20}}>
    <Text style={{color: 'white', fontSize: 28}}>Contacts</Text>
  </GlassScrollHeader>
</View>;
```

- Put the header **beside and above** its `ScrollView`/`FlatList`, overlapping the same viewport. Reserve its initial height with content padding; include your safe-area inset in the header height/padding when it extends under the status bar. Keep the linked ref stable, and leave the header background transparent on iOS 26 so it does not cover the system effect.
- `fallback="solid"` (default) gives Android and iOS below 26 an opaque fill. `fallback="blur"` gives older iOS a uniform system material and Android 12/API 31+ a uniform 20 dp blur of the linked scrolling content, with a light tint from `fallbackColor`. Android uses public `RenderNode`/`RenderEffect` APIs; it does not blur the header's children or require a blur library. Android below API 31, software rendering, or a missing source uses the solid fill.
- `fallbackColor` defaults to a light/dark system-like background. It controls fallback rendering; UIKit owns the iOS 26 edge’s blur strength, extent and contrast. There is no independent progressive-radius or brightness knob.
- Reduce Transparency uses an opaque fill on iOS. Unsupported platforms use a solid fallback. Android capture is for ordinary React Native scrolling views; separate video/`SurfaceView` content is not supported.
- The underlying `GlassScrollEdge` also accepts `fallbackMode="gradient" | "blur" | "solid"`. Its existing defaults (`edge="bottom"`, `effectStyle="automatic"`, gradient fallback) remain unchanged. For the same native full-region edge at the bottom, use `edge="bottom" effectStyle="progressive"`. The existing `soft`/`hard`/`automatic` options retain UIKit scroll-edge ownership on iOS 26+.

Demo: **Navigation & headers → Standalone blur**. Includes scrolling, header actions, Android fallback switching and remounting.

References: [Apple scroll-edge containers](https://developer.apple.com/documentation/uikit/uiscrolledgeelementcontainerinteraction), [Apple soft/hard edge styles](https://developer.apple.com/documentation/swiftui/scrolledgeeffectstyle), [React Native integration reference](https://github.com/bluesky-social/expo-scroll-edge-effect/blob/main/ios/ExpoScrollEdgeEffectView.swift), [Android RenderEffect](https://developer.android.com/reference/android/graphics/RenderEffect).
