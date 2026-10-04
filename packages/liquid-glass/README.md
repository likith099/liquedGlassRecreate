# React Native Adaptive Liquid Glass

[![npm](https://img.shields.io/npm/v/@likith99/react-native-adaptive-liquid-glass)](https://www.npmjs.com/package/@likith99/react-native-adaptive-liquid-glass)
[![license](https://img.shields.io/npm/l/@likith99/react-native-adaptive-liquid-glass)](https://github.com/likith099/liquedGlassRecreate/blob/main/LICENSE)
[![CI](https://github.com/likith099/liquedGlassRecreate/actions/workflows/ci.yml/badge.svg)](https://github.com/likith099/liquedGlassRecreate/actions/workflows/ci.yml)

Native iOS 26 Liquid Glass components for React Native, with system blur on older iOS and standard
controls on Android.

Every component is a real native view (`UIGlassEffect`, `UIMenu`, `UITabBarController`, SwiftUI
glass buttons), not a JavaScript imitation, and each one falls back to the platform's own controls
where glass is not available.

<p align="center">
  <img src="https://raw.githubusercontent.com/likith099/liquedGlassRecreate/v0.1.1/docs/images/demo.gif" width="280" alt="Demo: tapping a glass button, expanding the action cluster, and changing the material live on iOS 26">
</p>

<table>
  <tr>
    <td align="center"><img src="https://raw.githubusercontent.com/likith099/liquedGlassRecreate/v0.1.3/docs/images/badges-pills.png" width="260" alt="Glass badges over an image, expanding filter pills with Recent selected, and a round purple add button"><br><sub>Badges, expanding pills and a floating button</sub></td>
    <td align="center"><img src="https://raw.githubusercontent.com/likith099/liquedGlassRecreate/v0.1.3/docs/images/toolbar-icon-buttons.png" width="260" alt="A glass toolbar with three round buttons, a menu button, and round close and more icon buttons"><br><sub>Toolbar, menu and icon buttons</sub></td>
    <td align="center"><img src="https://raw.githubusercontent.com/likith099/liquedGlassRecreate/v0.1.3/docs/images/context-menu.png" width="180" alt="A long-pressed message card shown above a native context menu with edit, forward, save and delete actions"><br><sub>Long-press context menu</sub></td>
  </tr>
  <tr>
    <td align="center" colspan="3"><img src="https://raw.githubusercontent.com/likith099/liquedGlassRecreate/v0.1.3/docs/images/tab-bar-colours.png" width="400" alt="An iOS 26 glass tab bar with Library selected in green and a custom diamond icon"><br><img src="https://raw.githubusercontent.com/likith099/liquedGlassRecreate/v0.1.3/docs/images/android-tab-bar.png" width="400" alt="The same tabs as a Material bottom navigation bar on Android"><br><sub>One tab bar: iOS 26 glass (top) and Android Material (bottom), each tab in its own colour</sub></td>
  </tr>
</table>

## Features

- **Real Liquid Glass on iOS 26:** surfaces, buttons, menus, toolbars and tabs use Apple's native
  glass, including touch response and optional merging between nearby surfaces.
- **Works everywhere else:** system blur on iOS 15.1–25, opaque themed surfaces under Reduce
  Transparency, and standard Material controls on Android, all behind the same API.
- **Native menus and tabs:** `UIMenu` on iOS and a Material-style popup on Android (icons,
  custom corner radius and colours) with sections, checkmarks and destructive
  items; a native tab bar with badges, custom artwork and per-tab colours.
- **New in 0.1.6:** long-press message menus with a separate content preview, using
  Apple's own context menu (`GlassContextMenu` `menuPlacement="below"`), and `GlassMenuPanel` to
  open Apple's menu from a positioned anchor. UIKit controls final placement.
- **New in 0.1.3:** icon buttons, long-press context menus, expanding pill tabs, search field,
  scroll-edge effect, toasts and badges.
- **No runtime dependencies:** no Expo modules or third-party glass library. TypeScript types
  included.

## Requirements

| | |
| --- | --- |
| React Native | 0.81 or newer, **New Architecture** (tested on 0.81.5, 0.86.3, 0.87.1) |
| React | 19 or newer |
| iOS | 15.1 or newer, built with Xcode 26+. Glass on iOS 26; system materials below. |
| Android | React Native's minimum SDK (24); Material Components 1.13 |
| Expo | Development builds only; Expo Go cannot load native modules |

> Some React Native versions need host app settings: 0.81 uses prebuilt iOS dependencies, 0.87
> builds React from source, and iOS 27 requires the UIScene lifecycle. See
> [compatibility](https://github.com/likith099/liquedGlassRecreate/blob/v0.1.7/docs/compatibility.md#host-app-setup).

## Installation

```sh
npm install @likith99/react-native-adaptive-liquid-glass
cd ios && pod install
```

Then rebuild the app. Autolinking registers the iOS pod and the Android module; a JavaScript
reload alone does not load new native code.

## Usage

```tsx
import {Text} from 'react-native';
import {GlassView, GlassButton, GlassTabBar} from '@likith99/react-native-adaptive-liquid-glass';

<GlassView interactive cornerRadius={24} style={{padding: 20}}>
  <Text>Any React Native content on glass</Text>
</GlassView>

<GlassButton title="Add to collection" systemImage="plus" variant="prominent" onPress={add} />

<GlassTabBar value={tab} onValueChange={setTab} items={[
  {id: 'home', title: 'Home', icon: 'home'},
  {id: 'inbox', title: 'Inbox', icon: 'inbox', badge: 3},
]} />
```

Every component is controlled: pass the current value and update it in the callback.

## Components

| Component | What it is | Docs |
| --- | --- | --- |
| `GlassView`, `GlassContainer`, `GlassPressable` | Glass surfaces for your own content; opt-in merging; pressable cards | [Surfaces](https://github.com/likith099/liquedGlassRecreate/blob/v0.1.7/docs/surfaces.md) |
| `GlassBadge`, `GlassToastProvider`, `GlassScrollEdge` | Labels over imagery, confirmation toasts, content fading under floating bars | [Surfaces](https://github.com/likith099/liquedGlassRecreate/blob/v0.1.7/docs/surfaces.md) |
| `GlassButton`, `GlassSegmentedControl`, `GlassSlider` | Native button, segmented control (with counts) and slider | [Controls](https://github.com/likith099/liquedGlassRecreate/blob/v0.1.7/docs/controls.md) |
| `GlassSearchField`, `GlassExpandingTabs` | Search field; pill tabs where the selected pill shows its label | [Controls](https://github.com/likith099/liquedGlassRecreate/blob/v0.1.7/docs/controls.md) |
| `GlassMenuButton`, `GlassIconButton`, `GlassContextMenu`, `GlassMenuPanel`, `GlassLongPress` | Menu buttons, round icon buttons and floating action buttons, long-press content previews and Apple's menu from a positioned anchor | [Menus](https://github.com/likith099/liquedGlassRecreate/blob/v0.1.7/docs/menus.md) |
| `GlassToolbar` | Toolbar with actions, menus and automatic overflow | [Toolbars](https://github.com/likith099/liquedGlassRecreate/blob/v0.1.7/docs/toolbars.md) |
| `GlassTabBar` | Native tab bar with badges, custom images and per-tab colours | [Tabs](https://github.com/likith099/liquedGlassRecreate/blob/v0.1.7/docs/tabs.md) |
| `GlassActionCluster` | A button that expands into a row of glass actions | [Action clusters](https://github.com/likith099/liquedGlassRecreate/blob/v0.1.7/docs/action-clusters.md) |
| `useGlassTier()`, `GlassFallbackThemeProvider` | Which material is showing (`glass`, `blur`, `solid`); theme colours for the opaque tier | [Surfaces](https://github.com/likith099/liquedGlassRecreate/blob/v0.1.7/docs/surfaces.md#theming-the-opaque-tier) |

## Platform behaviour

| | iOS 26+ | iOS 15.1–25 | Android |
| --- | --- | --- | --- |
| Surfaces | Liquid Glass | System blur | Opaque, themeable |
| Controls, menus, tabs | Native, with glass | Standard UIKit and React Native controls | Material and platform views |
| Reduce Transparency | Opaque surfaces | Opaque surfaces | — |

## Documentation

- [Accessibility](https://github.com/likith099/liquedGlassRecreate/blob/v0.1.7/docs/accessibility.md): text size, Reduce Motion and Transparency, screen readers
- [Migrating from expo-glass-effect](https://github.com/likith099/liquedGlassRecreate/blob/v0.1.7/docs/migrating-from-expo-glass-effect.md)
- [Compatibility](https://github.com/likith099/liquedGlassRecreate/blob/v0.1.7/docs/compatibility.md): tested versions and known gaps
- [Changelog](https://github.com/likith099/liquedGlassRecreate/blob/v0.1.7/packages/liquid-glass/CHANGELOG.md)

## Contributing

The [repository](https://github.com/likith099/liquedGlassRecreate) includes a demo app that
exercises every component, and the UI tests that run in CI on iOS and Android. See
[developing the package](https://github.com/likith099/liquedGlassRecreate/blob/v0.1.7/docs/development.md).

## License

MIT
