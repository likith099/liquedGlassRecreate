import React, {useLayoutEffect, useState} from 'react';
import {findNodeHandle} from 'react-native';
import NativeScrollEdge from './specs/ALGScrollEdgeNativeComponent';
import type {GlassScrollEdgeProps} from './types';

/**
 * Wraps bars floating over a ScrollView edge. On iOS 26 UIKit draws its scroll-edge effect under
 * this container, so content fades beneath the bar instead of colliding with its glass.
 */
export default function GlassScrollEdge({scrollViewRef, edge = 'bottom', effectStyle = 'automatic',
  fallbackColor, ...props}: GlassScrollEdgeProps) {
  const [scrollViewTag, setScrollViewTag] = useState(-1);
  // The ScrollView may mount in the same commit; read its tag after layout, on every commit.
  useLayoutEffect(() => {
    const tag = scrollViewRef.current ? findNodeHandle(scrollViewRef.current as never) ?? -1 : -1;
    setScrollViewTag(current => current === tag ? current : tag);
  });
  return <NativeScrollEdge {...props} scrollViewTag={scrollViewTag} edge={edge} effectStyle={effectStyle}
    fallbackColor={fallbackColor} />;
}
