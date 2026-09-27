import {clampProgress, collapsedWidth, contentWidth, expandedWidth, labelBoxWidth, labelGap, labelOpacity,
  pillMetrics, pillWidth} from '../../packages/liquid-glass/src/expandingTabsGeometry';

test('collapsed and expanded widths follow the metrics', () => {
  expect(collapsedWidth()).toBe(20 + 2 * 15);
  expect(expandedWidth(80)).toBe(2 * 30 + 20 + 8 + 80);
  // A missing or tiny label never makes the open pill narrower than the idle one.
  expect(expandedWidth(0)).toBe(Math.max(collapsedWidth(), 2 * 30 + 20 + 8));
});

test('width is linear in progress, and progress is clamped', () => {
  const at = (p: number) => pillWidth(p, 80);
  expect(at(0)).toBe(collapsedWidth());
  expect(at(1)).toBe(expandedWidth(80));
  expect(at(0.5)).toBeCloseTo((at(0) + at(1)) / 2);
  expect(at(0.25)).toBeCloseTo(at(0) + (at(1) - at(0)) * 0.25);
  expect(at(1.2)).toBe(at(1));
  expect(at(-0.1)).toBe(at(0));
  expect(clampProgress(3)).toBe(1);
});

test('the label box and gap grow in step, and the label waits until halfway', () => {
  expect(labelBoxWidth(0.5, 80)).toBe(40);
  expect(labelGap(0.5)).toBe(4);
  expect(labelOpacity(0)).toBe(0);
  expect(labelOpacity(0.5)).toBe(0);
  expect(labelOpacity(0.75)).toBeCloseTo(0.5);
  expect(labelOpacity(1)).toBe(1);
  expect(labelOpacity(1.3)).toBe(1);
});

test('content never outgrows the pill, for any label width and progress', () => {
  for (let label = 0; label <= 160; label += 8) {
    for (let step = 0; step <= 20; step++) {
      const p = step / 20;
      expect(contentWidth(p, label)).toBeLessThanOrEqual(pillWidth(p, label) + 1e-9);
    }
  }
  expect(pillMetrics.paddingClosed * 2).toBe(pillMetrics.paddingOpen);
});
