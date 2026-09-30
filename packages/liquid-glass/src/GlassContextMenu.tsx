import React from 'react';
import NativeMenu from './specs/ALGMenuNativeComponent';
import {enabledMenuAction, menuStyleJSON, validateMenuItems} from './menuTree';
import type {GlassContextMenuProps} from './types';
import FallbackContextMenu from './fallback/GlassContextMenu';

/** Native long-press menu with the original content retained as its preview. */
export default function GlassContextMenu({children, items, onAction, disabled = false,
  previewCornerRadius = 16, previewCornerRadii, menuPlacement = 'system', onOpen, onClose, forceFallback = false, androidMenuStyle,
  accessibilityLabel, accessibilityHint, testID,
  ...props}: GlassContextMenuProps) {
  validateMenuItems(items);
  if (!Number.isFinite(previewCornerRadius) || previewCornerRadius < 0) {
    throw new Error('GlassContextMenu previewCornerRadius must be finite and nonnegative.');
  }
  for (const radius of Object.values(previewCornerRadii ?? {})) {
    if (radius !== undefined && !(Number.isFinite(radius) && radius >= 0)) {
      throw new Error('GlassContextMenu previewCornerRadii must be finite and nonnegative.');
    }
  }
  if (forceFallback) return <FallbackContextMenu {...props} items={items} onAction={onAction} onOpen={onOpen} onClose={onClose}
    disabled={disabled} accessibilityLabel={accessibilityLabel} accessibilityHint={accessibilityHint}
    testID={testID}>{children}</FallbackContextMenu>;
  return <NativeMenu {...props} title="" contextMenu itemsJSON={JSON.stringify(items)} menuStyleJSON={menuStyleJSON(androidMenuStyle)}
    disabled={disabled || items.length === 0} previewCornerRadius={previewCornerRadius} menuPlacement={menuPlacement}
    previewCornerTopLeft={previewCornerRadii?.topLeft ?? -1} previewCornerTopRight={previewCornerRadii?.topRight ?? -1}
    previewCornerBottomLeft={previewCornerRadii?.bottomLeft ?? -1} previewCornerBottomRight={previewCornerRadii?.bottomRight ?? -1}
    onMenuOpen={onOpen && (() => onOpen())} onMenuClose={onClose && (() => onClose())}
    controlLabel={accessibilityLabel} controlHint={accessibilityHint} controlTestID={testID}
    onMenuAction={event => {
      const item = enabledMenuAction(items, event.nativeEvent.id);
      if (!disabled && item) onAction(item.id);
    }}>{children}</NativeMenu>;
}
