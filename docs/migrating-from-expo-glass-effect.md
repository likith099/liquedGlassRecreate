# Migrating from expo-glass-effect

`expo-glass-effect`'s `GlassView` and `GlassContainer` map directly onto this package's components. The main behavioural difference is that merging is opt-in here. This package also draws system blur on iOS 15–25 and an opaque surface on Android, where Expo's components render an ordinary view.

This is a native module, so it does not run in **Expo Go**. Use a [development build](https://docs.expo.dev/develop/development-builds/introduction/) with the New Architecture. Expo development builds should pick it up through React Native autolinking, but that path is not yet covered by this repository's tests.

## GlassView

| expo-glass-effect | This package | Notes |
| --- | --- | --- |
| `glassEffectStyle="regular" \| "clear" \| "none"` | `material="regular" \| "clear" \| "none"` | Same three materials. |
| `glassEffectStyle={{style, animate, animationDuration}}` | `material` + `animationDuration` (seconds) | `animationDuration={0}` disables the transition; Reduce Motion always does. |
| `isInteractive` (default `false`) | `interactive` (default `false`) | For a pressable surface, use `GlassPressable`, which is interactive by default. |
| `tintColor` | `tintColor` | |
| `colorScheme="auto" \| "light" \| "dark"` | `colorScheme="system" \| "light" \| "dark"` | `auto` is `system`. |
| `style.borderRadius` | `cornerRadius` | The native shape ignores `borderRadius`. |
| `ref` | `ref` (`GlassHostRef`) | Resolves to the native host view. |

## GlassContainer

| expo-glass-effect | This package | Notes |
| --- | --- | --- |
| `spacing` | `spacing` + `mergingEnabled` | Merging is opt-in. Passing only `spacing` merges nothing and logs a development warning. |

```tsx
// expo-glass-effect
<GlassContainer spacing={20}>…</GlassContainer>
// this package
<GlassContainer mergingEnabled spacing={20}>…</GlassContainer>
```

## Availability checks

| expo-glass-effect | This package |
| --- | --- |
| `isLiquidGlassAvailable()` | `isLiquidGlassSupported()`: an OS check (iOS 26 or later). For what is actually drawn, use `useGlassTier()`, which returns `'glass'`, `'blur'` or `'solid'` and follows Reduce Transparency as it changes. |
| `isGlassEffectAPIAvailable()` | No equivalent. The package is built with Xcode 26 and uses the glass APIs only on iOS 26 or later. |

## What you gain

Native menus, toolbars, tab bars, icon buttons, segmented controls and sliders use the same glass tiers. `GlassFallbackThemeProvider` themes the opaque fallbacks, and `fallbackMaterial="solid"` keeps long lists cheap on older iOS. See the [README](../README.md) for the component list and platform matrix.
