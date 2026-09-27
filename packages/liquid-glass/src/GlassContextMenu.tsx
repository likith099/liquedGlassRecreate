import React from 'react';
import NativeMenu from './specs/ALGMenuNativeComponent';
import {enabledMenuAction, validateMenuItems} from './menuTree';
import type {GlassContextMenuProps} from './types';
import FallbackContextMenu from './fallback/GlassContextMenu';

/** Native long-press menu with the original content retained as its preview. */
export default function GlassContextMenu({children, items, onAction, disabled = false,
  previewCornerRadius = 16, forceFallback = false, accessibilityLabel, accessibilityHint, testID,
  ...props}: GlassContextMenuProps) {
  validateMenuItems(items);
  if (!Number.isFinite(previewCornerRadius) || previewCornerRadius < 0) {
    throw new Error('GlassContextMenu previewCornerRadius must be finite and nonnegative.');
  }
  if (forceFallback) return <FallbackContextMenu {...props} items={items} onAction={onAction}
    disabled={disabled} accessibilityLabel={accessibilityLabel} accessibilityHint={accessibilityHint}
    testID={testID}>{children}</FallbackContextMenu>;
  return <NativeMenu {...props} title="" contextMenu itemsJSON={JSON.stringify(items)}
    disabled={disabled || items.length === 0} previewCornerRadius={previewCornerRadius}
    controlLabel={accessibilityLabel} controlHint={accessibilityHint} controlTestID={testID}
    onMenuAction={event => {
      const item = enabledMenuAction(items, event.nativeEvent.id);
      if (!disabled && item) onAction(item.id);
    }}>{children}</NativeMenu>;
}
