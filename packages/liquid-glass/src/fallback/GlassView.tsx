import React from 'react';
import {View} from 'react-native';
import {useFallbackColors} from '../fallbackTheme';
import {withCornerBadge} from '../BadgeView';
import type {GlassViewProps} from '../types';

export default function GlassView({material = 'regular', interactive: _interactive,
  tintColor: _tint, cornerRadius = 24, animationDuration: _duration, colorScheme = 'system',
  fallbackStyle, forceFallback: _force, fallbackMaterial: _fallbackMaterial, badge, badgeColor, badgeTextColor, badgeAccessibilityLabel, style, ...props}: GlassViewProps) {
  const {dark, surface} = useFallbackColors(colorScheme);
  const viewStyle = [{borderRadius: cornerRadius,
    backgroundColor: material === 'none' ? 'transparent' : surface ?? (dark ? '#25272D' : '#F0F1F5')}, style, fallbackStyle];
  return withCornerBadge(<View {...props} style={viewStyle} />, badge, badgeColor, viewStyle,
    {textColor: badgeTextColor, accessibilityLabel: badgeAccessibilityLabel});
}
