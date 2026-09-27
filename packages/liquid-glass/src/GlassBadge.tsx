import React from 'react';
import {Text, View} from 'react-native';
import GlassView from './GlassView';
import {useFallbackColors} from './fallbackTheme';
import {useGlassTier} from './glassTier';
import type {GlassBadgeProps} from './types';

/**
 * A small label on material, for example over imagery. iOS 26 draws glass (tinted only with
 * `tintGlass`); iOS 15–25 draws system blur with `tintColor` over it; Android, Reduce
 * Transparency and `forceFallback` draw `solidColor`.
 */
export default function GlassBadge({children, tintColor, tintGlass = false, solidColor, textColor,
  colorScheme = 'system', cornerRadius = 12, forceFallback = false, style, textStyle, accessibilityLabel,
  ...props}: GlassBadgeProps) {
  const tier = useGlassTier();
  const {dark, surface, foreground} = useFallbackColors(colorScheme);
  const label = typeof children === 'string' || typeof children === 'number' ? String(children) : undefined;
  const content = label === undefined ? children : <Text numberOfLines={1} style={[{fontSize: 13, fontWeight: '600',
    color: textColor ?? foreground ?? (dark ? '#F4F4FA' : '#242630')}, textStyle]}>{label}</Text>;
  const layout = {flexDirection: 'row' as const, alignItems: 'center' as const, alignSelf: 'flex-start' as const,
    gap: 4, minHeight: 24, paddingHorizontal: 10, paddingVertical: 4};
  const semantics = {accessible: true, accessibilityRole: 'text' as const, accessibilityLabel: accessibilityLabel ?? label};
  if (forceFallback || tier === 'solid') {
    return <View {...props} {...semantics} style={[layout, {borderRadius: cornerRadius,
      backgroundColor: solidColor ?? surface ?? (dark ? '#25272D' : '#F0F1F5')}, style]}>{content}</View>;
  }
  return <GlassView {...props} {...semantics} colorScheme={colorScheme} cornerRadius={cornerRadius}
    tintColor={tier === 'glass' && !tintGlass ? undefined : tintColor} style={[layout, style]}>{content}</GlassView>;
}
