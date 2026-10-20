import React from 'react';
import NativeSurface from './specs/ALGSurfaceNativeComponent';
import Fallback from './fallback/GlassView';
import {withCornerBadge} from './BadgeView';
import {isLiquidGlassSupported} from './support';
import type {GlassViewProps} from './types';
export default function GlassView({glassID, tintColor, cornerRadius = 24, fallbackStyle, forceFallback,
  fallbackMaterial = 'blur', badge, badgeColor, badgeTextColor, badgeAccessibilityLabel, style, ...props}: GlassViewProps) {
  if (forceFallback || (fallbackMaterial === 'solid' && !isLiquidGlassSupported())) {
    return <Fallback {...props} style={style} tintColor={tintColor} cornerRadius={cornerRadius} fallbackStyle={fallbackStyle} badge={badge} badgeColor={badgeColor}
      badgeTextColor={badgeTextColor} badgeAccessibilityLabel={badgeAccessibilityLabel} />;
  }
  const glassStyle = isLiquidGlassSupported() ? style : [style, fallbackStyle];
  const surface = <NativeSurface {...props} nativeID={glassID ? `alg-glass-${glassID}` : props.nativeID} glassTint={tintColor} glassRadius={cornerRadius}
    style={glassStyle} />;
  return withCornerBadge(surface, badge, badgeColor, glassStyle, {textColor: badgeTextColor, accessibilityLabel: badgeAccessibilityLabel});
}
