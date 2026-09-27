import React from 'react';
import NativeMenu from './specs/ALGMenuNativeComponent';
import {enabledMenuAction, validateMenuItems} from './menuTree';
import {useMenuHandle} from './menuHandle';
import type {GlassIconButtonProps} from './types';

export function validateIconButton({systemImage, accessibilityLabel, size, symbolPointSize, onPress, menu}:
  Pick<GlassIconButtonProps, 'systemImage' | 'accessibilityLabel' | 'size' | 'symbolPointSize' | 'onPress' | 'menu'>) {
  if (!systemImage.trim()) throw new Error('GlassIconButton systemImage must be nonempty.');
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
 * Android draws an oval surface with a ripple and opens a PopupMenu.
 */
export default function GlassIconButton({ref, systemImage, accessibilityLabel, androidIcon, size = 44,
  symbolPointSize, colorScheme = 'system', variant = 'regular', tintColor, disabled = false,
  forceFallback = false, onPress, menu, onOpen, onClose, accessibilityHint, accessibilityState: _state, testID, style, ...props}: GlassIconButtonProps) {
  const host = useMenuHandle(ref);
  validateIconButton({systemImage, accessibilityLabel, size, symbolPointSize, onPress, menu});
  const items = menu?.items ?? [];
  return <NativeMenu {...props} ref={host} accessible={false} style={[{width: size, height: size}, style]}
    iconMode title="" systemImage={systemImage} androidIcon={androidIcon}
    symbolPointSize={symbolPointSize ?? Math.round(size * 0.4)} colorScheme={colorScheme} iconVariant={variant}
    itemsJSON={JSON.stringify(items)} disabled={disabled} glassTint={tintColor} forceFallback={forceFallback}
    controlLabel={accessibilityLabel} controlHint={accessibilityHint} controlTestID={testID}
    onButtonPress={() => { if (!disabled && !menu) onPress?.(); }}
    onMenuAction={event => {
      const item = enabledMenuAction(items, event.nativeEvent.id);
      if (!disabled && item) menu?.onAction(item.id);
    }}
    onMenuOpen={onOpen && (() => onOpen())} onMenuClose={onClose && (() => onClose())} />;
}
