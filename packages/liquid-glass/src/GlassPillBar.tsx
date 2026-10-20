import React, {useReducer} from 'react';
import {useWindowDimensions} from 'react-native';
import NativeControl from './NativeControl';
import {controlItems, controlAction} from './controlConfig';
import {GlassMetrics} from './GlassMetrics';
import {nativeIcon, iconColor, normalizeBadge} from './iconOptions';
import type {GlassPillBarProps} from './types';
export default function GlassPillBar({items, value, onValueChange, actions = [], onAction, selectedStyle = 'prominent', tintColor,
  contentInset, scrollSelectedIntoView = true, metrics, colorScheme = 'system', disabled = false, forceFallback = false, ...props}: GlassPillBarProps) {
  const {width} = useWindowDimensions();
  const [revision, reconcile] = useReducer((n: number) => n + 1, 0);
  const dimensions = {...GlassMetrics.pill, labelSize: 17, ...metrics};
  const inset = contentInset ?? GlassMetrics.pageMargin(width);
  if (Object.values(dimensions).some(n => !Number.isFinite(n) || n < 0) || !Number.isFinite(inset) || inset < 0) throw new Error('Pill metrics must be finite and nonnegative.');
  if (items.length && !items.some(item => item.id === value)) throw new Error('GlassPillBar value must name an item.');
  // Validate identity across both selectable pills and action capsules.
  controlItems([...items.map(item => ({...item, badge: undefined, accessibilityLabel: item.accessibilityLabel ?? item.label})), ...actions]);
  const pills = items.map(item => ({...item, label: item.accessibilityLabel ?? item.label, title: item.label,
    ...nativeIcon({...item, badge: normalizeBadge(item.badge)})}));
  return <NativeControl {...props} stretch minimumHeight={Math.max(44, dimensions.height)}
    configJSON={JSON.stringify({mode: 'pills', items: [...pills, ...controlItems(actions)], value, revision,
      selectedStyle, tint: iconColor(tintColor), contentInset: inset, scrollSelectedIntoView, ...dimensions,
      colorScheme, disabled, forceFallback})} onControlAction={({nativeEvent: {id, action}}) => {
      if (disabled) return;
      reconcile();
      const item = items.find(candidate => candidate.id === id);
      if (item && !item.disabled && id !== value) onValueChange(id);
      else controlAction(actions, id, action, onAction);
    }} />;
}
