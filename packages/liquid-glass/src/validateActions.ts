import type {GlassAction} from './types';
export function validateActions(actions: readonly GlassAction[]): void {
  const ids = new Set<string>();
  for (const action of actions) {
    if (!action.id || action.id === '__toggle' || ids.has(action.id)) {
      throw new Error('GlassActionCluster requires unique, nonempty action IDs; __toggle is reserved.');
    }
    ids.add(action.id);
  }
}
