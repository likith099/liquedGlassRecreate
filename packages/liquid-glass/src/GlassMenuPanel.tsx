import React, {useImperativeHandle, useRef} from 'react';
import {Platform, View} from 'react-native';
import NativeMenu, {Commands} from './specs/ALGMenuNativeComponent';
import FallbackContextMenu, {type FallbackMenuOpener} from './fallback/GlassContextMenu';
import {enabledMenuAction, menuStyleJSON, validateMenuItems} from './menuTree';
import {measureMenu} from './menuMetrics';
import type {GlassHostRef, GlassMenuPanelProps} from './types';

/** UIKit opens a button's menu from code from iOS 17.4 (performPrimaryAction); Android always can. */
function canOpenNatively() {
  if (Platform.OS === 'android') return true;
  return Platform.OS === 'ios' && parseFloat(String(Platform.Version)) >= 17.4;
}

/**
 * The system menu, opened exactly where the app wants it. The panel is an invisible anchor the app
 * gives the menu's frame with `style`; `open()` presents Apple's own UIMenu (the same native menu as
 * GlassMenuButton), which iOS 26 grows out of the anchor and fits over it whichever way it opens.
 * UIKit draws the menu, its rows, highlight and animation. Android shows the package's menu popup
 * over the anchor's frame. Where iOS cannot open a menu from code (before 17.4), open() shows the
 * plain fallback menu over the anchor.
 */
function GlassMenuPanel({ref, items, onAction, onOpen, onClose, disabled = false,
  forceFallback = false, androidMenuStyle, testID, style, ...props}: GlassMenuPanelProps) {
  validateMenuItems(items);
  const host = useRef<GlassHostRef>(null);
  const fallbackMenu = useRef<FallbackMenuOpener>(null);
  const fallback = forceFallback || !canOpenNatively();
  useImperativeHandle(ref, () => ({
    open: () => {
      if (fallback) fallbackMenu.current?.open();
      else if (host.current) Commands.open(host.current as never);
    },
    measure: callback => host.current?.measure(callback),
    measureInWindow: callback => host.current?.measureInWindow(callback),
    measureLayout: (relativeTo, onSuccess, onFail) => host.current?.measureLayout(relativeTo, onSuccess, onFail),
  }), [fallback]);
  // An anchor with no size gives the menu nothing to attach to.
  const anchorStyle = [{minWidth: 1, minHeight: 1}, style];
  const choose = (id: string) => {
    const item = enabledMenuAction(items, id);
    if (!disabled && item) onAction(item.id);
  };
  if (fallback) {
    return <FallbackContextMenu {...props} openRef={fallbackMenu} coverAnchor items={items}
      onAction={choose} onOpen={onOpen} onClose={onClose} disabled={disabled} testID={testID}
      style={anchorStyle} pointerEvents="none" accessible={false}><View /></FallbackContextMenu>;
  }
  return <NativeMenu {...props} ref={host as never} menuAnchor pointerEvents="none" accessible={false}
    style={anchorStyle} title="" itemsJSON={JSON.stringify(items)} menuStyleJSON={menuStyleJSON(androidMenuStyle)}
    disabled={disabled || items.length === 0} controlTestID={testID}
    onMenuAction={event => choose(event.nativeEvent.id)}
    onMenuOpen={onOpen && (() => onOpen())} onMenuClose={onClose && (() => onClose())} />;
}
/** The platform menu's size for these items before it opens; see menuMetrics.ts. */
GlassMenuPanel.measure = measureMenu;
export default GlassMenuPanel;
