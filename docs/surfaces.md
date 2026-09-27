# Glass surfaces

`GlassView`, `GlassContainer`, `GlassPressable` and `GlassBadge` put React content on a native material. The material depends on the platform tier: glass on iOS 26, system blur on iOS 15–25, and an opaque surface on Android, under Reduce Transparency, and with `forceFallback`. `useGlassTier()` reports the tier, and it follows Reduce Transparency as it changes.

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

## Theming the opaque tier

```tsx
<GlassFallbackThemeProvider value={{surface: {light: '#FFFFFF', dark: '#101820'}, foreground: {light: '#111', dark: '#EEE'}}}>
  <App />
</GlassFallbackThemeProvider>
```

The provider sets the surface and text colours for opaque surfaces, fallback buttons, segmented controls, the context-menu fallback, badges, toasts and the Android search field. Colours you do not set keep the defaults.

## Guidance

Keep glass for controls and small labels over content. Large glass panes behind forms or long text reduce legibility, so keep sheets, modals and form panels opaque. Do not animate the opacity of a glass surface or any of its ancestors: a visual effect view does not render while an ancestor's alpha is below 1. Animate position or scale instead, as `GlassToastProvider` does.
