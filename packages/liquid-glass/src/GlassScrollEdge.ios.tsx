import React, {useLayoutEffect, useState, useRef} from 'react';
import {findNodeHandle} from 'react-native';
import NativeScrollEdge from './specs/ALGScrollEdgeNativeComponent';
import {resolveScrollTarget} from './scrollTarget';
import type {GlassScrollEdgeProps} from './types';

/**
 * Wraps bars floating over a ScrollView edge. On iOS 26 UIKit draws its scroll-edge effect under
 * this container, so content fades beneath the bar instead of colliding with its glass.
 */
export default function GlassScrollEdge({scrollViewRef, edge = 'bottom', effectStyle = 'automatic',
  fallbackColor, fallbackMode = 'gradient', ...props}: GlassScrollEdgeProps) {
  const [scrollViewTag, setScrollViewTag] = useState(-1);
  const bound = useRef<unknown>(null);
  // The ScrollView may mount in the same commit; read its tag after layout, on every commit.
  useLayoutEffect(() => {
    const bind = () => {
      const target = resolveScrollTarget(scrollViewRef.current);
      if (target && target === bound.current) return;
      const tag = target ? findNodeHandle(target as never) ?? -1 : -1;
      if (tag > 0) bound.current = target;
      setScrollViewTag(current => current === tag ? current : tag);
    };
    bind();
    // FlatList can finish assigning its inner ScrollView ref after this sibling's
    // layout effect. Retry once after the commit, without an idle polling loop.
    if (bound.current) return;
    const frame = requestAnimationFrame(bind);
    return () => cancelAnimationFrame(frame);
  });
  return <NativeScrollEdge {...props} scrollViewTag={scrollViewTag} edge={edge} effectStyle={effectStyle}
    fallbackColor={fallbackColor} fallbackMode={fallbackMode} />;
}
