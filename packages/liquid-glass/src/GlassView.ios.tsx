import React from 'react';
import NativeSurface from './specs/ALGSurfaceNativeComponent';
import Fallback from './fallback/GlassView';
import {isLiquidGlassSupported} from './support';
import type {GlassViewProps} from './types';
export default function GlassView({tintColor, cornerRadius = 24, fallbackStyle, forceFallback,
  style, ...props}: GlassViewProps) {
  if (forceFallback) {
    return <Fallback {...props} style={style} tintColor={tintColor} cornerRadius={cornerRadius} fallbackStyle={fallbackStyle} />;
  }
  return <NativeSurface {...props} glassTint={tintColor} glassRadius={cornerRadius}
    style={isLiquidGlassSupported() ? style : [style, fallbackStyle]} />;
}
