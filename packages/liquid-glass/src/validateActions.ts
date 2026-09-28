import type {GlassAction} from './types';
export function validateActions(actions: readonly GlassAction[]): void {
  const ids = new Set<string>();
  for (const action of actions) {
    if (!action.id || ids.has(action.id)) {
      throw new Error('GlassActionCluster requires unique, nonempty action IDs.');
    }
    ids.add(action.id);
  }
}
