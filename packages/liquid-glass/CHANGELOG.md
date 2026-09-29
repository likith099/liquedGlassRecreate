# Changelog

All notable changes to `@likith99/react-native-adaptive-liquid-glass`. Versions follow
[semantic versioning](https://semver.org); while the major version is 0, minor versions may
change the API.

## Unreleased

### Added

- `GlassMenuPanel`: the system menu as a native view the app places itself, never presented by
  UIKit. iOS 26 glass platter and rows matching UIKit's menu (250 pt, 40 pt rows), final material
  from the first frame; system material below iOS 26; the `androidMenuStyle` popup look with
  ripples on Android. Touch highlights a row, sliding moves it with a selection tick, lifting on an
  enabled row calls `onAction`. `GlassMenuPanel.measure(items)` gives the height before it draws;
  also `width`, `maxHeight` with native scrolling, `colorScheme`, `appearFrom`, `dismiss()`,
  `autoFocus` and `accessibilityModal`. Sections only; submenus are rejected.
- `GlassLongPress`: a native long press around any content that reports the content's window
  frame, cancels the content's touches once recognised, and hands the same finger to the latest
  `GlassMenuPanel`, so a press can slide onto a row and lift to choose it.
- `GlassContextMenu`: `onOpen` and `onClose`, and per-corner `previewCornerRadii`.

Rebuild both native apps: this release adds native components.

## 0.1.4 — September 28, 2026

### Added

- Android menus can show item icons (`androidIcon` on menu items and submenus) and take
  `androidMenuStyle` on `GlassMenuButton`, `GlassIconButton` and `GlassContextMenu`: corner radius,
  and background, text, icon and destructive colours, each for light and dark.

### Changed

- Android menu buttons, icon buttons and context menus open a Material 3-style popup (rounded
  surface, icons, checkmarks, submenus shown in place) instead of the system `PopupMenu`. Rebuild
  the Android app after upgrading: the menu component gained a prop.

### Fixed

- `GlassExpandingTabs` (Android): switching pills made the whole row shake sideways. The pill widths
  were animated from JavaScript, and on the New Architecture those updates reach the views out of
  step with the layout the other pills are placed from. The pills now animate with transforms and
  opacity only, on the native driver, so every pill moves in the same frame.

## 0.1.3 — September 28, 2026

Rebuild both native apps after upgrading: the menu and tab Fabric components gained props.

### Added

- `GlassContextMenu` wraps any React content with a long-press native menu:
  `UIContextMenuInteraction` with a retained-content preview on iOS, an anchored `PopupMenu` on
  Android. `forceFallback` shows a plain anchored menu.
- `GlassIconButton`: a round, symbol-only glass button or menu button, with `size`,
  `symbolPointSize` and `colorScheme`.
- `GlassMenuButton` and `GlassIconButton` accept `onOpen` / `onClose`. Their ref is a
  `GlassMenuHandle` with `open()`: iOS 17.4+ `performPrimaryAction()` and Android
  `PopupMenu.show()`.
- `useGlassTier()`: the live material tier (`glass`, `blur` or `solid`), following Reduce
  Transparency.
- `GlassFallbackThemeProvider` themes the opaque fallback surfaces and text. Defaults are
  unchanged.
- `fallbackMaterial: 'blur' | 'solid'` on `GlassView` and `GlassPressable` selects the opaque
  surface below iOS 26, for long lists.
- `GlassTabBar` items (iOS): `image` / `selectedImage` asset names, and per-tab
  `selectedTintColor` / `inactiveTintColor`. On iOS 26, icon and label are drawn into one image
  per state, so the drag lens shows each tab in its own colour.
- `GlassTabBar` image sources on both platforms: `image` / `selectedImage` accept `require()` and
  `{uri}`, loaded at runtime and held in memory, with `imageRenderingMode`.
- `GlassTabBar` colours: per-tab colours now apply on Android too; a bar-wide `inactiveTintColor`;
  Android `androidBackgroundColor` and `androidIndicatorColor`.
- `GlassBadge`: a label on material for imagery. It tints the older-iOS blur (and optionally the
  glass), and uses `solidColor` on Android and under Reduce Transparency.
- `GlassSegmentedControl` options accept `count` and a per-option `tintColor`.
- `GlassIconButton` accepts `variant="prominent"` for floating action buttons.
- `GlassExpandingTabs`: icon pills that expand to show the selected label. One progress value per
  pill drives width, label reveal and colour; glass on iOS 26 with opt-in merging; `onReselect`.
- `GlassSearchField`: a controlled system search field on material, with `focus()` / `blur()`.
- `GlassToastProvider` and `useGlassToast()`: glass confirmations announced to screen readers.
- `GlassScrollEdge`: the iOS 26 scroll-edge effect under floating bars, with a gradient scrim
  elsewhere.
- `GlassPressable` accepts `interactive` (default true) so large tappable cards and rows can use
  non-deforming glass, and forwards `colorScheme` to its surface.
- Every component's `ref` is typed as `GlassHostRef` and resolves to its outermost native host
  view.
- A one-time development warning when `GlassContainer` receives `spacing` without
  `mergingEnabled`. Merging stays opt-in.

### Packaging

- The package ships compiled JavaScript (`lib/module`) and generated type definitions
  (`lib/typescript`), built with react-native-builder-bob, with an `exports` map. `src` still ships
  for React Native codegen and as the `source` export condition.
- Android apps can pin Material Components with `ext.adaptiveGlassMaterialVersion`.

### Changed

- No action ID is reserved in `GlassActionCluster`; `__toggle` is now accepted.

### Documentation

- The READMEs are shorter, with current screenshots; component detail moved to `docs/controls.md`,
  `docs/surfaces.md`, `docs/development.md` and a host-app setup section in `docs/compatibility.md`.
- iOS tab bars: extend the host to the bottom edge and include the bottom inset in its height.
  Padding it above the home indicator left the iOS 26 bar 34 points too high.
- New surfaces reference and `expo-glass-effect` migration guide.

### Fixed

- `GlassTabBar` (iOS 18.4+): configuring a controller that was not yet attached, or rebuilding
  items and selection in one render, could assert inside UIKit's tab model and terminate the app.
  Selection now waits for attachment and uses the tab UIKit holds. The legacy view-controller
  array is never installed over an adopted `UITab` list.
- `GlassTabBar` (iOS 18.4+): the tab selected when UIKit built the bar could keep its selected
  image. Images now come from the configured artwork instead of `tabBarItem`, which UIKit
  overwrites.
- `GlassTabBar` below iOS 26 now uses the standard bar background rather than the transparent
  scroll-edge appearance.
- `GlassToolbar` on iOS 26: Sort and overflow controls no longer turn into an opaque disk for
  about a second after a menu closes. Controls are glass buttons that own their menus; the
  standard `UIToolbar` remains for older iOS, `forceFallback` and Reduce Transparency.
- `GlassContextMenu` (Android): a long press on the wrapped React content never opened the menu,
  because React Native views claim every touch before the host's long-click listener. The host
  now watches the gesture itself and cancels JavaScript responders when the menu opens, so a
  pressable inside the content does not also fire.
- `GlassSearchField` (Android): queries are no longer auto-capitalised, matching Android's
  `SearchView`.
- `GlassExpandingTabs` (Android): a development warning names options without `androidIcon`,
  whose collapsed pills would otherwise be empty.
- `GlassExpandingTabs` (iOS 26): the pill row's scroll view clipped the glass shadow, drawing a
  hard-edged grey band behind the pills. The row no longer clips, so the shadow fades naturally and
  pills scroll under the row's inset.

## 0.1.2

- Optional stock SwiftUI implementation for `GlassActionCluster`.
- iPhone fallback verification.

## 0.1.1

- React Native 0.87 support; the React Native peer range no longer has an upper bound.

## 0.1.0

First public release: surfaces, native buttons, segmented control, slider, action cluster, menus,
toolbar and tab bar, with iOS 15.1+ fallbacks and Android counterparts.
