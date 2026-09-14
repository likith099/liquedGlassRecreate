import type {GlassMenuElement, GlassMenuItem} from './types';

/** Bounded recursive contract shared by menu buttons and toolbar menus. */
export function validateMenuItems(items: readonly GlassMenuElement[]) {
  const ids = new Set<string>();
  const visit = (elements: readonly GlassMenuElement[], depth: number, submenuDepth: number) => {
    if (depth > 8) throw new Error('Menus support at most 8 levels.');
    for (const item of elements) {
      if (!item.id.trim() || (item.kind !== 'section' && !item.title.trim())) {
        throw new Error('Menu IDs and action/submenu titles must be nonempty.');
      }
      if (ids.has(item.id)) throw new Error('Menu IDs must be unique throughout the tree.');
      ids.add(item.id);
      if (ids.size > 256) throw new Error('Menus support at most 256 elements.');
      if (item.kind === 'section' || item.kind === 'submenu') {
        if (!item.items.length) throw new Error('Menu groups must contain items.');
        const nextSubmenuDepth = submenuDepth + (item.kind === 'submenu' ? 1 : 0);
        if (nextSubmenuDepth > 1) throw new Error('Menus support one submenu level across platforms.');
        visit(item.items, depth + 1, nextSubmenuDepth);
      }
    }
  };
  visit(items, 1, 0);
}

/** Only enabled leaves can emit actions; a disabled submenu blocks all descendants. */
export function enabledMenuAction(items: readonly GlassMenuElement[], id: string): GlassMenuItem | undefined {
  for (const item of items) {
    if (item.kind === 'section' || item.kind === 'submenu') {
      if (item.kind === 'submenu' && item.disabled) continue;
      const action = enabledMenuAction(item.items, id);
      if (action) return action;
    } else if (item.id === id && !item.disabled) return item;
  }
}
