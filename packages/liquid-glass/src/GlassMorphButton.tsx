import React from 'react';
import NativeControl from './NativeControl';
import {controlItems, controlAction} from './controlConfig';
import {GlassMetrics} from './GlassMetrics';
import type {GlassControlItem, GlassMorphButtonProps} from './types';
export default function GlassMorphButton({content, anchor = 'trailing', onPress, controlSize = 'regular', disabled = false,
  colorScheme = 'system', tintColor, forceFallback = false, testID, style, ...props}: GlassMorphButtonProps) {
  const item: GlassControlItem = {...content, id: 'content', testID, tintColor,
    ...(content.kind === 'back' ? {symbol: {name: 'chevron.backward', pointSize: GlassMetrics.symbol.backPointSize, weight: 'semibold' as const, scale: 'large' as const}, androidIcon: 'alg_back'} : {})};
  const height = GlassMetrics.control[controlSize];
  return <NativeControl {...props} minimumHeight={height} style={[{alignSelf: anchor === 'trailing' ? 'flex-end' : anchor === 'leading' ? 'flex-start' : 'center'}, style]}
    configJSON={JSON.stringify({mode: 'morph', items: controlItems([item]).map(entry => ({...entry,
      title: content.kind === 'title' ? content.title : undefined})), height, anchor, disabled, colorScheme, forceFallback, swiftUIMorph: true})}
    onControlAction={({nativeEvent: {id, action}}) => {if (!disabled) controlAction([item], id, action, () => onPress?.());}} />;
}
