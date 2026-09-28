import React from 'react';
import {StyleSheet, View} from 'react-native';
import type {GlassScrollEdgeProps} from './types';

/** Android: an ordinary container with an optional gradient scrim in `fallbackColor` under its children. */
export default function GlassScrollEdge({scrollViewRef: _scrollView, edge = 'bottom', effectStyle: _style,
  fallbackColor, children, ...props}: GlassScrollEdgeProps) {
  // CSS gradients need a colour string; other colour values fall back to a solid scrim.
  const scrim = typeof fallbackColor === 'string'
    ? {experimental_backgroundImage: `linear-gradient(to ${edge === 'top' ? 'bottom' : 'top'}, ${fallbackColor}, transparent)`}
    : {backgroundColor: fallbackColor};
  return <View {...props}>
    {fallbackColor !== undefined && <View pointerEvents="none" style={[StyleSheet.absoluteFill, scrim]} />}
    {children}
  </View>;
}
