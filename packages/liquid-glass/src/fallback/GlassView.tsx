import React from 'react';
import {View, useColorScheme} from 'react-native';
import type {GlassViewProps} from '../types';

export default function GlassView({material = 'regular', interactive: _interactive,
  tintColor: _tint, cornerRadius = 24, animationDuration: _duration, colorScheme = 'system',
  fallbackStyle, forceFallback: _force, style, ...props}: GlassViewProps) {
  const system = useColorScheme();
  const dark = (colorScheme === 'system' ? system : colorScheme) === 'dark';
  return <View {...props} style={[{borderRadius: cornerRadius,
    backgroundColor: material === 'none' ? 'transparent' : dark ? '#25272D' : '#F0F1F5'}, style, fallbackStyle]} />;
}
