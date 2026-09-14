import type {GlassTabItem} from './types';
export function validateTabs(items: readonly GlassTabItem[], value: string | null) {
  if (items.length > 5) throw new Error('GlassTabBar supports at most 5 tabs.');
  const ids = new Set<string>();
  for (const item of items) {
    if (!item.id.trim() || !item.title.trim()) throw new Error('Tab IDs and titles must be nonempty.');
    if (ids.has(item.id)) throw new Error('Tab IDs must be unique.');
    ids.add(item.id);
    if (item.badge !== undefined && item.badge !== 'dot' &&
      (!Number.isInteger(item.badge) || item.badge < 0 || item.badge > 2147483647)) {
      throw new Error('Tab badge must be dot or a nonnegative 32-bit integer.');
    }
  }
  if (items.length === 0 ? value !== null : value === null || !ids.has(value)) {
    throw new Error('Tab value must identify an existing tab, or be null for empty items.');
  }
}
