import React from 'react';
import NativeMenu from './specs/ALGMenuNativeComponent';
import type {GlassMenuButtonProps, GlassMenuElement} from './types';
import {enabledMenuAction, validateMenuItems} from './menuTree';

export function validateMenu(title: string, items: readonly GlassMenuElement[]) {
  if (!title.trim()) throw new Error('GlassMenuButton title must be nonempty.');
  validateMenuItems(items);
}

export default function GlassMenuButton({title, items, onAction, systemImage, disabled = false,
  tintColor, forceFallback = false, accessibilityLabel, accessibilityHint,
  accessibilityState: _state, testID, style, ...props}: GlassMenuButtonProps) {
  validateMenu(title, items);
  return <NativeMenu {...props} accessible={false} style={[{height: 64, minWidth: 120}, style]}
    title={title} systemImage={systemImage} itemsJSON={JSON.stringify(items)}
    disabled={disabled || items.length === 0} glassTint={tintColor} forceFallback={forceFallback}
    controlLabel={accessibilityLabel ?? title} controlHint={accessibilityHint} controlTestID={testID}
    onMenuAction={event => {
      const item = enabledMenuAction(items, event.nativeEvent.id);
      if (!disabled && item) onAction(item.id);
    }} />;
}
