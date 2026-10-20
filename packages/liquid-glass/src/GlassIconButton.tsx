import React from 'react';
import {Platform, View} from 'react-native';
import {GlassMetrics} from './GlassMetrics';
import {nativeIcon, nativeMenuItems, resolveSymbol} from './iconOptions';
import NativeMenu from './specs/ALGMenuNativeComponent';
import {enabledMenuAction, menuStyleJSON, validateMenuItems} from './menuTree';
import {useMenuHandle} from './menuHandle';
import type {GlassIconButtonProps} from './types';

export function validateIconButton({systemImage, accessibilityLabel, size, symbolPointSize, onPress, menu}:
  Pick<GlassIconButtonProps, 'systemImage' | 'accessibilityLabel' | 'size' | 'symbolPointSize' | 'onPress' | 'menu'>) {
  if (!systemImage?.trim()) throw new Error('GlassIconButton systemImage must be nonempty.');
  if (!accessibilityLabel.trim()) throw new Error('GlassIconButton accessibilityLabel must be nonempty.');
  if (size !== undefined && !(Number.isFinite(size) && size > 0)) throw new Error('GlassIconButton size must be a positive number.');
  if (symbolPointSize !== undefined && !(Number.isFinite(symbolPointSize) && symbolPointSize > 0)) {
    throw new Error('GlassIconButton symbolPointSize must be a positive number.');
  }
  if (onPress && menu) throw new Error('GlassIconButton accepts onPress or menu, not both.');
  if (!onPress && !menu) throw new Error('GlassIconButton needs onPress or menu.');
  if (menu) validateMenuItems(menu.items);
}

/**
 * Round icon-only control. UIKit owns the glass, press highlight and menu morph on iOS 26
 * (`UIButton.Configuration.glass()`); older iOS and Reduce Transparency use `.gray()`.
 * Android draws an oval surface with a ripple and opens the package's menu popup.
 */
export default function GlassIconButton({ref, glassID, systemImage, accessibilityLabel, androidIcon, size: explicitSize, controlSize, symbol, contentTransition, pressEffect, image, badge, badgeColor, badgeTextColor, badgeAccessibilityLabel,
  symbolPointSize, material = 'regular', colorScheme = 'system', variant = 'regular', tintColor, disabled = false,
  forceFallback = false, onPress, menu, onOpen, onClose, androidMenuStyle, accessibilityHint, accessibilityState: _state, testID, style, ...props}: GlassIconButtonProps) {
  const host = useMenuHandle(ref);
  const size = explicitSize ?? GlassMetrics.control[controlSize ?? 'regular'];
  const resolved = resolveSymbol(symbol, systemImage, symbolPointSize ?? Math.round(size * 0.4));
  const iconOptionsJSON = JSON.stringify(nativeIcon({symbol, systemImage, symbolPointSize: resolved.pointSize, contentTransition, pressEffect, image, badge, badgeColor, badgeTextColor, badgeAccessibilityLabel}));
  validateIconButton({systemImage: resolved.name || (image ? 'image' : ''), accessibilityLabel, size, symbolPointSize, onPress, menu});
  const items = menu?.items ?? [];
  const native = <NativeMenu {...props} ref={host} accessible={false} style={[{width: size, height: size}, style]}
    nativeID={glassID ? `alg-glass-${glassID}` : props.nativeID} iconMode title="" systemImage={resolved.name} androidIcon={typeof androidIcon === 'string' ? androidIcon : undefined} iconOptionsJSON={iconOptionsJSON} glassMaterial={material}
    symbolPointSize={symbolPointSize ?? Math.round(size * 0.4)} colorScheme={colorScheme} iconVariant={variant}
    itemsJSON={JSON.stringify(nativeMenuItems(items))} menuStyleJSON={menuStyleJSON(androidMenuStyle)} disabled={disabled} glassTint={tintColor} forceFallback={forceFallback}
    controlLabel={accessibilityLabel} controlHint={accessibilityHint} controlTestID={testID}
    onButtonPress={() => { if (!disabled && !menu) onPress?.(); }}
    onMenuAction={event => {
      const item = enabledMenuAction(items, event.nativeEvent.id);
      if (!disabled && item) menu?.onAction(item.id);
    }}
    onMenuOpen={onOpen && (() => onOpen())} onMenuClose={onClose && (() => onClose())} />;
  return Platform.OS === 'android' && androidIcon && typeof androidIcon !== 'string'
    ? <View style={[{width: size, height: size}, style]}>{native}<View pointerEvents="none" accessible={false}
        style={{position: 'absolute', inset: 0, alignItems: 'center', justifyContent: 'center'}}>{androidIcon}</View></View>
    : native;
}
