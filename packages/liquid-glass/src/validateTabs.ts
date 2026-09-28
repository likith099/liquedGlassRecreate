import {Image, PixelRatio, processColor, type ColorValue, type ImageSourcePropType, type ImageURISource} from 'react-native';
import type {GlassTabItem} from './types';

/** Tab colours travel to native code as JSON, so only static colours are accepted. */
export function staticColor(color: ColorValue | undefined, field: string): number | undefined {
  if (color === undefined) return undefined;
  const processed = processColor(color);
  if (typeof processed !== 'number') throw new Error(`Tab ${field} must be a static colour, not a platform or dynamic colour.`);
  return processed;
}
/** A loadable image: a Metro asset URL in development, a bundled file or resource in release, or any URI. */
export interface TabImageSource {uri: string; scale: number}
/**
 * Resolves tab artwork to an asset-catalog name or a loadable source. For a list of sources, the one
 * whose scale is closest to the screen's is used, as React Native's Image does for fixed-size images.
 */
export function resolveTabImage(image: string | ImageSourcePropType | undefined, field: string):
  {name?: string; source?: TabImageSource} {
  if (image === undefined) return {};
  if (typeof image === 'string') {
    if (!image.trim()) throw new Error(`Tab ${field} must be a nonempty asset name or an image source.`);
    return {name: image};
  }
  let candidate: number | ImageURISource | undefined;
  if (Array.isArray(image)) {
    const screen = PixelRatio.get();
    candidate = [...(image as readonly ImageURISource[])].sort((a, b) =>
      Math.abs((a.scale ?? 1) - screen) - Math.abs((b.scale ?? 1) - screen))[0];
  } else {
    candidate = image as number | ImageURISource;
  }
  const resolved = candidate === undefined ? null : Image.resolveAssetSource(candidate);
  if (!resolved?.uri) throw new Error(`Tab ${field} must be an asset name, require() of an image, or a source with a uri.`);
  return {source: {uri: resolved.uri, scale: resolved.scale ?? 1}};
}
export function validateTabs(items: readonly GlassTabItem[], value: string | null) {
  if (items.length > 5) throw new Error('GlassTabBar supports at most 5 tabs.');
  const ids = new Set<string>();
  for (const item of items) {
    if (!item.id.trim() || !item.title.trim()) throw new Error('Tab IDs and titles must be nonempty.');
    if (ids.has(item.id)) throw new Error('Tab IDs must be unique.');
    ids.add(item.id);
    staticColor(item.selectedTintColor, 'selectedTintColor');
    staticColor(item.inactiveTintColor, 'inactiveTintColor');
    resolveTabImage(item.image, 'image');
    resolveTabImage(item.selectedImage, 'selectedImage');
    if (item.imageRenderingMode !== undefined && item.imageRenderingMode !== 'template' && item.imageRenderingMode !== 'original') {
      throw new Error('Tab imageRenderingMode must be template or original.');
    }
    if (item.badge !== undefined && item.badge !== 'dot' &&
      (!Number.isInteger(item.badge) || item.badge < 0 || item.badge > 2147483647)) {
      throw new Error('Tab badge must be dot or a nonnegative 32-bit integer.');
    }
  }
  if (items.length === 0 ? value !== null : value === null || !ids.has(value)) {
    throw new Error('Tab value must identify an existing tab, or be null for empty items.');
  }
}
