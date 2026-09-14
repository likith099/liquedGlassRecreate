import React from 'react';
import {View} from 'react-native';
import NativeSurface from './specs/ALGSurfaceNativeComponent';
import {isLiquidGlassSupported} from './support';
import type {GlassContainerProps} from './types';
export default function GlassContainer({forceFallback, mergingEnabled = false, spacing, ...props}: GlassContainerProps) {
  return forceFallback || !isLiquidGlassSupported() ? <View {...props} /> :
    <NativeSurface {...props} container mergingEnabled={mergingEnabled} spacing={spacing} />;
}
