import React from 'react';
import NativeSurface from './specs/ALGSurfaceNativeComponent';
import Fallback from './fallback/GlassView';
import {isLiquidGlassSupported} from './support';
import type {GlassViewProps} from './types';
export default function GlassView({tintColor, cornerRadius = 24, fallbackStyle, forceFallback,
  ...props}: GlassViewProps) {
  if (forceFallback || !isLiquidGlassSupported()) {
    return <Fallback {...props} tintColor={tintColor} cornerRadius={cornerRadius} fallbackStyle={fallbackStyle} />;
  }
  return <NativeSurface {...props} glassTint={tintColor} glassRadius={cornerRadius} />;
}
