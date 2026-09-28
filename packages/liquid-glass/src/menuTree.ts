import {processColor, type ColorValue} from 'react-native';
import type {GlassMenuElement, GlassMenuItem, GlassMenuStyle, GlassSchemeColor} from './types';

/** Bounded recursive contract shared by menu buttons and toolbar menus. */
export function validateMenuItems(items: readonly GlassMenuElement[]) {
  const ids = new Set<string>();
  const visit = (elements: readonly GlassMenuElement[], depth: number, submenuDepth: number) => {
    if (depth > 8) throw new Error('Menus support at most 8 levels.');
    for (const item of elements) {
      if (!item.id.trim() || (item.kind !== 'section' && !item.title.trim())) {
        throw new Error('Menu IDs and action/submenu titles must be nonempty.');
      }
      if (ids.has(item.id)) throw new Error('Menu IDs must be unique throughout the tree.');
      ids.add(item.id);
      if (ids.size > 256) throw new Error('Menus support at most 256 elements.');
      if (item.kind === 'section' || item.kind === 'submenu') {
        if (!item.items.length) throw new Error('Menu groups must contain items.');
        const nextSubmenuDepth = submenuDepth + (item.kind === 'submenu' ? 1 : 0);
        if (nextSubmenuDepth > 1) throw new Error('Menus support one submenu level across platforms.');
        visit(item.items, depth + 1, nextSubmenuDepth);
      }
    }
  };
  visit(items, 1, 0);
}

/** Only enabled leaves can emit actions; a disabled submenu blocks all descendants. */
export function enabledMenuAction(items: readonly GlassMenuElement[], id: string): GlassMenuItem | undefined {
  for (const item of items) {
    if (item.kind === 'section' || item.kind === 'submenu') {
      if (item.kind === 'submenu' && item.disabled) continue;
      const action = enabledMenuAction(item.items, id);
      if (action) return action;
    } else if (item.id === id && !item.disabled) return item;
  }
}

/** One static colour as ARGB, for native code reading JSON. */
function staticMenuColor(color: ColorValue, field: string): number {
  const processed = processColor(color);
  if (typeof processed !== 'number') throw new Error(`androidMenuStyle.${field} must be a static colour, not a platform or dynamic colour.`);
  return processed;
}
function schemeColor(color: GlassSchemeColor | undefined, field: string): {light: number; dark: number} | undefined {
  if (color === undefined) return undefined;
  if (typeof color === 'object' && color !== null && 'light' in color && 'dark' in color) {
    return {light: staticMenuColor(color.light, field), dark: staticMenuColor(color.dark, field)};
  }
  const value = staticMenuColor(color as ColorValue, field);
  return {light: value, dark: value};
}
/** The Android menu popup style as native code reads it; empty when unset. */
export function menuStyleJSON(style: GlassMenuStyle | undefined): string {
  if (!style) return '';
  if (style.cornerRadius !== undefined && !(Number.isFinite(style.cornerRadius) && style.cornerRadius >= 0)) {
    throw new Error('androidMenuStyle.cornerRadius must be a finite, nonnegative number.');
  }
  return JSON.stringify({cornerRadius: style.cornerRadius,
    backgroundColor: schemeColor(style.backgroundColor, 'backgroundColor'),
    textColor: schemeColor(style.textColor, 'textColor'),
    iconColor: schemeColor(style.iconColor, 'iconColor'),
    destructiveColor: schemeColor(style.destructiveColor, 'destructiveColor')});
}
