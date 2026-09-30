import type React from 'react';
import type {ColorValue, ImageSourcePropType, PressableProps, StyleProp, TextStyle, View, ViewProps, ViewStyle} from 'react-native';
/** The native host view a component ref resolves to (measure, focus, layout). */
export type GlassHostRef = React.ComponentRef<typeof View>;
/** React 19 passes ref as a prop; every component forwards it to its outermost host view. */
export interface GlassRefProp {
  ref?: React.Ref<GlassHostRef>;
}
export interface GlassViewProps extends ViewProps, GlassRefProp {
  material?: 'regular' | 'clear' | 'none';
  interactive?: boolean;
  tintColor?: ColorValue;
  /** Uniform native shape radius. Use this instead of style.borderRadius. */
  cornerRadius?: number;
  /** Seconds, 0 disables material transitions. Reduce Motion takes precedence. */
  animationDuration?: number;
  colorScheme?: 'system' | 'light' | 'dark';
  /** Surface style applied on older iOS, Android, or in forced fallback mode. */
  fallbackStyle?: StyleProp<ViewStyle>;
  /** Use an opaque React surface instead of native glass or older-iOS blur. */
  forceFallback?: boolean;
  /**
   * Surface below iOS 26: system blur (default) or the opaque React surface. `solid` is
   * cheaper in long lists and on older devices. iOS 26 glass is unaffected.
   */
  fallbackMaterial?: 'blur' | 'solid';
}
export interface GlassContainerProps extends ViewProps, GlassRefProp {
  /** Allow nearby glass surfaces to join. Defaults to false. */
  mergingEnabled?: boolean;
  /** Native merging threshold in points when enabled, not the layout gap. */
  spacing?: number;
  forceFallback?: boolean;
}
export interface GlassPressableProps extends Omit<PressableProps, 'style' | 'children'>, GlassRefProp {
  title?: never;
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  contentStyle?: StyleProp<ViewStyle>;
  material?: GlassViewProps['material'];
  tintColor?: ColorValue;
  cornerRadius?: number;
  /**
   * Whether the glass deforms and highlights under touch. Defaults to true; always false
   * while disabled. Set false for large tappable surfaces such as cards and rows.
   */
  interactive?: boolean;
  /** Pins the material appearance, for example dark glass over media in light mode. */
  colorScheme?: GlassViewProps['colorScheme'];
  fallbackMaterial?: GlassViewProps['fallbackMaterial'];
  fallbackStyle?: StyleProp<ViewStyle>;
  forceFallback?: boolean;
}
/** SwiftUI owns the title/icon button on iOS 26+. */
export interface NativeGlassButtonProps extends Omit<ViewProps, 'children'>, GlassRefProp {
  children?: never;
  title: string;
  systemImage?: string;
  variant?: 'regular' | 'prominent';
  disabled?: boolean;
  loading?: boolean;
  onPress: () => void;
  tintColor?: ColorValue;
  colorScheme?: 'system' | 'light' | 'dark';
  forceFallback?: boolean;
}
/** Custom children remain supported for compatibility; prefer GlassPressable for them. */
export type GlassButtonProps = NativeGlassButtonProps | GlassPressableProps;
export interface GlassSegment {
  value: string;
  label: string;
  disabled?: boolean;
  /** Shown after the label, for example "Saved 3". Values above 99 show as "99+". */
  count?: number;
  /** Selected-segment colour for this option; overrides the control's tintColor. A static colour. */
  tintColor?: ColorValue;
}
export interface GlassSegmentedControlProps extends Omit<ViewProps, 'children'>, GlassRefProp {
  options: readonly GlassSegment[];
  value: string | null;
  onValueChange: (value: string) => void;
  disabled?: boolean;
  tintColor?: ColorValue;
  colorScheme?: 'system' | 'light' | 'dark';
  forceFallback?: boolean;
}
export interface GlassSliderProps extends Omit<ViewProps, 'children'>, GlassRefProp {
  /** Controlled value; clamped to the range and snapped to step. */
  value: number;
  onValueChange: (value: number) => void;
  minimumValue?: number;
  maximumValue?: number;
  /** 0 means continuous; positive steps are anchored at minimumValue. */
  step?: number;
  disabled?: boolean;
  tintColor?: ColorValue;
  onSlidingStart?: (value: number) => void;
  onSlidingComplete?: (value: number) => void;
  /** Cancellation restores the latest controlled value; it is not completion. */
  onSlidingCancel?: (value: number) => void;
}
export interface GlassAction {
  /** Stable unique identity used to retain the native action control. */
  id: string;
  title: string;
  /** SF Symbol name on iOS. Android uses title. */
  systemImage?: string;
  disabled?: boolean;
}
export interface GlassActionClusterProps extends Omit<ViewProps, 'children'>, GlassRefProp {
  /** iOS 26+: current UIKit material controls (default) or stock SwiftUI glass buttons.
   * Older iOS, Android and narrow hosts use the standard fallback in either mode. */
  iosImplementation?: 'uikit' | 'swiftui';
  actions: readonly GlassAction[];
  expanded: boolean;
  onExpandedChange: (expanded: boolean) => void;
  onAction: (id: string) => void;
  /** Enable shared glass merging and morphing. Defaults to false. */
  mergingEnabled?: boolean;
  spacing?: number;
  /** UIKit: material tint (neutral dark-mode shading by default).
   * SwiftUI: standard button tint; no custom default shading. */
  tintColor?: ColorValue;
  /** UIKit only; SwiftUI uses its standard glass material. */
  material?: 'regular' | 'clear';
  /** UIKit only; SwiftUI retains standard button feedback. Does not disable actions. */
  interactive?: boolean;
  /** @deprecated Ignored. Native glass feedback follows interactive; custom feedback was removed. */
  pressFeedback?: 'subtle' | 'native';
  animationDuration?: number;
  toggleLabel?: string;
  forceFallback?: boolean;
}

export interface GlassMenuItem {
  kind?: 'action';
  id: string;
  title: string;
  /** SF Symbol on iOS. */
  systemImage?: string;
  /** Android drawable resource name, shown beside the title in the menu. */
  androidIcon?: string;
  disabled?: boolean;
  destructive?: boolean;
  /** Controlled checkmark. Update items in onAction to change selection. */
  checked?: boolean;
}
export interface GlassMenuSubmenu {
  kind: 'submenu';
  id: string;
  title: string;
  systemImage?: string;
  /** Android drawable resource name. */
  androidIcon?: string;
  disabled?: boolean;
  items: readonly GlassMenuElement[];
}
export interface GlassMenuSection {
  kind: 'section';
  id: string;
  /** Empty title creates an untitled group. */
  title: string;
  items: readonly GlassMenuElement[];
}
export type GlassMenuElement = GlassMenuItem | GlassMenuSubmenu | GlassMenuSection;
/** One static colour for both appearances, or one for each. */
export type GlassSchemeColor = ColorValue | {light: ColorValue; dark: ColorValue};
/**
 * Android menu popup appearance. iOS menus are drawn by UIKit and keep the system appearance.
 * Colours must be static (strings or numbers), not PlatformColor.
 */
export interface GlassMenuStyle {
  /** Corner radius in dp. Defaults to 16. */
  cornerRadius?: number;
  /** Popup surface. Defaults to #FFFFFF (light) and #1A1B20 (dark). */
  backgroundColor?: GlassSchemeColor;
  /** Item titles. */
  textColor?: GlassSchemeColor;
  /** Item icons and the submenu and checkmark indicators. */
  iconColor?: GlassSchemeColor;
  /** Titles and icons of destructive items. */
  destructiveColor?: GlassSchemeColor;
}
export type GlassToolbarItem = (GlassMenuItem | GlassMenuSubmenu) & {
  /** Automatic items may move into overflow when space is limited. */
  placement?: 'automatic' | 'overflow';
};
export interface GlassToolbarProps extends Omit<ViewProps, 'children'>, GlassRefProp {
  items: readonly GlassToolbarItem[];
  onAction: (id: string) => void;
  disabled?: boolean;
  /** Upper limit, not a guarantee. 0 places all items in overflow. Default 3. */
  maxVisibleItems?: number;
  /** Allow adjacent iOS toolbar items to share a native background. Default false. */
  mergingEnabled?: boolean;
  tintColor?: ColorValue;
  forceFallback?: boolean;
}
export interface GlassContextMenuProps extends ViewProps, GlassRefProp {
  items: readonly GlassMenuElement[];
  onAction: (id: string) => void;
  disabled?: boolean;
  /** Shared plain anchored menu on either platform; content stays in place. Default false. */
  forceFallback?: boolean;
  /** iOS lifted preview outline only; does not clip children. Default 16. */
  previewCornerRadius?: number;
  /** iOS: a radius per corner for the lifted preview, for example a grouped bubble's tight corner.
   * Corners left out use previewCornerRadius. */
  previewCornerRadii?: {topLeft?: number; topRight?: number; bottomLeft?: number; bottomRight?: number};
  /**
   * iOS: where the menu opens. 'system' (default) is UIKit's placement around the content in place,
   * which puts the menu above content in the lower half of the screen. 'below' opens it below the
   * content, as Messages does: the press-in plays in place, then the lifted content glides up only as
   * far as the menu needs and the menu emerges from behind it; both return on close. UIKit lays out
   * and animates both. Android opens its popup below the content whenever it fits.
   */
  menuPlacement?: 'system' | 'below';
  /** The menu opened. */
  onOpen?: () => void;
  /** The menu closed, after its dismissal animation, with or without an action. */
  onClose?: () => void;
  /** Android: corner radius and colours of the menu popup. */
  androidMenuStyle?: GlassMenuStyle;
}
/**
 * Ref handle for menu buttons: the host view's measurement and focus methods, plus open().
 */
export interface GlassMenuHandle extends Pick<GlassHostRef, 'measure' | 'measureInWindow' | 'measureLayout' | 'focus' | 'blur'> {
  /**
   * Presents the menu as if tapped. iOS 17.4+ and Android. A no-op on older iOS, while
   * disabled, without items, or before the button is on screen. Menu placement is the system's.
   */
  open(): void;
}
export interface GlassMenuButtonProps extends Omit<ViewProps, 'children'> {
  ref?: React.Ref<GlassMenuHandle>;
  title: string;
  items: readonly GlassMenuElement[];
  onAction: (id: string) => void;
  /** The menu was presented, by a tap or open(). */
  onOpen?: () => void;
  /** The menu was dismissed, after its closing animation, with or without an action. */
  onClose?: () => void;
  systemImage?: string;
  disabled?: boolean;
  /** Button foreground accent, not menu material tint. */
  tintColor?: ColorValue;
  /** Preview the standard iOS button. Android always uses its standard button. */
  forceFallback?: boolean;
  /** Android: corner radius and colours of the menu popup. */
  androidMenuStyle?: GlassMenuStyle;
}

export type GlassTabIcon = 'home' | 'search' | 'library' | 'favorites' | 'inbox' | 'settings';
export interface GlassTabItem {
  id: string;
  title: string;
  /** Built-in platform icon preset; defaults to a circle when absent. */
  icon?: GlassTabIcon;
  systemImage?: string;
  selectedSystemImage?: string;
  /**
   * Tab artwork, tried before systemImage. A string is an iOS asset-catalog name. An image source
   * (`require('./tab.png')` or `{uri}`) works on both platforms: it is loaded at runtime and kept
   * in memory. Artwork larger than 30 pt is scaled down to fit.
   */
  image?: string | ImageSourcePropType;
  /** Artwork for the selected state, in the same forms as `image`. */
  selectedImage?: string | ImageSourcePropType;
  /**
   * `template` (the default for image sources) draws the artwork's shape in the tab colours;
   * `original` keeps its own colours. Asset-catalog images default to their catalog setting.
   */
  imageRenderingMode?: 'template' | 'original';
  /**
   * This tab's icon and label colour while selected. On iOS icons are baked, so the colour also
   * holds under the iOS 26 drag lens. A static colour (string or number), not PlatformColor.
   */
  selectedTintColor?: ColorValue;
  /** This tab's icon and label colour while not selected. A static colour. */
  inactiveTintColor?: ColorValue;
  /** Drawable resource name in the consuming Android application, tried before `image`. */
  androidIcon?: string;
  badge?: number | 'dot';
  disabled?: boolean;
  accessibilityLabel?: string;
}
export interface GlassTabBarProps extends Omit<ViewProps, 'children'>, GlassRefProp {
  items: readonly GlassTabItem[];
  /** Required for nonempty items. Set null only when items are empty. */
  value: string | null;
  onValueChange: (id: string) => void;
  onTabReselect?: (id: string) => void;
  disabled?: boolean;
  tintColor?: ColorValue;
  /** Icon and label colour of every tab while not selected; a tab's own inactiveTintColor wins. A static colour. */
  inactiveTintColor?: ColorValue;
  /** Android: the bar's surface colour. iOS keeps the system glass or bar material. */
  androidBackgroundColor?: ColorValue;
  /** Android: the Material 3 active-indicator pill behind the selected icon. */
  androidIndicatorColor?: ColorValue;
}

export interface GlassExpandingTab {
  value: string;
  /** Shown when selected, and always read by screen readers. */
  label: string;
  /** iOS SF Symbol. */
  systemImage: string;
  /** Android drawable resource name. */
  androidIcon?: string;
  /** This tab's ink and selected fill. A static colour. */
  tintColor?: ColorValue;
  disabled?: boolean;
}
/** A row of icon pills where the selected one expands to show its label. */
export interface GlassExpandingTabsProps extends Omit<ViewProps, 'children'>, GlassRefProp {
  options: readonly GlassExpandingTab[];
  value: string;
  onValueChange: (value: string) => void;
  /** `glass` pills on iOS 26, or neutral `tinted` plates; the selected pill gets a wash of its
   * colour either way. Defaults to glass. Below iOS 26 and under Reduce Transparency the plates
   * are neutral fills. */
  material?: 'glass' | 'tinted';
  /** Let neighbouring glass pills merge (iOS 26). Defaults to false. */
  mergingEnabled?: boolean;
  /** The selected pill was tapped again, for example to scroll its content to the top. */
  onReselect?: (value: string) => void;
  /** Horizontal inset of the first and last pill; the row scrolls under it. Defaults to 16. */
  contentInset?: number;
  /** Default ink for tabs without their own tintColor. */
  tintColor?: ColorValue;
  disabled?: boolean;
}
/** Ref handle for GlassMenuPanel: the host view's measurement, plus a native dismissal. */
export interface GlassMenuPanelHandle extends Pick<GlassHostRef, 'measure' | 'measureInWindow' | 'measureLayout'> {
  /**
   * Presents the menu over the panel's frame: Apple's native UIMenu on iOS 17.4+, the menu popup on
   * Android, the plain fallback menu on older iOS. A no-op while disabled, without items, or before
   * the panel is on screen.
   */
  open(): void;
}
/**
 * An invisible anchor for the native menu. Give it the menu's exact frame with `style` (position
 * from computeFocusMenuLayout or your own layout, size from GlassMenuPanel.measure), then call
 * `ref.open()`: iOS 26 grows its own menu out of the anchor and covers it exactly, whichever way it
 * opens, so the menu appears where the anchor is.
 */
export interface GlassMenuPanelProps extends Omit<ViewProps, 'children'> {
  ref?: React.Ref<GlassMenuPanelHandle>;
  /** Actions, sections and submenus, as for GlassMenuButton. */
  items: readonly GlassMenuElement[];
  /** An enabled item was chosen. */
  onAction: (id: string) => void;
  /** The menu was presented. */
  onOpen?: () => void;
  /** The menu was dismissed, after its closing animation, with or without an action. */
  onClose?: () => void;
  /** Blocks the menu. */
  disabled?: boolean;
  /** Use the plain fallback menu on every platform. Default false. */
  forceFallback?: boolean;
  /** Android: corner radius and colours of the menu popup; iOS keeps the system menu. */
  androidMenuStyle?: GlassMenuStyle;
}
/** Window-point frame of the view a long press began on. */
export interface GlassMenuPanelMeasureOptions {
  /** The system text-size multiplier; defaults to the current one (PixelRatio.getFontScale()). */
  fontScale?: number;
  /** Caps the height; UIKit scrolls a taller menu. */
  maxHeight?: number;
}
/** The platform menu's size in points, before it opens. */
export interface GlassMenuSize {
  width: number;
  height: number;
}
export interface FocusMenuRect {
  x: number;
  y: number;
  width: number;
  height: number;
}
/** Everything in window points, measured after the keyboard is down. */
export interface FocusMenuLayoutInput {
  /** The pressed message where it sits now (GlassLongPress's `frame`). */
  bubble: FocusMenuRect;
  /** Sent by the viewer (right side): the menu hugs the message's right edge; otherwise its left. */
  isOwn: boolean;
  window: {width: number; height: number};
  /** Safe-area insets; the top limit is `topLimit`. */
  insets?: {left?: number; right?: number; bottom?: number};
  /** The bottom edge of the app's header: a message never sits above `topLimit + topGap`. */
  topLimit: number;
  /** GlassMenuPanel.measure(items).height. */
  menuHeight: number;
  /** GlassMenuPanel.measure(items).width, the width the menu is drawn at. Default min(248, window − 32). */
  menuWidth?: number;
  /** Message bottom to menu top. Default 10. */
  menuGap?: number;
  /** Header bottom to the highest a message may sit. Default 12. */
  topGap?: number;
  /** Closest the menu comes to a side of the window, inside the safe area. Default 8. */
  edge?: number;
}
export interface FocusMenuLayout {
  /** Where the message (or its lifted copy) goes: same x, same size; only y changes. */
  bubble: FocusMenuRect;
  /** The menu's frame: give it to GlassMenuPanel as its style. */
  menu: FocusMenuRect;
  /** Clip the lifted copy above this y (the header's bottom edge). */
  clipTop: number;
}
export interface GlassLongPressEvent {
  frame: {x: number; y: number; width: number; height: number};
}
/**
 * A native long press around React children. Before it is recognised the children's own taps and
 * an enclosing list's scroll keep working; once recognised it cancels the children's touch and
 * reports their frame, for example to place a GlassMenuPanel and open the native menu.
 */
export interface GlassLongPressProps extends ViewProps {
  children?: React.ReactNode;
  /** Milliseconds before the press is recognised. Defaults to 500. */
  minimumDuration?: number;
  /** Points the finger may move before recognition; more fails the press so a list can scroll.
   * Defaults to 10. */
  allowableMovement?: number;
  disabled?: boolean;
  /** Impact feedback when recognised. Defaults to 'none'. */
  haptic?: 'none' | 'light' | 'medium' | 'heavy' | 'soft' | 'rigid';
  onLongPress?: (event: GlassLongPressEvent) => void;
}
/** Ref handle for GlassSearchField: host measurement plus keyboard focus. */
export interface GlassSearchFieldHandle extends Pick<GlassHostRef, 'measure' | 'measureInWindow' | 'measureLayout'> {
  focus(): void;
  blur(): void;
}
/** A controlled search field on material. */
export interface GlassSearchFieldProps extends Omit<ViewProps, 'children'> {
  ref?: React.Ref<GlassSearchFieldHandle>;
  value: string;
  onChangeText: (text: string) => void;
  /** The return (Search) key was pressed; the keyboard is dismissed. */
  onSubmitEditing?: (text: string) => void;
  onFocus?: () => void;
  onBlur?: () => void;
  /** Defaults to "Search". */
  placeholder?: string;
  disabled?: boolean;
  /** Cursor and selection colour. */
  tintColor?: ColorValue;
  colorScheme?: 'system' | 'light' | 'dark';
  /** Opaque field instead of glass or blur. */
  forceFallback?: boolean;
}
/** A container for bars floating over a ScrollView's edge. */
export interface GlassScrollEdgeProps extends ViewProps, GlassRefProp {
  /** The ScrollView (or FlatList) under this container. */
  scrollViewRef: React.RefObject<unknown>;
  /** Which edge of the scroll view the container sits on. Defaults to bottom. */
  edge?: 'top' | 'bottom';
  /** iOS 26 edge-effect style. `soft` fades, `hard` adds a dividing edge; `automatic` lets UIKit choose. */
  effectStyle?: 'automatic' | 'soft' | 'hard';
  /** Below iOS 26 and on Android: a gradient scrim from this colour to clear, under the container. */
  fallbackColor?: ColorValue;
}
/** A small label on material that reads the same over bright and dark imagery. */
export interface GlassBadgeProps extends Omit<ViewProps, 'children'>, GlassRefProp {
  /** A string or number is rendered as a one-line label; other nodes render as given. */
  children: React.ReactNode;
  /** Material tint on iOS 15–25 blur, and on iOS 26 glass when `tintGlass` is set. */
  tintColor?: ColorValue;
  /** Also tint iOS 26 glass. Defaults to false, leaving the glass clear. */
  tintGlass?: boolean;
  /** Fill for Android, Reduce Transparency and `forceFallback`. */
  solidColor?: ColorValue;
  textColor?: ColorValue;
  colorScheme?: 'system' | 'light' | 'dark';
  /** Native shape radius. Defaults to 12, a capsule at the default height. */
  cornerRadius?: number;
  forceFallback?: boolean;
  textStyle?: StyleProp<TextStyle>;
}
/** A round, icon-only control: a native glass button, or a menu button when `menu` is set. */
export interface GlassIconButtonProps extends Omit<ViewProps, 'children'> {
  ref?: React.Ref<GlassMenuHandle>;
  /** iOS SF Symbol name. */
  systemImage: string;
  /** Spoken name; required because the control has no visible text. */
  accessibilityLabel: string;
  /** Android drawable resource name for the glyph. */
  androidIcon?: string;
  /** Diameter in points. Defaults to 44, the minimum recommended touch target. */
  size?: number;
  /** Glyph size in points. Defaults to 40% of `size`. */
  symbolPointSize?: number;
  /** Pins the material, for example dark glass over a photo in both themes. */
  colorScheme?: 'system' | 'light' | 'dark';
  /** Glyph colour; for `prominent`, the fill colour (the glyph is white). */
  tintColor?: ColorValue;
  /**
   * `prominent` fills the button with `tintColor`, for a floating action button: prominent glass
   * on iOS 26, a filled button below it. Defaults to `regular`.
   */
  variant?: 'regular' | 'prominent';
  disabled?: boolean;
  /** Preview the standard (gray) iOS button on iOS 26. */
  forceFallback?: boolean;
  /** Plain button action. Mutually exclusive with `menu`. */
  onPress?: () => void;
  /** Makes the control a menu button. Mutually exclusive with `onPress`. */
  menu?: {items: readonly GlassMenuElement[]; onAction: (id: string) => void};
  onOpen?: () => void;
  onClose?: () => void;
  /** Android: corner radius and colours of the menu popup. */
  androidMenuStyle?: GlassMenuStyle;
}
