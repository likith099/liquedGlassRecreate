import React from 'react';
import {Platform, Pressable} from 'react-native';
import GlassView from './GlassView';
import type {GlassPressableProps} from './types';
export default function GlassPressable({children, style, contentStyle, material, tintColor, cornerRadius = 28,
  interactive = true, colorScheme, fallbackMaterial, fallbackStyle, forceFallback, disabled, accessibilityState, android_ripple,
  ...props}: GlassPressableProps) {
  return <Pressable {...props} disabled={disabled} accessibilityRole="button"
    accessibilityState={{...accessibilityState, disabled: !!disabled}}
    android_ripple={android_ripple ?? {color: '#80808030', foreground: true}}
    style={[{borderRadius: cornerRadius, overflow: Platform.OS === 'android' ? 'hidden' : 'visible'}, style]}>
    <GlassView material={material} tintColor={tintColor} cornerRadius={cornerRadius}
      interactive={interactive && !disabled} colorScheme={colorScheme} fallbackMaterial={fallbackMaterial} forceFallback={forceFallback} fallbackStyle={fallbackStyle}
      style={[{minHeight: 52, paddingHorizontal: 22, paddingVertical: 14, justifyContent: 'center', alignItems: 'center'}, contentStyle]}>
      {children}
    </GlassView>
  </Pressable>;
}
