import React from 'react';
import {Text, View, useColorScheme} from 'react-native';
import GlassButton from '../GlassButton';
import {validateActions} from '../validateActions';
import type {GlassActionClusterProps} from '../types';
export default function GlassActionCluster({actions, expanded, onExpandedChange, onAction,
  toggleLabel = 'Actions', style, spacing: _spacing, tintColor: _tint, material: _material,
  interactive: _interactive, animationDuration: _duration, forceFallback: _force,
  mergingEnabled: _merging, pressFeedback: _pressFeedback, iosImplementation: _implementation, ...props}: GlassActionClusterProps) {
  validateActions(actions);
  const dark = useColorScheme() === 'dark';
  const textStyle = {color: dark ? '#F5F5FA' : '#242630', fontWeight: '600' as const};
  return <View {...props} accessible={false} style={[{minHeight: 80, flexDirection: 'row', flexWrap: 'wrap', gap: 12,
    alignItems: 'center', justifyContent: 'flex-end', padding: 12}, style]}>
    {expanded && actions.map(action => <GlassButton key={action.id} forceFallback
      testID={`glass-action-${action.id}`} accessibilityLabel={action.title} disabled={action.disabled}
      onPress={() => onAction(action.id)} contentStyle={{paddingHorizontal: 16}}>
      <Text style={textStyle}>{action.title}</Text>
    </GlassButton>)}
    <GlassButton forceFallback testID="glass-cluster-toggle" accessibilityLabel={toggleLabel}
      accessibilityState={{expanded}} onPress={() => onExpandedChange(!expanded)}>
      <Text style={textStyle}>{expanded ? 'Close' : toggleLabel}</Text>
    </GlassButton>
  </View>;
}
