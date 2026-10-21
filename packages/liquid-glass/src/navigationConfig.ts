import {controlAction, controlItems} from './controlConfig';
import {iconColor} from './iconOptions';
import type {GlassNavigationViewProps, GlassNavigationAction, GlassNavigationSpacer, GlassSchemeColor, GlassHeaderBand} from './types';
const warned = new Set<string>();
export function navigationWarning(message: string) {
  if (!warned.has(message)) { warned.add(message); console.warn(`[GlassNavigationView] ${message}`); }
}
export const isNavigationSpacer = (item: GlassNavigationAction | GlassNavigationSpacer): item is GlassNavigationSpacer => 'spacer' in item;
export function navigationItems(props: GlassNavigationViewProps) {
  const back: GlassNavigationAction[] = props.onBack ? [{id: '__navigation_back', symbol: 'chevron.backward', androidIcon: 'alg_back',
    accessibilityLabel: props.backAccessibilityLabel ?? 'Back', testID: props.backTestID ?? 'navigation-back'}] : [];
  const ids = new Set<string>();
  const valid = <T extends {id: string}>(items: readonly T[]): T[] => items.filter(item => {
    if (!item.id.trim() || ids.has(item.id)) {
      const message = 'Control IDs must be nonempty and unique across navigation placements.';
      if (__DEV__) throw new Error(message);
      navigationWarning(message + ' Invalid item dropped.'); return false;
    }
    ids.add(item.id); return true;
  });
  const leading = valid([...back, ...(props.leadingItems ?? [])]), trailing = valid(props.trailingItems ?? []), toolbar = valid(props.toolbarItems ?? []);
  const all = [...leading, ...trailing, ...toolbar.filter(item => !isNavigationSpacer(item))] as GlassNavigationAction[];
  controlItems(all);
  return {leading, trailing, toolbar, all};
}
export function navigationAction(props: GlassNavigationViewProps, id: string, action: string) {
  if (id === '__navigation_back' && props.onBack) props.onBack();
  else controlAction(navigationItems(props).all, id, action, props.onAction);
}
export function nativeNavigationItems(items: readonly (GlassNavigationAction | GlassNavigationSpacer)[]) {
  return items.map(item => isNavigationSpacer(item) ? item : ({...controlItems([item])[0], title: item.title,
    prominent: item.prominent, selected: item.selected, hidesSharedBackground: item.hidesSharedBackground,
    systemItem: item.systemItem, imageRendering: item.imageRendering, imageShape: item.imageShape}));
}
export function navigationTitleOptions(props: GlassNavigationViewProps) {
  const transition = props.titleView ? 'native' : props.titleTransition ?? 'native';
  let display = props.titleDisplayMode ?? 'large';
  if (display === 'inlineLarge' && transition === 'native' && (props.onBack || props.leadingItems?.length)) {
    display = 'large';
    if (__DEV__) navigationWarning('Native inlineLarge can hide leading actions on older iOS. Falling back to large; morph preserves these actions.');
  }
  const bounded = (value: number | undefined, fallback: number) => Number.isFinite(value) ? Math.max(10, Math.min(64, value!)) : fallback;
  return {titleDisplayMode: display, titleTransition: transition,
    titlePosition: transition === 'morph' ? 'leading' : props.titlePosition ?? 'automatic',
    titleFont: {...props.titleFont, compactSize: bounded(props.titleFont?.compactSize, 17), largeSize: bounded(props.titleFont?.largeSize, 34)}};
}
export function navigationColor(value: GlassSchemeColor | undefined, dark: boolean) {
  return iconColor(value && typeof value === 'object' && 'light' in value ? value[dark ? 'dark' : 'light'] : value);
}
/** Native hard-band config: `system` keeps UIKit's hard edge; fields are clamped, colours resolved. */
export function navigationBand(band: GlassHeaderBand | 'system' | undefined, dark: boolean) {
  if (band === 'system') return {system: true};
  const unit = (value: number | undefined) => value === undefined || !Number.isFinite(value) ? undefined : Math.min(1, Math.max(0, value));
  return {color: navigationColor(band?.color, dark), opacity: unit(band?.opacity), blur: unit(band?.blur), progressive: band?.progressive,
    separator: band?.separator === false ? undefined : navigationColor(band?.separator, dark), hideSeparator: band?.separator === false};
}
