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
  /** SF Symbol on iOS; Android uses the title. */
  systemImage?: string;
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
}
