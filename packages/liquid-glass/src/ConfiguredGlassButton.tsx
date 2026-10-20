import React from 'react';
import NativeControl from './NativeControl';
import {nativeIcon, iconColor} from './iconOptions';
import {GlassMetrics} from './GlassMetrics';
import type {NativeGlassButtonProps} from './types';
export default function ConfiguredGlassButton({title, systemImage, symbol, image, contentTransition, pressEffect,
  badge, badgeColor, badgeTextColor, badgeAccessibilityLabel, controlSize, variant, loading, disabled, onPress, tintColor, colorScheme, forceFallback,
  accessibilityLabel, testID, ...props}: NativeGlassButtonProps) {
  return <NativeControl {...props} minimumHeight={GlassMetrics.control[controlSize ?? 'regular']}
    configJSON={JSON.stringify({mode: 'morph', height: GlassMetrics.control[controlSize ?? 'regular'], colorScheme,
      forceFallback, disabled: disabled || loading, value: variant === 'prominent' ? 'button' : undefined, selectedStyle: 'tinted',
      items: [{id: 'button', title: loading ? `${title}…` : title, label: accessibilityLabel ?? title, testID,
        tint: iconColor(tintColor), ...nativeIcon({systemImage, symbol, image, contentTransition, pressEffect, badge, badgeColor, badgeTextColor, badgeAccessibilityLabel})}]})}
    onControlAction={() => {if (!disabled && !loading) onPress();}} />;
}
