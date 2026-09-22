export const packageName = '@likith99/react-native-adaptive-liquid-glass';

// npm 11 has emitted arrays, bare entries and objects keyed by package name.
export function parsePackResult(raw, expectedName = packageName) {
  const start = raw.search(/[[{]/);
  if (start < 0) throw new Error('npm pack produced no JSON');
  const parsed = JSON.parse(raw.slice(start));
  const candidates = Array.isArray(parsed) ? parsed :
    Array.isArray(parsed?.files) ? [parsed] : Object.values(parsed ?? {});
  const entry = candidates.find(item => item?.name === expectedName && Array.isArray(item.files));
  if (!entry) throw new Error(`No pack entry for ${expectedName}: ${JSON.stringify(parsed).slice(0, 2000)}`);
  return entry;
}
