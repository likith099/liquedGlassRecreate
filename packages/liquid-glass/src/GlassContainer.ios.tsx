import React from 'react';
import {View} from 'react-native';
import NativeSurface from './specs/ALGSurfaceNativeComponent';
import {warnSpacingWithoutMerging} from './devWarnings';
import {isLiquidGlassSupported} from './support';
import type {GlassContainerProps} from './types';
export default function GlassContainer({forceFallback, mergingEnabled, spacing, ...props}: GlassContainerProps) {
  warnSpacingWithoutMerging(spacing, mergingEnabled);
  return forceFallback || !isLiquidGlassSupported() ? <View {...props} /> :
    <NativeSurface {...props} container mergingEnabled={mergingEnabled ?? false} spacing={spacing} />;
}
