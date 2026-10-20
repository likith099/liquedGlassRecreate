import React from 'react';
import NativeControl from './NativeControl';
import {controlItems, controlAction} from './controlConfig';
import {GlassMetrics} from './GlassMetrics';
import type {GlassIconGroupProps} from './types';
export default function GlassIconGroup({items, onPress, symbol, controlSize = 'regular', colorScheme = 'system', disabled = false,
  forceFallback = false, ...props}: GlassIconGroupProps) {
  const height = GlassMetrics.control[controlSize];
  return <NativeControl {...props} minimumHeight={height} configJSON={JSON.stringify({mode: 'group', items: controlItems(items, {scale: 'medium', ...symbol}),
    height, colorScheme, disabled, forceFallback})} onControlAction={({nativeEvent: {id, action}}) => {
      if (!disabled) controlAction(items, id, action, onPress);
    }} />;
}
