import React from 'react';
import {useWindowDimensions} from 'react-native';
import adaptiveHeight from './adaptiveHeight';
import NativeMenu from './specs/ALGMenuNativeComponent';
import type {GlassMenuButtonProps, GlassMenuElement} from './types';
import {enabledMenuAction, menuStyleJSON, validateMenuItems} from './menuTree';
import {useMenuHandle} from './menuHandle';

export function validateMenu(title: string, items: readonly GlassMenuElement[]) {
  if (!title.trim()) throw new Error('GlassMenuButton title must be nonempty.');
  validateMenuItems(items);
}

export default function GlassMenuButton({ref, title, items, onAction, onOpen, onClose, systemImage, disabled = false,
  tintColor, forceFallback = false, androidMenuStyle, accessibilityLabel, accessibilityHint,
  accessibilityState: _state, testID, style, ...props}: GlassMenuButtonProps) {
  const {fontScale} = useWindowDimensions();
  const host = useMenuHandle(ref);
  validateMenu(title, items);
  return <NativeMenu {...props} ref={host} accessible={false} style={[{height: adaptiveHeight(64, 20, fontScale), minWidth: 120}, style]}
    title={title} systemImage={systemImage} itemsJSON={JSON.stringify(items)} menuStyleJSON={menuStyleJSON(androidMenuStyle)}
    disabled={disabled || items.length === 0} glassTint={tintColor} forceFallback={forceFallback}
    controlLabel={accessibilityLabel ?? title} controlHint={accessibilityHint} controlTestID={testID}
    onMenuAction={event => {
      const item = enabledMenuAction(items, event.nativeEvent.id);
      if (!disabled && item) onAction(item.id);
    }}
    onMenuOpen={onOpen && (() => onOpen())} onMenuClose={onClose && (() => onClose())} />;
}
