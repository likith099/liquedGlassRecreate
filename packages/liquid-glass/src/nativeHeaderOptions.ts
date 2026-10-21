import {badgeText, normalizeBadge} from './iconOptions';
import type {GlassMenuElement} from './types';
import type {GlassHeaderItem} from './GlassHeaderHost';

/**
 * iOS 26: header controls as UIKit bar button items in the stack's own navigation bar
 * (React Navigation native-stack `unstable_headerLeftItems` / `unstable_headerRightItems`, backed by
 * react-native-screens 4.2x UIBarButtonItems).
 * UIKit then performs its own bar-item morph between screens — the outgoing content blurs out,
 * the glass reshapes, the incoming content focuses in — scrubs it with the swipe back and
 * moves VoiceOver focus. Plain data: no runtime dependency on a navigator.
 */
export interface GlassNativeHeaderOptions {
  leading?: readonly GlassHeaderItem[];
  trailing?: readonly GlassHeaderItem[];
  /** Title shown in the bar. Defaults to none: screens usually draw their own title. */
  title?: string;
}

const symbolName = (symbol: unknown) => typeof symbol === 'string' ? symbol : (symbol as {name?: string} | undefined)?.name;

function menuItems(items: readonly GlassMenuElement[], onAction: (id: string) => void): object[] {
  return items.map(item => {
    if (item.kind === 'section' || item.kind === 'submenu') {
      const icon = item.kind === 'submenu' ? symbolName(item.symbol) ?? item.systemImage : undefined;
      return {type: 'submenu', label: item.title, inline: item.kind === 'section',
        ...(icon ? {icon: {type: 'sfSymbol', name: icon}} : {}),
        multiselectable: !item.singleSelection, items: menuItems(item.items, onAction)};
    }
    const icon = symbolName(item.symbol) ?? item.systemImage;
    return {type: 'action', label: item.title, description: item.subtitle, onPress: () => onAction(item.id),
      ...(icon ? {icon: {type: 'sfSymbol', name: icon}} : {}), disabled: item.disabled, destructive: item.destructive,
      state: item.checked ? 'on' : undefined, keepsMenuPresented: item.keepsMenuPresented};
  });
}

function barItem(item: GlassHeaderItem): object {
  const badge = badgeText(normalizeBadge(item.badge));
  const shared = {
    accessibilityLabel: item.accessibilityLabel, identifier: item.testID ?? item.slot, disabled: item.disabled,
    ...(badge !== undefined ? {badge: {value: badge, style: {backgroundColor: item.badgeColor, color: item.badgeTextColor}}} : {}),
    // `label` is required; an icon item shows its icon and uses the label for accessibility/overflow.
    label: item.kind === 'title' ? item.title : item.accessibilityLabel,
    ...(item.kind === 'title' ? {} : {icon: {type: 'sfSymbol', name: item.kind === 'symbol' ? symbolName(item.symbol) ?? 'circle' : 'chevron.backward'}}),
  };
  if (item.menu) return {type: 'menu', ...shared, menu: {multiselectable: true, items: menuItems(item.menu.items, item.menu.onAction)}};
  return {type: 'button', ...shared, onPress: () => item.onPress?.()};
}

/** Native-stack screen options for `GlassHeaderHost` items on iOS 26. `kind: 'back'` uses UIKit's back button. */
// Typed loosely so it fits native-stack's `options` without a navigator type dependency.
export function glassHeaderOptions({leading = [], trailing = [], title}: GlassNativeHeaderOptions): Record<string, any> {
  const back = leading.some(item => item.kind === 'back');
  const left = leading.filter(item => item.kind !== 'back').map(barItem);
  const right = trailing.map(barItem);
  return {
    headerShown: true, headerTransparent: true, headerShadowVisible: false, headerLargeTitle: false,
    headerTitle: title ?? '', headerBackVisible: back, headerBackButtonDisplayMode: 'minimal' as const,
    unstable_headerLeftItems: () => left, unstable_headerRightItems: () => right,
  };
}
