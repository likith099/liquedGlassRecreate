/** Public ref adapters shared by navigation and standalone edges. No assumptions about list internals. */
export function resolveScrollTarget(value: unknown): unknown {
  let target = value;
  const seen = new Set<unknown>();
  while (target && !seen.has(target)) {
    seen.add(target);
    const ref = target as {getNativeScrollRef?: () => unknown; getScrollResponder?: () => unknown};
    const next = ref.getNativeScrollRef?.() ?? ref.getScrollResponder?.();
    if (!next && (ref.getNativeScrollRef || ref.getScrollResponder)) return null;
    if (!next || next === target) break;
    target = next;
  }
  return target;
}
export function scrollTargetToTop(value: unknown, animated: boolean) {
  const ref = value as {scrollToOffset?: (options: {offset: number; animated: boolean}) => void} | null;
  if (ref?.scrollToOffset) { ref.scrollToOffset({offset: 0, animated}); return; }
  const target = resolveScrollTarget(value) as {scrollTo?: (options: {y: number; animated: boolean}) => void} | null;
  target?.scrollTo?.({y: 0, animated});
}
