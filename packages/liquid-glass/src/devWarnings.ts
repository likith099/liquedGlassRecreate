const warned = new Set<string>();

/** Logs a development-only warning once per key. Production builds stay silent. */
export function warnOnce(key: string, message: string) {
  if (!__DEV__ || warned.has(key)) return;
  warned.add(key);
  console.warn(`[react-native-adaptive-liquid-glass] ${message}`);
}

/** Merging is opt-in; spacing alone (the expo-glass-effect shape) would otherwise do nothing. */
export function warnSpacingWithoutMerging(spacing: number | undefined, mergingEnabled: boolean | undefined) {
  if (spacing !== undefined && mergingEnabled === undefined) {
    warnOnce('container-spacing', 'GlassContainer received spacing without mergingEnabled. Merging is ' +
      'opt-in, so no surfaces will merge. Pass mergingEnabled={true} to merge, or mergingEnabled={false} ' +
      'to silence this warning.');
  }
}
