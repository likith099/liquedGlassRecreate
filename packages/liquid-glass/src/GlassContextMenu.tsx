import React, {useEffect, useRef} from 'react';
import NativeMenu from './specs/ALGMenuNativeComponent';
import {enabledMenuAction, menuStyleJSON, validateMenuItems} from './menuTree';
import type {GlassContextMenuProps} from './types';
import FallbackContextMenu from './fallback/GlassContextMenu';

/** Native long-press menu with the original content retained as its preview. */
export default function GlassContextMenu({children, items, onAction, disabled = false,
  actionTiming = 'selection', colorScheme = 'system',
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
  const interaction = useRef<{open: boolean; pending?: string}>({open: false});
  useEffect(() => () => { interaction.current = {open: false}; }, []);
  const deliver = (id: string) => {
    const item = enabledMenuAction(items, id);
    if (!disabled && item) onAction(item.id);
  };
  const choose = (id: string) => {
    if (disabled || !enabledMenuAction(items, id)) return;
    // Accessibility actions have no presented menu and must not wait for a close that never comes.
    if (actionTiming === 'afterClose' && interaction.current.open) interaction.current.pending = id;
    else deliver(id);
  };
  const opened = () => {
    interaction.current = {open: true};
    onOpen?.();
  };
  const closed = () => {
    const pending = interaction.current.pending;
    interaction.current = {open: false};
    onClose?.();
    if (pending !== undefined) deliver(pending);
  };
  if (forceFallback) return <FallbackContextMenu {...props} items={items} onAction={choose} onOpen={opened} onClose={closed}
    disabled={disabled} colorScheme={colorScheme} accessibilityLabel={accessibilityLabel} accessibilityHint={accessibilityHint}
    testID={testID}>{children}</FallbackContextMenu>;
  return <NativeMenu {...props} title="" contextMenu itemsJSON={JSON.stringify(items)} menuStyleJSON={menuStyleJSON(androidMenuStyle)}
    disabled={disabled || items.length === 0} colorScheme={colorScheme} previewCornerRadius={previewCornerRadius} menuPlacement={menuPlacement}
    previewCornerTopLeft={previewCornerRadii?.topLeft ?? -1} previewCornerTopRight={previewCornerRadii?.topRight ?? -1}
    previewCornerBottomLeft={previewCornerRadii?.bottomLeft ?? -1} previewCornerBottomRight={previewCornerRadii?.bottomRight ?? -1}
    onMenuOpen={opened} onMenuClose={closed}
    controlLabel={accessibilityLabel} controlHint={accessibilityHint} controlTestID={testID}
    onMenuAction={event => choose(event.nativeEvent.id)}>{children}</NativeMenu>;
}
