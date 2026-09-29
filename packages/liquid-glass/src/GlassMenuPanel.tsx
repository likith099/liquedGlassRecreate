import React, {useImperativeHandle, useRef} from 'react';
import {PixelRatio, Platform, useWindowDimensions} from 'react-native';
import NativeMenuPanel, {Commands} from './specs/ALGMenuPanelNativeComponent';
import {enabledMenuAction, menuStyleJSON, validateMenuItems} from './menuTree';
import type {GlassMenuElement, GlassMenuPanelHandle, GlassMenuPanelMeasureOptions, GlassMenuPanelProps} from './types';

/**
 * Row metrics of the native panel. iOS values are measured from UIKit's own menu on iOS 26
 * (ALGMenuPanelView.swift, PanelMetrics); Android's from the package's menu popup (ALGMenuPanelView.kt).
 * Change them together with the native code: the app lays out around the measured height.
 */
const metrics = Platform.OS === 'ios'
  ? {width: 250, paddingVertical: 9, row: 40, separator: 21, title: 30}
  : {width: 250, paddingVertical: 8, row: 52, separator: 17, title: 36};

type Line = 'row' | 'title' | 'separator';
/** Sections become an optional title between separators; the native views lay out the same lines. */
function lines(items: readonly GlassMenuElement[]): Line[] {
  const out: Line[] = [];
  for (const item of items) {
    if (item.kind === 'section') {
      if (out.length && out[out.length - 1] !== 'separator') out.push('separator');
      if (item.title) out.push('title');
      out.push(...lines(item.items));
      out.push('separator');
    } else out.push('row');
  }
  while (out[out.length - 1] === 'separator') out.pop();
  return out;
}

function validatePanel(items: readonly GlassMenuElement[]) {
  validateMenuItems(items);
  const visit = (elements: readonly GlassMenuElement[]) => {
    for (const item of elements) {
      if (item.kind === 'submenu') throw new Error('GlassMenuPanel does not support submenus; use sections.');
      if (item.kind === 'section') visit(item.items);
    }
  };
  visit(items);
}

const resolveWidth = (width: number | 'intrinsic' | undefined) => width === undefined || width === 'intrinsic' ? metrics.width : width;

/**
 * The panel's height for these items, before it is drawn: the app can place the menu, and move the
 * content it belongs to, in the same frame the panel first appears.
 */
function measure(items: readonly GlassMenuElement[], options: GlassMenuPanelMeasureOptions = {}) {
  const scale = Math.max(1, options.fontScale ?? PixelRatio.getFontScale());
  let height = 2 * metrics.paddingVertical;
  for (const line of lines(items)) {
    height += line === 'row' ? Math.round(metrics.row * scale)
      : line === 'title' ? Math.round(metrics.title * scale) : metrics.separator;
  }
  return options.maxHeight !== undefined ? Math.min(height, options.maxHeight) : height;
}

/**
 * The system menu as a view you place. It is drawn natively (UIKit rows on the iOS 26 glass
 * platter, the system material below 26, the package's Material popup look on Android), laid out
 * by React Native like any view and never presented by the system: put it under a message, above
 * it, or anywhere else. Touching a row highlights it, sliding moves the highlight with a selection
 * tick per row, and lifting on an enabled row calls onAction. Inside a GlassLongPress, the finger
 * that pressed can slide straight onto a row.
 */
function GlassMenuPanel({ref, items, onAction, onCancelTouch, onRequestClose, onDismissed, width, maxHeight,
  colorScheme = 'system', disabled = false, appearFrom = 'none', autoFocus = false, accessibilityModal = false,
  androidMenuStyle, testID, style, ...props}: GlassMenuPanelProps) {
  validatePanel(items);
  const resolvedWidth = resolveWidth(width);
  if (!(Number.isFinite(resolvedWidth) && resolvedWidth > 0)) throw new Error('GlassMenuPanel width must be a positive number.');
  if (maxHeight !== undefined && !(Number.isFinite(maxHeight) && maxHeight > 0)) {
    throw new Error('GlassMenuPanel maxHeight must be a positive number.');
  }
  const {fontScale} = useWindowDimensions();
  const host = useRef<React.ComponentRef<typeof NativeMenuPanel>>(null);
  useImperativeHandle(ref, () => ({
    dismiss: () => { if (host.current) Commands.dismiss(host.current); },
    measure: callback => host.current?.measure(callback),
    measureInWindow: callback => host.current?.measureInWindow(callback),
    measureLayout: (relativeTo, onSuccess, onFail) => host.current?.measureLayout(relativeTo, onSuccess, onFail),
  }), []);
  return <NativeMenuPanel {...props} ref={host} accessibilityRole="menu"
    style={[{width: resolvedWidth, height: measure(items, {width, maxHeight, fontScale})}, style]}
    itemsJSON={JSON.stringify(items)} fontScale={fontScale} colorScheme={colorScheme} disabled={disabled}
    appearFrom={appearFrom} autoFocus={autoFocus} menuModal={accessibilityModal}
    menuStyleJSON={menuStyleJSON(androidMenuStyle)} controlTestID={testID}
    onMenuAction={event => {
      // Only enabled leaves of the current items act.
      const item = enabledMenuAction(items, event.nativeEvent.id);
      if (!disabled && item) onAction(item.id);
    }}
    onCancelTouch={onCancelTouch && (() => onCancelTouch())}
    onRequestClose={onRequestClose && (() => onRequestClose())}
    onDismissed={onDismissed && (() => onDismissed())} />;
}
GlassMenuPanel.measure = measure;
export default GlassMenuPanel;
