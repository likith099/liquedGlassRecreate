import React from 'react';
import {StyleSheet, View} from 'react-native';
import type {GlassScrollEdgeProps} from './types';

/** Unsupported platforms: an optional gradient scrim or solid fill beneath the children. */
export default function GlassScrollEdge({scrollViewRef: _scrollView, edge = 'bottom', effectStyle: _style,
  fallbackColor, fallbackMode = 'gradient', children, ...props}: GlassScrollEdgeProps) {
  // CSS gradients need a colour string; other colour values fall back to a solid scrim.
  const scrim = fallbackMode === 'gradient' && typeof fallbackColor === 'string'
    ? {experimental_backgroundImage: `linear-gradient(to ${edge === 'top' ? 'bottom' : 'top'}, ${fallbackColor}, transparent)`}
    : {backgroundColor: fallbackColor};
  return <View {...props}>
    {fallbackColor !== undefined && <View pointerEvents="none" style={[StyleSheet.absoluteFill, scrim]} />}
    {children}
  </View>;
}
