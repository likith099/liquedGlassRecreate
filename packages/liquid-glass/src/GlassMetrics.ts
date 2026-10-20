export type GlassControlSize = 'mini' | 'small' | 'regular' | 'large' | 'extraLarge';
const pageMargin = (width: number) => width >= 414 ? 20 : 16;
/** Package layout metrics in points/dp, not a promise about UIKit's intrinsic button sizes. */
export const GlassMetrics = Object.freeze({
  control: Object.freeze({mini: 28, small: 36, regular: 44, large: 50, extraLarge: 56}),
  pill: Object.freeze({height: 42, horizontalPadding: 15, gap: 10, iconCapsuleWidth: 49}),
  group: Object.freeze({endPadding: 14, glyphSpacing: 35}),
  header: Object.freeze({inset: pageMargin, gapBetweenShapes: 12}),
  pageMargin,
  // The back preset reproduces UIKit's back indicator: 17 pt semibold at large scale (measured
  // against UIKit's own back button, ink 11.0 × 18.7 pt).
  symbol: Object.freeze({barItemPointSize: 17, backPointSize: 17}),
});
