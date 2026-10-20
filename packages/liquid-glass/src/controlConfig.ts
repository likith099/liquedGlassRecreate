import {nativeIcon, nativeMenuItems, iconColor} from './iconOptions';
import {validateMenuItems, enabledMenuAction} from './menuTree';
import type {GlassControlItem, GlassIconGroupProps} from './types';
export function controlItems(items: readonly GlassControlItem[], defaults?: GlassIconGroupProps['symbol']) {
  const ids = new Set<string>();
  return items.filter(item => {
    if (!item.id.trim() || ids.has(item.id)) {
      if (__DEV__) throw new Error('Control IDs must be nonempty and unique.');
      console.warn('Invalid duplicate or blank glass control ID dropped.'); return false;
    }
    ids.add(item.id); return true;
  }).map(item => {
    if (!item.accessibilityLabel.trim()) throw new Error('Controls require an accessibilityLabel.');
    if (item.menu) validateMenuItems(item.menu.items);
    const symbol = typeof item.symbol === 'string' ? {name: item.symbol} : item.symbol;
    return {id: item.id, label: item.accessibilityLabel, testID: item.testID, disabled: item.disabled,
      tint: iconColor(item.tintColor), androidIcon: typeof item.androidIcon === 'string' ? item.androidIcon : undefined,
      ...nativeIcon({...item, symbol: symbol ? {...defaults, ...symbol} : undefined}),
      menu: item.menu ? nativeMenuItems(item.menu.items) : undefined};
  });
}
export function controlAction(items: readonly GlassControlItem[], id: string, action: string, onPress?: (id: string) => void) {
  const item = items.find(entry => entry.id === id);
  if (!item || item.disabled) return;
  if (action && item.menu) {
    if (enabledMenuAction(item.menu.items, action)) item.menu.onAction(action);
  } else if (!item.menu) onPress?.(id);
}
