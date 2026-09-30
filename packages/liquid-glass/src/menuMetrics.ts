import {PixelRatio, Platform} from 'react-native';
import type {GlassMenuElement, GlassMenuPanelMeasureOptions, GlassMenuSize} from './types';

/**
 * The size of the platform's own menu for these items, before it opens, so an app can make room for
 * it and give GlassMenuPanel exactly the menu's frame. iOS values were measured from UIKit's menu on
 * iOS 26.5 (iPhone 17 Pro Max) at every system text size; nothing here draws a menu. Titles are
 * assumed to fit on one line: a title that wraps makes UIKit's menu taller than this. The
 * accessibility-size width (400) was measured on a 440-point-wide phone. A titled section at the very
 * start of a menu is estimated (its header without the separator above it).
 */
type IOSRow = {fontScale: number; row: number; titledSection: number; width: number};
// fontScale is React Native's multiplier for each iOS text size (XS … Accessibility XXXL).
const IOS: IOSRow[] = [
  {fontScale: 0.823, row: 35.667, titledSection: 45.333, width: 250},
  {fontScale: 0.882, row: 38, titledSection: 45.333, width: 250},
  {fontScale: 0.941, row: 40, titledSection: 45.333, width: 250},
  {fontScale: 1, row: 42, titledSection: 49.333, width: 250},
  {fontScale: 1.118, row: 46.333, titledSection: 54.333, width: 250},
  {fontScale: 1.235, row: 50.333, titledSection: 59.667, width: 250},
  {fontScale: 1.353, row: 56.667, titledSection: 64.333, width: 250},
  {fontScale: 1.786, row: 67.333, titledSection: 76, width: 400},
  {fontScale: 2.143, row: 80, titledSection: 86, width: 400},
  {fontScale: 2.643, row: 96.667, titledSection: 102.667, width: 400},
  {fontScale: 3.143, row: 113.667, titledSection: 117, width: 400},
  {fontScale: 3.571, row: 126, titledSection: 132, width: 400},
];
const IOS_PADDING = 10;
const IOS_SEPARATOR = 21;

/** The package's Android menu popup (ALGMenuPopup): 8 dp padding, 52 dp rows, 17 dp dividers, 36 dp titles. */
const ANDROID = {padding: 8, row: 52, separator: 17, title: 36, width: 250};

type Line = 'row' | 'separator' | 'titledSeparator' | 'title';
/** Rows, and what separates sections, in display order (sections are inline; submenus are rows). */
function lines(items: readonly GlassMenuElement[]): Line[] {
  const out: Line[] = [];
  const walk = (elements: readonly GlassMenuElement[]) => {
    for (const item of elements) {
      if (item.kind === 'section') {
        const titled = !!item.title;
        if (out.length && out[out.length - 1] === 'row') out.push(titled ? 'titledSeparator' : 'separator');
        else if (titled) out.push('title');
        walk(item.items);
        if (out.length && out[out.length - 1] === 'row') out.push('separator');
      } else out.push('row');
    }
  };
  walk(items);
  while (out.length && out[out.length - 1] !== 'row') out.pop();
  return out;
}

function iosRow(fontScale: number): IOSRow {
  return IOS.reduce((best, entry) =>
    Math.abs(entry.fontScale - fontScale) < Math.abs(best.fontScale - fontScale) ? entry : best);
}

export function measureMenu(items: readonly GlassMenuElement[], options: GlassMenuPanelMeasureOptions = {}): GlassMenuSize {
  const fontScale = options.fontScale ?? PixelRatio.getFontScale();
  let width: number;
  let height: number;
  if (Platform.OS === 'ios') {
    const metrics = iosRow(fontScale);
    width = metrics.width;
    height = 2 * IOS_PADDING;
    for (const line of lines(items)) {
      if (line === 'row') height += metrics.row;
      else if (line === 'separator') height += IOS_SEPARATOR;
      else if (line === 'titledSeparator') height += metrics.titledSection;
      else height += metrics.titledSection - IOS_SEPARATOR;
    }
  } else {
    const scale = Math.max(1, fontScale);
    width = ANDROID.width;
    height = 2 * ANDROID.padding;
    for (const line of lines(items)) {
      if (line === 'row') height += Math.round(ANDROID.row * scale);
      else if (line === 'separator') height += ANDROID.separator;
      else if (line === 'titledSeparator') height += ANDROID.separator + Math.round(ANDROID.title * scale);
      else height += Math.round(ANDROID.title * scale);
    }
  }
  if (options.maxHeight !== undefined) height = Math.min(height, options.maxHeight);
  return {width, height: Math.round(height * 1000) / 1000};
}
