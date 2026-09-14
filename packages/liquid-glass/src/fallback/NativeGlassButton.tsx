import React from 'react';
import {ActivityIndicator, Pressable, Text, useColorScheme} from 'react-native';
import type {NativeGlassButtonProps} from '../types';
export default function NativeGlassButton({title, systemImage: _symbol, variant = 'regular', disabled,
  loading, onPress, tintColor, colorScheme = 'system', forceFallback: _fallback, style,
  accessibilityLabel, accessibilityState, ...props}: NativeGlassButtonProps) {
  const scheme = useColorScheme();
  const dark = (colorScheme === 'system' ? scheme : colorScheme) === 'dark';
  const inactive = !!(disabled || loading);
  const foreground = variant === 'prominent' ? '#FFFFFF' : dark ? '#F4F4FA' : '#242630';
  return <Pressable {...props} accessibilityRole="button" accessibilityLabel={accessibilityLabel ?? title}
    accessibilityState={{...accessibilityState, disabled: inactive, busy: !!loading}} disabled={inactive}
    onPress={() => {if (!inactive) onPress();}} android_ripple={{color: '#80808040', foreground: true}}
    style={[{minHeight: 56, borderRadius: 28, paddingVertical: 14, paddingHorizontal: 20,
      flexDirection: 'row', gap: 10, alignItems: 'center', justifyContent: 'center', overflow: 'hidden',
      backgroundColor: variant === 'prominent' ? tintColor ?? '#6159B7' : dark ? '#25272D' : '#F0F1F5',
      opacity: disabled ? 0.45 : 1}, style]}>
    {loading && <ActivityIndicator color={foreground} />}
    <Text style={{color: foreground, fontSize: 16, fontWeight: '600', flexShrink: 1}}>{title}</Text>
  </Pressable>;
}
