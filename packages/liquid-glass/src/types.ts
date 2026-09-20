import type {ColorValue, PressableProps, StyleProp, ViewProps, ViewStyle} from 'react-native';
export interface GlassViewProps extends ViewProps {
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
}
export interface GlassContainerProps extends ViewProps {
  /** Allow nearby glass surfaces to join. Defaults to false. */
  mergingEnabled?: boolean;
  /** Native merging threshold in points when enabled, not the layout gap. */
  spacing?: number;
  forceFallback?: boolean;
}
export interface GlassPressableProps extends Omit<PressableProps, 'style' | 'children'> {
  title?: never;
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  contentStyle?: StyleProp<ViewStyle>;
  material?: GlassViewProps['material'];
  tintColor?: ColorValue;
  cornerRadius?: number;
  fallbackStyle?: StyleProp<ViewStyle>;
  forceFallback?: boolean;
}
/** SwiftUI owns the title/icon button on iOS 26+. */
export interface NativeGlassButtonProps extends Omit<ViewProps, 'children'> {
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
}
export interface GlassSegmentedControlProps extends Omit<ViewProps, 'children'> {
  options: readonly GlassSegment[];
  value: string | null;
  onValueChange: (value: string) => void;
  disabled?: boolean;
  tintColor?: ColorValue;
  colorScheme?: 'system' | 'light' | 'dark';
  forceFallback?: boolean;
}
export interface GlassSliderProps extends Omit<ViewProps, 'children'> {
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
  /** Stable unique identity used to retain the native action control. '__toggle' is reserved. */
  id: string;
  title: string;
  /** SF Symbol name on iOS. Android uses title. */
  systemImage?: string;
  disabled?: boolean;
}
export interface GlassActionClusterProps extends Omit<ViewProps, 'children'> {
  actions: readonly GlassAction[];
  expanded: boolean;
  onExpandedChange: (expanded: boolean) => void;
  onAction: (id: string) => void;
  /** Enable shared glass merging and morphing. Defaults to false. */
  mergingEnabled?: boolean;
  spacing?: number;
  /** Native material tint. Default: neutral dark-mode shading; overrides replace it. */
  tintColor?: ColorValue;
  material?: 'regular' | 'clear';
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
export interface GlassToolbarProps extends Omit<ViewProps, 'children'> {
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
export interface GlassMenuButtonProps extends Omit<ViewProps, 'children'> {
  title: string;
  items: readonly GlassMenuElement[];
  onAction: (id: string) => void;
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
  /** Drawable resource name in the consuming Android application. */
  androidIcon?: string;
  badge?: number | 'dot';
  disabled?: boolean;
  accessibilityLabel?: string;
}
export interface GlassTabBarProps extends Omit<ViewProps, 'children'> {
  items: readonly GlassTabItem[];
  /** Required for nonempty items. Set null only when items are empty. */
  value: string | null;
  onValueChange: (id: string) => void;
  onTabReselect?: (id: string) => void;
  disabled?: boolean;
  tintColor?: ColorValue;
}
