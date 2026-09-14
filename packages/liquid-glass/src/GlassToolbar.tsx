import React from 'react';
import NativeMenu from './specs/ALGMenuNativeComponent';
import {enabledMenuAction, validateMenuItems} from './menuTree';
import type {GlassToolbarProps} from './types';

export default function GlassToolbar({items, onAction, disabled = false, maxVisibleItems = 3,
  mergingEnabled = false, tintColor, forceFallback = false, accessibilityLabel, accessibilityHint,
  accessibilityState: _state, testID, style, ...props}: GlassToolbarProps) {
  validateMenuItems(items);
  if (!Number.isInteger(maxVisibleItems) || maxVisibleItems < 0 || maxVisibleItems > 256) {
    throw new Error('GlassToolbar maxVisibleItems must be an integer from 0 to 256.');
  }
  return <NativeMenu {...props} accessible={false} toolbar title="" itemsJSON={JSON.stringify(items)}
    style={[{height: 64, minWidth: 64}, style]} disabled={disabled || items.length === 0}
    maxVisibleItems={maxVisibleItems} mergingEnabled={mergingEnabled}
    glassTint={tintColor} forceFallback={forceFallback} controlLabel={accessibilityLabel}
    controlHint={accessibilityHint} controlTestID={testID}
    onMenuAction={event => {
      const item = enabledMenuAction(items, event.nativeEvent.id);
      if (!disabled && item) onAction(item.id);
    }} />;
}
