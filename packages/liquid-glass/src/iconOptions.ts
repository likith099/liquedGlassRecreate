import {Image, processColor, type ColorValue} from 'react-native';
import type {GlassIconOptions, GlassSymbol, GlassControlBadge, GlassMenuElement} from './types';

export function iconColor(value?: ColorValue): number | undefined {
  if (value === undefined) return undefined;
  const result = processColor(value);
  if (typeof result !== 'number') throw new Error('Icon palette and badge colours must be static colours.');
  return result;
}
export function resolveSymbol(symbol?: GlassSymbol, systemImage?: string, pointSize?: number) {
  const options = typeof symbol === 'string' ? {name: symbol} : symbol;
  const result = {...options, name: options?.name ?? systemImage ?? '', pointSize: options?.pointSize ?? pointSize};
  if (result.pointSize !== undefined && (!Number.isFinite(result.pointSize) || result.pointSize <= 0)) {
    throw new Error('Symbol pointSize must be positive.');
  }
  if (result.variableValue !== undefined && (!Number.isFinite(result.variableValue) || result.variableValue < 0 || result.variableValue > 1)) {
    throw new Error('Symbol variableValue must be between 0 and 1.');
  }
  return {...result, paletteColors: result.paletteColors?.map(iconColor)};
}
/** Accepts the shorthand forms (a number for a count, 'dot') alongside GlassControlBadge. */
export function normalizeBadge(badge?: number | 'dot' | GlassControlBadge | null): GlassControlBadge | null | undefined {
  if (badge === undefined || badge === null) return badge;
  if (typeof badge === 'number') return {count: badge};
  if (badge === 'dot') return {indicator: true};
  return badge;
}
/** The drawn badge: a capped count, the text, or '' for a dot. */
export function badgeText(badge?: GlassControlBadge | null): string | undefined {
  if (!badge) return undefined;
  if ('count' in badge) {
    if (!Number.isInteger(badge.count) || badge.count < 0) throw new Error('Badge count must be a nonnegative integer.');
    return badge.count > 99 ? '99+' : String(badge.count);
  }
  if ('text' in badge) {
    if (typeof badge.text !== 'string' || !badge.text.trim()) throw new Error('Badge text must be a nonempty string; use {indicator: true} for a dot.');
    return badge.text;
  }
  return '';
}
/**
 * What assistive technology reads for the badge. The defaults are English; apps that ship other
 * languages pass `badgeAccessibilityLabel`.
 */
export function badgeSpoken(badge?: GlassControlBadge | null, override?: string): string | undefined {
  const text = badgeText(badge);
  if (text === undefined) return undefined;
  if (override !== undefined && override.trim()) return override;
  if (badge && 'count' in badge) return `${text} new`;
  return text || 'New';
}
export function nativeIcon(options: Partial<GlassIconOptions> & {systemImage?: string; symbolPointSize?: number;
  badge?: GlassControlBadge | null; badgeColor?: ColorValue; badgeTextColor?: ColorValue; badgeAccessibilityLabel?: string}): {
  symbol: ReturnType<typeof resolveSymbol>;
  imageSource?: {uri: string; width?: number; height?: number; scale?: number};
  contentTransition?: GlassIconOptions['contentTransition'];
  pressEffect?: GlassIconOptions['pressEffect'];
  badge?: string; badgeColor?: number; badgeTextColor?: number; badgeAccessibility?: string;
} {
  return {symbol: resolveSymbol(options.symbol, options.systemImage, options.symbolPointSize),
    imageSource: options.image === undefined ? undefined : Image.resolveAssetSource(options.image),
    contentTransition: options.contentTransition, pressEffect: options.pressEffect,
    badge: badgeText(options.badge), badgeColor: iconColor(options.badgeColor),
    badgeTextColor: iconColor(options.badgeTextColor),
    badgeAccessibility: badgeSpoken(options.badge, options.badgeAccessibilityLabel)};
}
const warned = new Set<string>();
function warnMenuRowBadge(id: string) {
  if (!__DEV__ || warned.has(id)) return;
  warned.add(id);
  console.warn(`Glass menu item "${id}" has a badge, but menu rows cannot show badges: Apple's native menus have ` +
    'no row badge and the package keeps Android menus to the same rows. Badges show on toolbar buttons and on ' +
    'the control that opens the menu; put the badge there, or say it in the item title.');
}
/**
 * Menu items for native code. `rows` is false only for a toolbar's own buttons, which draw their
 * badges; every other level is a menu row, where a badge is ignored and a development warning
 * explains why.
 */
export function nativeMenuItems(items: readonly GlassMenuElement[], rows = true): unknown[] {
  return items.map(item => {
    if (rows && 'badge' in item && item.badge) warnMenuRowBadge(item.id);
    return item.kind === 'section' ? {...item, items: nativeMenuItems(item.items, rows)} :
      {...item, ...(item.symbol || item.image || item.badge ? nativeIcon(item) : {}), androidIcon: typeof item.androidIcon === 'string' ? item.androidIcon : undefined,
        ...('items' in item ? {items: nativeMenuItems(item.items, true)} : {})};
  });
}
