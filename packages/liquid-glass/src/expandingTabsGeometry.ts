/**
 * Geometry of one expanding pill, driven by its progress `p` (0 idle, 1 selected). The iOS
 * implementation mirrors these formulas in Swift; the Android fallback uses them directly.
 * Every function clamps `p`, because a spring can overshoot.
 */
export const pillMetrics = {
  /** Icon box, a square. */
  icon: 20,
  /** The single control for the pill's height: icon plus twice this. */
  paddingVertical: 8,
  /** Horizontal padding of an idle pill; half of the open padding keeps idle pills compact. */
  paddingClosed: 15,
  paddingOpen: 30,
  /** Icon to label. */
  gap: 8,
  /** Between pills. */
  spacing: 8,
  /** Minimum touch target height; the difference to the pill height becomes vertical hit slop. */
  touchTarget: 44,
} as const;
/** The metrics with any value, for example an icon scaled with the text size. */
export type PillMetrics = {[Key in keyof typeof pillMetrics]: number};

export const clampProgress = (p: number) => Math.min(1, Math.max(0, p));
export const collapsedWidth = (m: PillMetrics = pillMetrics) => m.icon + 2 * m.paddingClosed;
export const expandedWidth = (labelWidth: number, m: PillMetrics = pillMetrics) =>
  Math.max(collapsedWidth(m), 2 * m.paddingOpen + m.icon + m.gap + labelWidth);
/** Linear in p between the collapsed and expanded widths. */
export const pillWidth = (p: number, labelWidth: number, m: PillMetrics = pillMetrics) =>
  collapsedWidth(m) + (expandedWidth(labelWidth, m) - collapsedWidth(m)) * clampProgress(p);
/** The label is revealed by a clip box that grows in step with the pill. */
export const labelBoxWidth = (p: number, labelWidth: number) => labelWidth * clampProgress(p);
/** The icon–label gap grows too, so an idle pill centres its icon alone. */
export const labelGap = (p: number, m: PillMetrics = pillMetrics) => m.gap * clampProgress(p);
/** 0 until halfway, then linear to 1: text never shows squeezed into a pill still too narrow. */
export const labelOpacity = (p: number) => clampProgress((clampProgress(p) - 0.5) / 0.5);
/** Content width; never exceeds pillWidth, so the centred icon never jumps. */
export const contentWidth = (p: number, labelWidth: number, m: PillMetrics = pillMetrics) =>
  m.icon + labelGap(p, m) + labelBoxWidth(p, labelWidth);
